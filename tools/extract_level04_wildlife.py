"""Original Level04 bull, noisy leaf polygons and ambient Leaf records.

Does not modify shared animations/items. Run after native level import:
python tools/extract_level04_wildlife.py DECOMP_REPO PC_LVL_04
"""
import json
import re
import struct
import sys
from pathlib import Path

from extract_inventory_ui import read_lists
from extract_shared_items import page_image

ROOT = Path(__file__).resolve().parents[1]


def extract(decomp, folder):
    decomp, folder = Path(decomp), Path(folder)
    slug = folder.name.lower().replace('-', '_')
    out = ROOT / 'assets/levels' / slug
    entities = json.loads((out / 'data/entities.json').read_text(encoding='utf8'))
    manifest = json.loads((out / 'data/manifest.json').read_text(encoding='utf8'))
    solids = json.loads((out / 'data/solid_boxes.json').read_text(encoding='utf8'))
    runtime = json.loads((out / 'data/runtime.json').read_text(encoding='utf8'))
    war = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    table = struct.unpack_from('<%dI' % struct.unpack_from('<I', war, 12)[0], war, 16)
    pointer = next(value & 0xffffff for value in table if value >> 24 == 0x82)
    count = struct.unpack_from('<I', war, pointer)[0]
    pointer += 4
    exports = {}
    for _ in range(count):
        identity, length = struct.unpack_from('<HH', war, pointer)
        exports[identity] = struct.unpack_from('<%dI' % length, war, pointer + 4)
        pointer += 4 + length * 4

    def boxes(identity):
        return [{'flags': values[0], 'min': list(values[1:4]), 'max': list(values[4:])}
                for at in exports.get(identity, [])
                for values in [struct.unpack_from('<I6h', war, at)]]

    def trajectory(identity):
        if not exports.get(identity):
            return []
        at = exports[identity][0]
        count = struct.unpack_from('<H', war, at)[0]
        return [list(struct.unpack_from('<3h', war, at + 2 + index * 6)) for index in range(count)]

    def common(entity):
        return {**entity, 'directory': manifest['models'][str(entity['model_res'])]['directory'],
                'boxes': next((entry['boxes'] for entry in solids if entry['res'] == entity['res']), [])}

    bulls = []
    leaf_zones = []
    leaves = []
    for entity in entities:
        props = entity['props']
        if entity['class_id'] == 43:
            bulls.append({**common(entity), 'activation_boxes': boxes(props['0x0']),
                          'movement_boxes': boxes(props['0x8']), 'no_return_boxes': boxes(props['0xc']),
                          'asleep': bool(props['0x4']), 'wake_speed_pct': props['0x20'],
                          'charge_speed': 8.0, 'close_wake_distance': 2.0, 'hit_distance': 1.5,
                          'retarget_seconds': 2.0, 'hit_recovery_seconds': 10.0,
                          'source': 'objects/bull.cpp::PostLoadInit/SetState/Update/HandleMessage'})
        elif entity['class_id'] == 54:
            polygon = trajectory(props['0x8'])
            guardian = next((candidate['res'] for candidate in entities
                             if table[candidate['res']] & 0xffffff in exports.get(props['0x4'], [])), None)
            source_x, _, source_z = entity['pos']
            radius = max((abs(point[0] * .01 - source_x) + abs(point[2] * .01 - source_z)
                          for point in polygon), default=0)
            leaf_zones.append({**common(entity), 'polygon': polygon, 'zone': boxes(props['0x0']),
                               'guardian': guardian, 'radius': radius, 'height_tolerance': .6,
                               'source': 'objects/heapofleaf.cpp::DetectMovers/PointInPolygon'})
        elif entity['class_id'] == 191:
            leaves.append({**common(entity), 'range': props['0x0'] * .01,
                           'respawn_min': .75, 'respawn_max': 2.25,
                           'source': 'objects/leaf.cpp::PostLoadInit/Update'})

    sys.path.insert(0, str(decomp / 'tools'))
    import war_meshes
    dav_path = next(folder.glob('*.[dD][aA][vV]'))
    raw = dav_path.read_bytes()
    dav = war_meshes.read_dav(dav_path)
    groups, banks = read_lists(raw)
    symbols = dict((name, int(value)) for name, value in re.findall(
        r'(DAV_IDI_\w+)\s*=\s*(\d+)',
        (decomp / 'src/include/scenaric_props.h').read_text()))
    sheets = {}
    for name, symbol in [('leaves', 'DAV_IDI_IGLEAVE1'), ('dust', 'DAV_IDI_IGLSMOK_')]:
        first = groups[symbols[symbol]][0]
        frames = next(bank for bank in banks if first in bank)
        directory = out / 'effects/wildlife' / name
        directory.mkdir(parents=True, exist_ok=True)
        paths = []
        for index, bitmap in enumerate(frames):
            x, width, y, height, page = dav['rects'][bitmap]
            path = directory / f'frame_{index}.png'
            page_image(raw, dav['pages'][page]).crop((x, y, x + width, y + height)).save(path)
            paths.append('res://' + path.relative_to(ROOT).as_posix())
        sheets[name] = paths
    data = {'bulls': bulls, 'leaf_zones': leaf_zones, 'leaves': leaves,
            'sheets': sheets, 'sounds': runtime['sounds'],
            'leaf_sound_id': 129, 'charge_sound_id': 253,
            'particle_params': {'leaves': {'life': .5, 'period': 819 / 4096,
                                          'size_start': .4, 'size_end': .9, 'v_speed': -.2, 'h_speed': .1},
                                'dust': {'life': 2, 'period': .125, 'size_start': .8,
                                         'size_end': 1.8, 'v_speed': .6, 'h_speed': .5}}}
    # Each controller only needs its own definition; no hardcoded level paths.
    for record in bulls:
        record['dust_frames'] = sheets['dust']
    for record in leaf_zones:
        record['leaf_frames'] = sheets['leaves']
    (out / 'data/wildlife.json').write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf8')
    print(slug, 'bulls', len(bulls), 'noisy polygons', len(leaf_zones), 'ambient leaves', len(leaves),
          'sprites', {name: len(frames) for name, frames in sheets.items()})


if __name__ == '__main__':
    extract(*sys.argv[1:3])
