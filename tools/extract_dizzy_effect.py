"""Recover AETOIL01 / TURN1 used by Wolf::Fx0_Start from native WAR/DAV."""
import json
from pathlib import Path
import struct
import sys
from extract_shared_items import read_rig, page_image

ROOT = Path(__file__).resolve().parents[1]

def main():
    decomp, folder = map(Path,sys.argv[1:3])
    sys.path.insert(0,str(decomp/'tools'))
    import level_editor as editor
    import war_meshes
    war_path = next(folder.glob('*.[wW][aA][rR]'))
    dav_path = next(folder.glob('*.[dD][aA][vV]'))
    war, raw = war_path.read_bytes(), dav_path.read_bytes()
    table = struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
    at = next(e&0xffffff for e in table if e>>24 == 0x82)
    count = struct.unpack_from('<I',war,at)[0]
    at += 4
    exports = {}
    for _ in range(count):
        identity, n = struct.unpack_from('<HH',war,at)
        exports[identity] = struct.unpack_from('<%dI'%n,war,at+4)
        at += 4+n*4
    # scenaric_props.h: WAR_IDO_AETOIL01 = 2.
    resource = next(e for e in table if (e&0xffffff) == exports[2][0])
    rig = read_rig(war,resource,editor,war_meshes,editor.dav_tables(raw),{'turn1':'turn1'})
    assert set(rig['animations']) == {'turn1'}
    rig.update(rotation_order='ZXY',rotation_axis_sign=[1,1,-1])
    out = ROOT/'assets/effects/dizzy'
    (out/'textures').mkdir(parents=True,exist_ok=True)
    (out/'worn_data.json').write_text(json.dumps(rig,separators=(',',':')),encoding='utf8')
    dav = war_meshes.read_dav(dav_path)
    materials = {}
    for page in rig['surfaces']:
        if int(page) < 0: continue
        record = dav['pages'][int(page)]
        page_image(raw,record).save(out/'textures'/f'page_{page}.png')
        materials[page] = record['kind']
    metadata = dict(model='AETOIL01',animation='turn1',source=str(war_path),
                    resource=table.index(resource),export_id=2,joint=0,
                    offset_native=[0,-150,0],offset_godot=[0,1.5,0],
                    directory='res://assets/effects/dizzy',materials=materials,
                    loop_animations=['turn1'])
    (out/'source.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf8')
    print('AETOIL01 TURN1:',rig['animations']['turn1']['duration'],'s;',len(rig['joints']),'joints')

if __name__ == '__main__': main()
