"""Recover Butterfly alternate models and appearance zones from native WAR."""
import json
import struct
import sys
from pathlib import Path
from extract_shared_items import read_rig, page_image

ROOT = Path(__file__).resolve().parents[1]

def main():
    decomp, folder = map(Path,sys.argv[1:3])
    sys.path.insert(0,str(decomp/'tools'))
    import level_editor as editor
    import war_meshes
    slug = folder.name.lower().replace('-','_')
    base = ROOT/'assets/levels'/slug
    war = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    dav_path = next(folder.glob('*.[dD][aA][vV]'))
    raw = dav_path.read_bytes()
    tables = editor.dav_tables(raw)
    dav = war_meshes.read_dav(dav_path)
    table = struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
    cursor = next(e&0xffffff for e in table if e>>24==0x82)
    count = struct.unpack_from('<I',war,cursor)[0]
    cursor += 4
    exports = {}
    for _ in range(count):
        identity,length = struct.unpack_from('<HH',war,cursor)
        exports[identity] = struct.unpack_from('<%dI'%length,war,cursor+4)
        cursor += 4+length*4
    entities = json.loads((base/'data/entities.json').read_text(encoding='utf8'))
    records = []
    variants = {}
    for entity in entities:
        if entity['class_id'] != 161:
            continue
        variant = int(entity['props']['0x0'])
        identity = 185 if variant else 184
        if identity not in variants:
            resource = next(e for e in table if (e&0xffffff)==exports[identity][0])
            at = resource&0xffffff
            pointer = struct.unpack_from('<I',war,at+16)[0]
            n = struct.unpack_from('<I',war,pointer)[0]
            names = [war[p:p+8].split(b'\0')[0].decode().lower() for p in struct.unpack_from('<%dI'%n,war,pointer+4) if p]
            rig = read_rig(war,resource,editor,war_meshes,tables,{name:name for name in names})
            rig.update(rotation_order='ZXY',rotation_axis_sign=[1,1,-1])
            out = base/'butterflies'/str(identity)
            (out/'textures').mkdir(parents=True,exist_ok=True)
            (out/'worn_data.json').write_text(json.dumps(rig,separators=(',',':')),encoding='utf8')
            materials = {}
            for page in rig['surfaces']:
                if int(page)<0: continue
                record = dav['pages'][int(page)]
                page_image(raw,record).save(out/'textures'/f'page_{page}.png')
                materials[page] = record['kind']
            definition = dict(directory='res://'+out.relative_to(ROOT).as_posix(),materials=materials,
                              model_export_id=identity,loop_animations=['fly'])
            (out/'source.json').write_text(json.dumps(definition,indent=2)+'\n',encoding='utf8')
            variants[identity] = definition
        boxes = [dict(min=list(struct.unpack_from('<3h',war,p+4)),max=list(struct.unpack_from('<3h',war,p+10))) for p in exports[entity['props']['0x4']]]
        records.append(dict(res=entity['res'],variant=variant,directory=variants[identity]['directory'],zones=boxes))
    result = dict(source='Butterfly::PostLoadInit / Update / SetState',butterflies=records,
                  radius_m=2.0,angular_speed=550*6.283185307179586/4096,vertical_speed=.8,
                  vertical_range_m=2.0,quarter_turn_units=1023,appearance_frames=3)
    (base/'data/butterflies.json').write_text(json.dumps(result,separators=(',',':')),encoding='utf8')
    print(slug,len(records),'butterflies;',len(variants),'alternate models')

if __name__=='__main__': main()
