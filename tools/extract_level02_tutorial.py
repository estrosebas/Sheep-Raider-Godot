"""DaffyLevel02: native CIN01/02, AROBIN01/ATEROB01, ACTBOX and MLT48.

No invented camera positions or dialogue. Run before build_level02_tutorial.gd.
"""
import json, struct, sys
from pathlib import Path
from extract_shared_items import read_rig, page_image
ROOT = Path(__file__).resolve().parents[1]
STRIDES = [0,8,8,4,2,2,4,2,2]

def main():
    decomp, game = map(Path, sys.argv[1:3]); sys.path.insert(0,str(decomp/'tools'))
    import level_editor as editor, war_meshes
    folder=game/'Levels/Lvl-02'; out=ROOT/'assets/levels/lvl_02'; cine=out/'cinematics'
    w=(folder/'Lvl-02.WAR').read_bytes(); raw=(folder/'Lvl-02.DAV').read_bytes()
    dt=editor.dav_tables(raw); dav=war_meshes.read_dav(folder/'Lvl-02.DAV')
    t=struct.unpack_from('<%dI'%struct.unpack_from('<I',w,12)[0],w,16)
    def save(path,data):
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')),encoding='utf8')
    p=next(e&0xffffff for e in t if e>>24==0x82); n=struct.unpack_from('<I',w,p)[0];p+=4;ex={}
    for _ in range(n):
        i,c=struct.unpack_from('<HH',w,p);ex[i]=struct.unpack_from('<%dI'%c,w,p+4);p+=4+c*4
    def boxes(i):
        return [dict(flags=v[0],min=list(v[1:4]),max=list(v[4:])) for p in ex.get(i,[]) for v in [struct.unpack_from('<I6h',w,p)]]
    es=json.loads((out/'data/entities.json').read_text()); daffy=next(e for e in es if e['class_id']==47);dp=daffy['props']
    manifest=json.loads((ROOT/'assets/localization/manifest.json').read_text(encoding='utf8'))
    bank=json.loads((ROOT/'assets/localization/levels/lvl_02/es.json').read_text(encoding='utf8'))['lists'][48]
    voice=lambda i: manifest['languages']['es']['voices'].get(str(i),'')
    rules={'resource':daffy['res'],'activation':boxes(dp['0x0']),'start':boxes(dp['0x20']),'goal':boxes(dp['0x1c']),
           'trigger':boxes(dp['0xc']),'sheep':boxes(dp['0x14']),'cine_ids':[dp['0x4'],dp['0x8']],
           'text_base':dp['0x18'],'question':bank[10],'answers':[{'choice':bank[11+i*2],'text':bank[12+i*2],
           'voice_id':v,'voice_path':voice(v)} for i,v in enumerate([25,23,24])],
           'burnt':{'text':GameBurntText(ROOT),'voice_path':voice(13)},'head_directory':'res://assets/levels/lvl_02/daffy_head'}
    save(out/'data/daffy.json',rules)
    definitions={};cache={};sound_ids=set()
    def rig(model,directory):
        if directory in cache:return definitions[str(directory)]
        resource=t[model];at=resource&0xffffff
        if resource>>24==0x44:
            p=struct.unpack_from('<I',w,at+16)[0];n=struct.unpack_from('<I',w,p)[0]
            qs=struct.unpack_from('<%dI'%n,w,p+4)
            names={w[q:q+8].split(b'\0')[0].decode().lower() for q in qs if q}
            data=read_rig(w,resource,editor,war_meshes,dt,{s:s for s in names})
            data.update(rotation_order='ZXY',rotation_axis_sign=[1,1,-1])
            sound_ids.update(c['sound_id'] for a in data['animations'].values() for c in a['sound_cues'])
        else:
            g=editor.geometry(w,dt,at,False);surfaces={}
            for page,vs in g['groups'].items():
                div=128 if int(page)>=0 else 255
                surfaces[page]={'verts':[[vs[i]*.01,-vs[i+1]*.01,vs[i+2]*.01] for i in range(0,len(vs),8)],'uvs':[vs[i+3:i+5] for i in range(0,len(vs),8)],'cols':[[c/div for c in vs[i+5:i+8]] for i in range(0,len(vs),8)]}
            data={'static':True,'surfaces':surfaces,'animations':{},'joints':[]}
        save(directory/'worn_data.json',data);materials={}
        for page in data['surfaces']:
            if int(page)<0:continue
            record=dav['pages'][int(page)];(directory/'textures').mkdir(exist_ok=True)
            page_image(raw,record).save(directory/'textures'/f'page_{page}.png');materials[page]=record['kind']
        definition={'directory':'res://'+directory.relative_to(ROOT).as_posix(),'materials':materials}
        definitions[str(directory)]=definition;cache[directory]=data
        return definition
    # Replace the placeholder single STAND1 with the complete native Lucas rig.
    rig(daffy['model_res'],out/'models'/str(daffy['model_res']))
    for model in [3,9,22,29,30,31,34,38]: rig(model,out/'models'/str(model))
    import re
    props=(decomp/'src/include/scenaric_props.h').read_text()
    head_id=int(re.search(r'WAR_IDO_ATEROB01\s*=\s*(\d+)',props)[1])
    head_model=next(i for i,e in enumerate(t) if e&0xffffff==ex[head_id][0])
    rig(head_model,out/'daffy_head')
    p=next(e&0xffffff for e in t if e>>24==0x85)
    pairs=[struct.unpack_from('<2I',w,p+4+i*8) for i in range(struct.unpack_from('<I',w,p)[0])]
    classless=[i for i,e in enumerate(t) if e>>24==10];sequences=[]
    for h,p in pairs:
        identity=h&65535
        if identity not in rules['cine_ids']:continue
        count=(h>>16)&0x7fff;voice_id=struct.unpack_from('<I',w,p)[0];p+=4;tracks=[];actors={};end=0
        for _ in range(count):
            selector,records,index,_=struct.unpack_from('<BBHI',w,p);p+=8
            track={'selector':selector,'index':index,'records':[]}
            for _ in range(records):
                op,n,_=struct.unpack_from('<HHI',w,p);p+=8;keys=[]
                for k in range(n):
                    word=struct.unpack_from('<H',w,p+k*STRIDES[op])[0]
                    v=list(struct.unpack_from('<%dh'%((STRIDES[op]-2)//2),w,p+k*STRIDES[op]+2));time=(word&0x3fff)*.016
                    end=max(end,time);keys.append({'time':time,'mode':word>>14,'value':v})
                track['records'].append({'opcode':op,'keys':keys});p=(p+n*STRIDES[op]+3)&~3
            tracks.append(track)
            if not selector:continue
            resource=index if selector in [1,2] else classless[index];model=struct.unpack_from('<H',w,t[resource]&0xffffff)[0];ids={}
            if t[model]>>24==0x44:
                mp=struct.unpack_from('<I',w,(t[model]&0xffffff)+16)[0];n=struct.unpack_from('<I',w,mp)[0];mp+=4+n*4
                n=struct.unpack_from('<I',w,mp)[0];mapped=struct.unpack_from('<%dI'%n,w,mp+4)
                used={k['value'][0]&0x7fff for r in track['records'] if r['opcode']==3 for k in r['keys']}
                ids={str(i):w[mapped[i]:mapped[i]+8].split(b'\0')[0].decode().lower() for i in used}
            directory=cine/f'model_{model}';definition=rig(model,directory)
            actors[f'{selector}:{index}']={**definition,'name':f'Actor_{resource}','resource':resource,'model':model,'animation_ids':ids}
        sequences.append({'cine_id':identity,'duration':end,'voice_id':voice_id,'voice_path':voice(voice_id),'tracks':tracks,'actors':actors,
                          'text':bank[dp['0x18']+rules['cine_ids'].index(identity)],'trigger':rules['trigger'][0]})
    snd=(folder/'Lvl-02.SND').read_bytes();p=12;sounds={}
    for _ in range(struct.unpack_from('<I',snd,8)[0]):
        i,n,f=struct.unpack_from('<III',snd,p)
        if i in sound_ids:
            dest=out/'audio'/f'{i}.wav';dest.write_bytes(snd[p+12:p+12+n]);sounds[str(i)]='res://'+dest.relative_to(ROOT).as_posix()
        p+=12+n
    for seq in sequences:save(cine/f"sequence_{seq['cine_id']}.json",{**seq,'sounds':sounds})
    save(out/'data/tutorial_models.json',list(definitions.values()))
    # Native level environment, using the same WAR/DAV reader and units.
    water=boxes(54)
    seesaw=next(e for e in es if e['class_id']==15);model=seesaw['model_res']
    q=struct.unpack_from('<I',w,(t[model]&0xffffff)+12)[0]
    solids=[dict(flags=v[0],min=list(v[1:4]),max=list(v[4:])) for i in range(struct.unpack_from('<I',w,q)[0]) for v in [struct.unpack_from('<I6h',w,q+4+i*16)]]
    def trajectory(identity):
        p=ex[identity][0];n=struct.unpack_from('<H',w,p)[0]
        return [list(struct.unpack_from('<3h',w,p+2+i*6)) for i in range(n)]
    save(out/'data/environment.json',{'water':water,'seesaw':{**seesaw,'rot_deg':[r*360/4096 for r in seesaw['rot']],
         'directory':f'res://assets/levels/lvl_02/models/{model}','boxes':solids,
         'trajectories':[trajectory(seesaw['props'][k]) for k in ['0x2c','0x30']],
         'ejection_boxes':[boxes(seesaw['props'][k])[0] for k in ['0x18','0x1c']]}})
    def model_boxes(entity):
        q=struct.unpack_from('<I',w,(t[entity['model_res']]&0xffffff)+12)[0]
        return [dict(flags=v[0],min=list(v[1:4]),max=list(v[4:])) for i in range(struct.unpack_from('<I',w,q)[0]) for v in [struct.unpack_from('<I6h',w,q+4+i*16)]]
    def target_ids(identity):
        return [entity['res'] for entity in es if t[entity['res']]&0xffffff in ex.get(identity,[])]
    save(out/'data/switches.json',{'buttons':[{**e,'directory':f"res://assets/levels/lvl_02/models/{e['model_res']}",'boxes':model_boxes(e),
        'targets':target_ids(e['props']['0x0'])+target_ids(e['props']['0x4'])} for e in es if e['class_id']==24],
        'lifts':[{**e,'directory':f"res://assets/levels/lvl_02/models/{e['model_res']}",'boxes':model_boxes(e)} for e in es if e['class_id']==36],
        'weighted_platforms':[{**e,'directory':f"res://assets/levels/lvl_02/models/{e['model_res']}",'boxes':model_boxes(e),
            'activation':boxes(e['props']['0x0']),'door_resource':target_ids(e['props']['0x8'])[0]} for e in es if e['class_id']==40]})
    header=next(e&0xffffff for e in t if e>>24==0x83);lists=struct.unpack_from('<4H',w,header);reverse=struct.unpack_from('<H',w,header+8)[0]
    directory=struct.unpack_from('<I',raw,0x14)[0];rec_at=struct.unpack_from('<I',raw,directory+10)[0];p=struct.unpack_from('<I',raw,directory+18)[0];n=struct.unpack_from('<I',raw,p)[0];p+=4;dx={}
    for _ in range(n):
        identity,c=struct.unpack_from('<HH',raw,p);dx[identity]=struct.unpack_from('<%dI'%c,raw,p+4);p+=4+c*4
    scroll=[]
    for i,identity in enumerate(lists):
        for p in dx.get(identity,[]):
            bitmap=(p-rec_at)//10;x,width,y,height,page=dav['rects'][bitmap]
            scroll.append({'list':identity,'bitmap':bitmap,'page':page,'rect':[x,y,width,height],'step':-1 if reverse&(1<<i) else 1})
    save(out/'data/texture_scroll.json',scroll)
    scenery=json.loads((out/'data/scenery.json').read_text());anchors=[]
    for rec in scroll:
        group=scenery.get(str(rec['page']));x,width,y,h=rec['rect'];points=[]
        if group:
            for i in range(0,len(group['verts']),3):
                if all(x/256<=uv[0]<=(x+width)/256 and y/256<=uv[1]<=(y+h)/256 for uv in group['uvs'][i:i+3]):points+=group['verts'][i:i+3]
        if points and max(p[1] for p in points)-min(p[1] for p in points)>1:
            low=min(p[1] for p in points);bottom=[p for p in points if p[1]<low+.5]
            anchors.append([sum(p[0] for p in bottom)/len(bottom),low,-sum(p[2] for p in bottom)/len(bottom)])
    from extract_inventory_ui import read_lists
    groups,banks=read_lists(raw);symbol=int(re.search(r'DAV_IDI_IGLTIDE_\s*=\s*(\d+)',props)[1]);first=groups[symbol][0]
    frames=next(b for b in banks if first in b);sheet=[];target=out/'effects/water';target.mkdir(parents=True,exist_ok=True)
    for i,bitmap in enumerate(frames):
        x,width,y,height,page=dav['rects'][bitmap];path=target/f'frame_{i}.png'
        page_image(raw,dav['pages'][page]).crop((x,y,x+width,y+height)).save(path);sheet.append('res://'+path.relative_to(ROOT).as_posix())
    # Intersect the original solid structures with the water surface. Spray
    # belongs at submerged supports, not across the whole bank of the river.
    for e in es:
        if e['class_id'] not in [12,36,40]:continue
        px,py,pz=e['pos']
        for zone in water:
            a,b=zone['min'],zone['max'];surface=-a[1]*.01
            if a[0]*.01<px<b[0]*.01 and -b[2]*.01<-pz<-a[2]*.01 and abs(py-surface)<3:
                anchors.append([px,surface+.05,-pz])
    for group in scenery.values():
        for i in range(0,len(group['verts']),3):
            tri=group['verts'][i:i+3]
            if len(tri)<3 or max(v[1] for v in tri)-min(v[1] for v in tri)<.5:continue
            if max(v[0] for v in tri)-min(v[0] for v in tri)>5 or max(v[2] for v in tri)-min(v[2] for v in tri)>5:continue
            for zone in water:
                a,b=zone['min'],zone['max'];surface=-a[1]*.01;cross=[]
                for j in range(3):
                    u,v=tri[j],tri[(j+1)%3]
                    if (u[1]-surface)*(v[1]-surface)>0 or abs(v[1]-u[1])<.001:continue
                    t0=(surface-u[1])/(v[1]-u[1]);cross.append([u[0]+(v[0]-u[0])*t0,surface+.05,-(u[2]+(v[2]-u[2])*t0)])
                if not cross:continue
                point=[sum(p[k] for p in cross)/len(cross) for k in range(3)]
                if not (a[0]*.01+1<point[0]<b[0]*.01-1 and -b[2]*.01+1<point[2]<-a[2]*.01-1):continue
                if all((p[0]-point[0])**2+(p[2]-point[2])**2>4 for p in anchors):anchors.append(point)
    sparse=[]
    for point in anchors:
        if all((p[0]-point[0])**2+(p[2]-point[2])**2>16 for p in sparse):sparse.append(point)
    save(out/'data/effects.json',{'sheets':{'water':sheet},'water_anchors':sparse,'river_spray':True})
    # PIRANA1 is Ralph's distinct death, not DEAD1 or STRIKE2.
    from extract_run_assets import decode
    p=struct.unpack_from('<I',w,(t[0]&0xffffff)+16)[0];qs=struct.unpack_from('<%dI'%struct.unpack_from('<I',w,p)[0],w,p+4)
    ptr=next(q for q in qs if q and w[q:q+8].split(b'\0')[0].lower()==b'pirana1')
    clip=decode(w,ptr,struct.unpack_from('<H',w,(t[0]&0xffffff)+24)[0])
    water_clips={'piranha_death':clip}
    for name in ['swim1','swim2','swim3','swim4']:
        ptr=next(q for q in qs if q and w[q:q+8].split(b'\0')[0].lower()==name.encode())
        water_clips[name]=decode(w,ptr,struct.unpack_from('<H',w,(t[0]&0xffffff)+24)[0])
    save(ROOT/'assets/models/ralph_water_data.json',water_clips)
    ids={35,54,94,264}|{c['sound_id'] for animation in water_clips.values() for c in animation['sound_cues']};p=12
    for _ in range(struct.unpack_from('<I',snd,8)[0]):
        i,n,f=struct.unpack_from('<III',snd,p)
        if i in ids:(out/'audio'/f'{i}.wav').write_bytes(snd[p+12:p+12+n])
        if i==35:(ROOT/'assets/audio/sfx/original_swim_loop.wav').write_bytes(snd[p+12:p+12+n])
        if i==51:(ROOT/'assets/audio/sfx/original_surface_swim.wav').write_bytes(snd[p+12:p+12+n])
        p+=12+n
    save(ROOT/'assets/models/ralph_water_audio.json',{'51':{'path':'res://assets/audio/sfx/original_surface_swim.wav','loop':False}})
    print('Environment:',len(water),'water zones,',len(scroll),'scroll rectangles,',len(anchors),'sprays')
    print('Native Daffy tutorial:',[(s['cine_id'],s['voice_id'],s['duration'],len(s['actors'])) for s in sequences],rules['trigger'])

def GameBurntText(root):
    return json.loads((root/'assets/levels/lvl_01/data/daffy.json').read_text(encoding='utf8'))['burnt']['text']

if __name__=='__main__':main()
