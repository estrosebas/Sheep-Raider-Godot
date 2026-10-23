"""Native Catapult/SmallRock data, controller pose and ICTJAUG1 gauge."""
import json
import struct
import sys
from pathlib import Path
from extract_shared_items import page_image, read_rig
from extract_inventory_ui import read_lists
from extract_run_assets import decode

ROOT = Path(__file__).resolve().parents[1]

def main():
    decomp,folder = map(Path,sys.argv[1:3])
    sys.path.insert(0,str(decomp/'tools'))
    import war_meshes
    import level_editor as editor
    base = ROOT/'assets/levels'/folder.name.lower().replace('-','_')
    war = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    table = struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
    cursor = next(e&0xffffff for e in table if e>>24==0x82)
    count = struct.unpack_from('<I',war,cursor)[0]; cursor += 4; exports = {}
    for _ in range(count):
        identity,n = struct.unpack_from('<HH',war,cursor)
        exports[identity] = struct.unpack_from('<%dI'%n,war,cursor+4); cursor += 4+n*4
    def boxes(model):
        p = struct.unpack_from('<I',war,(table[model]&0xffffff)+12)[0]
        return [dict(flags=struct.unpack_from('<I',war,p+4+i*16)[0],min=list(struct.unpack_from('<3h',war,p+8+i*16)),max=list(struct.unpack_from('<3h',war,p+14+i*16))) for i in range(struct.unpack_from('<I',war,p)[0])] if p else []
    entities = json.loads((base/'data/entities.json').read_text(encoding='utf8'))
    catapult_entities = [e for e in entities if e['class_id']==56]
    if not catapult_entities:
        print(base.name,'has no Catapult records'); return
    path = base/'data/catapults.json'
    data = json.loads(path.read_text(encoding='utf8')) if path.exists() else {'catapults':[]}
    for entity in catapult_entities:
        if any(cat['res']==entity['res'] for cat in data['catapults']): continue
        props=entity['props'];p=exports[props['0x24']][0];n=struct.unpack_from('<H',war,p)[0]
        trajectory=[list(struct.unpack_from('<3h',war,p+2+i*6)) for i in range(n)]
        assert len(trajectory)==3
        activation=[dict(flags=struct.unpack_from('<I',war,p)[0],min=list(struct.unpack_from('<3h',war,p+4)),max=list(struct.unpack_from('<3h',war,p+10))) for p in exports[props['0x0']]]
        data['catapults'].append({**entity,'directory':f'res://assets/levels/{base.name}/models/{entity["model_res"]}',
                                'boxes':[b for b in boxes(entity['model_res']) if not b['flags']&1],
                                'activation':activation,'trajectory':trajectory,'max_throw_offset':props['0x14']*.01,
                                'arm_lengths':[props[key]*.01 for key in ['0x4','0x8','0xc']]})
    for cat in data['catapults']:
        cat['model_boxes'] = boxes(cat['model_res'])
        cat['camera'] = None
        if cat['props']['0x18']:
            focal,*values = struct.unpack_from('<H6h',war,exports[cat['props']['0x18']][0])
            cat['camera'] = dict(focal=focal,rotation=values[:3],eye=values[3:])
        cat['status'] = 'Shared operating controller; native power, bucket, arc, camera and HUD'
    data['small_rocks'] = [{**e,'directory':f'res://assets/levels/{base.name}/models/{e["model_res"]}', 'boxes':boxes(e['model_res'])} for e in entities if e['class_id']==65]
    data['rules'] = dict(power_min=0,power_max=1024,power_step=6,original_update_hz=60,
                         camera_hold_seconds=2,return_seconds=1.024,fire_sound=263,power_sound=118)
    path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf8')
    if '--level-data-only' in sys.argv:
        print(base.name,'native catapult/rock data; shared animations, UI and break assets preserved')
        return
    # Ralph WOLF_ST_CATAPULT_OPERATE switches STAND0 <-> TURN.
    at=table[0]&0xffffff;p=struct.unpack_from('<I',war,at+16)[0];n=struct.unpack_from('<I',war,p)[0]
    names={war[q:q+8].split(b'\0')[0].lower():q for q in struct.unpack_from('<%dI'%n,war,p+4) if q}
    joints=struct.unpack_from('<H',war,at+24)[0]
    animations={'catapult_turn':decode(war,names[b'turn'],joints)}
    (ROOT/'assets/models/ralph_catapult_data.json').write_text(json.dumps(animations,separators=(',',':')),encoding='utf8')
    dav_path=next(folder.glob('*.[dD][aA][vV]'));raw=dav_path.read_bytes();dav=war_meshes.read_dav(dav_path)
    groups,_=read_lists(raw);out=ROOT/'assets/ui/catapult';out.mkdir(parents=True,exist_ok=True)
    metadata={'source':str(dav_path),'gauge_origin':[8,16],'pointer_x':[24,108],'pointer_y':39,'assets':{}}
    for identity,name in [(71,'gauge'),(55,'frame')]:
        bitmap=groups[identity][0];x,w,y,h,page=dav['rects'][bitmap]
        page_image(raw,dav['pages'][page]).crop((x,y,x+w,y+h)).save(out/f'{name}.png')
        metadata['assets'][name]=dict(resource=identity,bitmap=bitmap,page=page,rect=[x,y,w,h])
    (out/'source.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf8')
    resource=next(e for e in table if (e&0xffffff)==exports[88][0])
    rig=read_rig(war,resource,editor,war_meshes,editor.dav_tables(raw),{'break':'break','stand':'stand'})
    rig.update(rotation_order='ZXY',rotation_axis_sign=[1,1,-1])
    broken=ROOT/'assets/effects/small_rock_break';(broken/'textures').mkdir(parents=True,exist_ok=True)
    (broken/'worn_data.json').write_text(json.dumps(rig,separators=(',',':')),encoding='utf8')
    materials={}
    for page in rig['surfaces']:
        if int(page)<0: continue
        record=dav['pages'][int(page)]
        page_image(raw,record).save(broken/'textures'/f'page_{page}.png');materials[page]=record['kind']
    (broken/'source.json').write_text(json.dumps(dict(directory='res://assets/effects/small_rock_break',materials=materials),indent=2)+'\n',encoding='utf8')
    print('Catapults:',len(data['catapults']),'SmallRocks:',len(data['small_rocks']),metadata)

if __name__=='__main__': main()
