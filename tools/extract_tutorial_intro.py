"""Decode CIN 1, its trigger, rigs, mapped animation IDs and sound cues from original WAR/DAV/SND."""
import json
from pathlib import Path
import struct
import sys
from PIL import Image
from extract_shared_items import read_rig, page_image

ROOT = Path(__file__).resolve().parent.parent
STRIDES = [0,8,8,4,2,2,4,2,2]

def main():
    decomp, folder = map(Path,sys.argv[1:3])
    verify = '--verify' in sys.argv
    def save_json(path, value):
        if verify:
            assert json.loads(path.read_text()) == value, path
        else:
            path.write_text(json.dumps(value,separators=(',',':')))
    sys.path.insert(0,str(decomp/'tools'))
    import level_editor as editor
    import war_meshes
    files={p.suffix.lower():p for p in folder.iterdir()}
    war=files['.war'].read_bytes()
    table=struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
    at=next(e&0xffffff for e in table if e>>24==0x85)
    pairs=[struct.unpack_from('<2I',war,at+4+i*8) for i in range(struct.unpack_from('<I',war,at)[0])]
    def sequence(identity):
        header,pointer=next((h,p) for h,p in pairs if h&65535==identity)
        count=(header>>16)&0x7fff
        voice,=struct.unpack_from('<I',war,pointer)
        cursor=pointer+4
        tracks=[]
        end=0
        for _ in range(count):
            selector,records,index,_unused=struct.unpack_from('<BBHI',war,cursor)
            cursor+=8
            track={'selector':selector,'index':index,'records':[]}
            for _ in range(records):
                op,n,_unused=struct.unpack_from('<HHI',war,cursor)
                cursor+=8
                keys=[]
                for i in range(n):
                    word,=struct.unpack_from('<H',war,cursor+i*STRIDES[op])
                    value=list(struct.unpack_from('<%dh'%((STRIDES[op]-2)//2),war,cursor+i*STRIDES[op]+2))
                    time=(word&0x3fff)*0.016
                    end=max(time,end)
                    keys.append({'time':time,'mode':word>>14,'value':value})
                track['records'].append({'opcode':op,'keys':keys})
                cursor=(cursor+n*STRIDES[op]+3)&~3
            tracks.append(track)
        return voice,tracks,end
    voice,tracks,end=sequence(1)
    follow_voice,follow_tracks,follow_end=sequence(5)
    build_voice,build_tracks,build_end=sequence(3)
    # Resolve the manager's first ACTBOX through the original type-0x82 export table.
    at=next(e&0xffffff for e in table if e>>24==0x82)
    n,=struct.unpack_from('<I',war,at)
    cursor=at+4
    exports={}
    for _ in range(n):
        identity,num=struct.unpack_from('<HH',war,cursor)
        exports[identity]=struct.unpack_from('<%dI'%num,war,cursor+4)
        cursor+=4+4*num
    flags,*corners=struct.unpack_from('<I6h',war,exports[662][0])
    trigger={'export_id':662,'flags':flags,'min':corners[:3],'max':corners[3:]}
    cine_objects=[i for i,e in enumerate(table) if e>>24==10]
    labels={'2:52':'ralph','2:56':'daffy','4:0':'bipbip_prop','4:1':'bipbip',
            '4:2':'curtain','4:3':'anvil','4:7':'prop'}
    output=ROOT/'assets/cinematics/tutorial_intro'
    output.mkdir(parents=True,exist_ok=True)
    davraw=files['.dav'].read_bytes()
    dav=war_meshes.read_dav(files['.dav'])
    actors={}
    sound_ids=set()
    all_tracks={f"{track['selector']}:{track['index']}":track for track in tracks+follow_tracks+build_tracks if track['selector']!=0}
    for key,track in all_tracks.items():
        if track['selector']==0:
            continue
        name=labels.get(key,'platform_'+str(track['index']))
        resource=track['index'] if track['selector'] in [1,2] else cine_objects[track['index']]
        model,=struct.unpack_from('<H',war,table[resource]&0xffffff)
        model_at=table[model]&0xffffff
        if track['selector']==3:
            geometry=editor.geometry(war,editor.dav_tables(davraw),model_at,False)
            surfaces={}
            for page,values in geometry['groups'].items():
                group={'verts':[],'uvs':[],'cols':[]}
                for i in range(0,len(values),8):
                    x,y,z,u,v,r,g,b=values[i:i+8];divisor=128 if int(page)>=0 else 255
                    group['verts'].append([x*.01,-y*.01,z*.01]);group['uvs'].append([u,v]);group['cols'].append([r/divisor,g/divisor,b/divisor])
                surfaces[page]=group
            box_pointer,=struct.unpack_from('<I',war,model_at+12)
            collision_boxes=[]
            if box_pointer:
                for box_index in range(struct.unpack_from('<I',war,box_pointer)[0]):
                    box_flags,*corners=struct.unpack_from('<I6h',war,box_pointer+4+box_index*16)
                    if not box_flags&1:
                        collision_boxes.append({'flags':box_flags,'min':corners[:3],'max':corners[3:]})
            names={};rig={'static':True,'surfaces':surfaces,'animations':{},'joints':[], 'collision_boxes':collision_boxes}
        else:
            anim_at,=struct.unpack_from('<I',war,model_at+16)
            direct_count,=struct.unpack_from('<I',war,anim_at)
            mapped_at=anim_at+4+direct_count*4
            mapped_count,=struct.unpack_from('<I',war,mapped_at)
            mapped=struct.unpack_from('<%dI'%mapped_count,war,mapped_at+4)
            used=set()
            for related in tracks+follow_tracks+build_tracks:
                if related['selector']==track['selector'] and related['index']==track['index']:
                    used.update(k['value'][0]&0x7fff for r in related['records'] if r['opcode']==3 for k in r['keys'])
            if name=='daffy':
                used.update([15,18,20,21,22,23,34,36,37])
            if name=='anvil':
                used.update([0,1,2]) # SignPost: drop, hold, lift.
            if name=='bipbip':
                used.add(0) # bipbip's default mapped animation: RUN1 for the road chase.
            names={str(i):war[mapped[i]:mapped[i]+8].split(b'\0')[0].decode().lower() for i in used}
            rig=read_rig(war,table[model],editor,war_meshes,editor.dav_tables(davraw),{v:v for v in names.values()})
        actor_dir=output/name
        actor_dir.mkdir(exist_ok=True)
        save_json(actor_dir/'worn_data.json',rig)
        materials={}
        textures=actor_dir/'textures'
        textures.mkdir(exist_ok=True)
        for page in rig['surfaces']:
            if int(page)>=0:
                record=dav['pages'][int(page)]
                image = page_image(davraw,record)
                path = textures/f'page_{page}.png'
                if verify:
                    actual = Image.open(path).convert('RGBA')
                    assert actual.size == image.size and actual.tobytes() == image.tobytes(), path
                else:
                    image.save(path)
                materials[page]=record['kind']
        for animation in rig['animations'].values():
            sound_ids.update(c['sound_id'] for c in animation['sound_cues'])
        actors[key]={'name':name,'source_resource':resource,'model':model,'animation_ids':names,
            'materials':materials,'directory':f'res://assets/cinematics/tutorial_intro/{name}'}
        print(name,'model',model,'joints',len(rig['joints']),'animations',names)
    snd=files['.snd'].read_bytes()
    sounds={}
    at=12
    (output/'audio').mkdir(exist_ok=True)
    for _ in range(struct.unpack_from('<I',snd,8)[0]):
        identity,size,flags=struct.unpack_from('<III',snd,at)
        if identity in sound_ids:
            target=output/f'audio/{identity:04x}.wav'
            blob = snd[at+12:at+12+size]
            if verify:
                assert target.read_bytes() == blob, target
            else:
                target.write_bytes(blob)
            sounds[str(identity)]='res://'+target.relative_to(ROOT).as_posix()
        at+=12+size
    assert sound_ids.issubset(set(map(int,sounds))), sound_ids-set(map(int,sounds))
    result={'cine_id':1,'duration':end,'voice_id':voice,'trigger':trigger,'tracks':tracks,'actors':actors,'sounds':sounds}
    save_json(output/'sequence.json',result)
    follow_result={'cine_id':5,'duration':follow_end,'voice_id':follow_voice,'trigger':trigger,
        'tracks':follow_tracks,'actors':actors,'sounds':sounds}
    save_json(output/'follow_sequence.json',follow_result)
    save_json(output/'platform_sequence.json',{'cine_id':3,'duration':build_end,'voice_id':build_voice,
        'trigger':trigger,'tracks':build_tracks,'actors':actors,'sounds':sounds})
    print('CIN 1 duration',end,'trigger',trigger,'sounds',len(sounds))
    if verify:
        print('Verified original sequence, rigs, animation channels, DAV pages and SND bytes')

if __name__=='__main__':
    main()
