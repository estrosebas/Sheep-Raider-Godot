"""Recover WMS_EXPLOSION / AEXPLOS2 BOOM (Wolf state 0x0e)."""
import json
import struct
import sys
from pathlib import Path
from extract_shared_items import read_rig, page_image

ROOT = Path(__file__).resolve().parents[1]

def main():
    decomp, folder = map(Path, sys.argv[1:3])
    sys.path.insert(0, str(decomp / 'tools'))
    import level_editor as editor
    import war_meshes
    war_path = next(folder.glob('*.[wW][aA][rR]'))
    dav_path = next(folder.glob('*.[dD][aA][vV]'))
    war, raw = war_path.read_bytes(), dav_path.read_bytes()
    table = struct.unpack_from('<%dI' % struct.unpack_from('<I', war, 12)[0], war, 16)
    candidates = []
    for index, resource in enumerate(table):
        if resource >> 24 != 0x44:
            continue
        pointer = struct.unpack_from('<I', war, (resource & 0xffffff) + 16)[0]
        count = struct.unpack_from('<I', war, pointer)[0]
        names = [war[p:p+8].split(b'\0')[0].lower() for p in struct.unpack_from('<%dI' % count, war, pointer+4) if p]
        # AEXPLOS1 has BOOM + STAND1; the fatal-fall model has BOOM only.
        if names == [b'boom']:
            candidates.append((index, resource))
    assert len(candidates) == 1, candidates
    index, resource = candidates[0]
    rig = read_rig(war, resource, editor, war_meshes, editor.dav_tables(raw), {'boom':'boom'})
    rig.update(rotation_order='ZXY', rotation_axis_sign=[1,1,-1])
    out = ROOT / 'assets/effects/void_impact'
    (out / 'textures').mkdir(parents=True, exist_ok=True)
    (out / 'worn_data.json').write_text(json.dumps(rig, separators=(',',':')), encoding='utf8')
    materials = {}
    dav = war_meshes.read_dav(dav_path)
    for page in rig['surfaces']:
        if int(page) < 0:
            continue
        record = dav['pages'][int(page)]
        page_image(raw, record).save(out / 'textures' / f'page_{page}.png')
        materials[page] = record['kind']
    metadata = dict(model='AEXPLOS2', animation='boom', resource=index,
                    source=str(war_path), state='WOLF_ST_DIE_FELL',
                    directory='res://assets/effects/void_impact', materials=materials)
    (out/'source.json').write_text(json.dumps(metadata, indent=2)+'\n', encoding='utf8')
    print('AEXPLOS2 / BOOM:', rig['animations']['boom']['duration'], 'seconds')

if __name__ == '__main__':
    main()
