"""Level 04 DAV scrolling regions and native water sprites.

Run after extract_imported_level_content.py; it owns environment/interactions/
switches/elastic, and this supplement deliberately leaves those files intact.
Usage: python tools/extract_level04_environment.py DECOMP_REPO PC_LVL_04
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
    sys.path.insert(0, str(decomp / 'tools'))
    import war_meshes

    slug = folder.name.lower().replace('-', '_')
    if slug not in ('lvl_04', 'lvl_05'):
        raise ValueError('Validated native environment layouts: lvl_04 and lvl_05.')
    out = ROOT / 'assets/levels' / slug
    war = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    dav_path = next(folder.glob('*.[dD][aA][vV]'))
    raw = dav_path.read_bytes()
    dav = war_meshes.read_dav(dav_path)
    table = struct.unpack_from('<%dI' % struct.unpack_from('<I', war, 12)[0], war, 16)
    header = next(value & 0xffffff for value in table if value >> 24 == 0x83)
    identities = struct.unpack_from('<4H', war, header)
    reverse = struct.unpack_from('<H', war, header + 8)[0]
    directory = struct.unpack_from('<I', raw, 0x14)[0]
    records_at = struct.unpack_from('<I', raw, directory + 10)[0]
    pointer = struct.unpack_from('<I', raw, directory + 18)[0]
    count = struct.unpack_from('<I', raw, pointer)[0]
    pointer += 4
    exports = {}
    for _ in range(count):
        identity, length = struct.unpack_from('<HH', raw, pointer)
        exports[identity] = struct.unpack_from('<%dI' % length, raw, pointer + 4)
        pointer += 4 + length * 4
    scroll = []
    for index, identity in enumerate(identities):
        if not identity:
            continue
        for pointer in exports.get(identity, []):
            bitmap = (pointer - records_at) // 10
            x, width, y, height, page = dav['rects'][bitmap]
            scroll.append({'list': identity, 'bitmap': bitmap, 'page': page,
                           'rect': [x, y, width, height],
                           'step': -1 if reverse & (1 << index) else 1})

    symbols = dict((name, int(value)) for name, value in re.findall(
        r'(DAV_IDI_\w+)\s*=\s*(\d+)',
        (decomp / 'src/include/scenaric_props.h').read_text()))
    groups, banks = read_lists(raw)
    first = groups[symbols['DAV_IDI_IGLTIDE_']][0]
    frames = next(bank for bank in banks if first in bank)
    target = out / 'effects/water'
    target.mkdir(parents=True, exist_ok=True)
    sheets = []
    for index, bitmap in enumerate(frames):
        x, width, y, height, page = dav['rects'][bitmap]
        path = target / f'frame_{index}.png'
        page_image(raw, dav['pages'][page]).crop((x, y, x + width, y + height)).save(path)
        sheets.append('res://' + path.relative_to(ROOT).as_posix())

    # Optional spray belongs only to tall scrolling water geometry, never the
    # flat river surface. Keep the same coordinate conversion as levels 01/02.
    scenery = json.loads((out / 'data/scenery.json').read_text(encoding='utf8'))
    anchors = []
    for region in scroll:
        mesh = scenery.get(str(region['page']), {})
        points = []
        x, y, width, height = region['rect']
        for offset in range(0, len(mesh.get('verts', [])), 3):
            uvs = mesh['uvs'][offset:offset + 3]
            if len(uvs) == 3 and all(x / 256 <= uv[0] <= (x + width) / 256
                                     and y / 256 <= uv[1] <= (y + height) / 256 for uv in uvs):
                points.extend(mesh['verts'][offset:offset + 3])
        if not points or max(point[1] for point in points) - min(point[1] for point in points) < 2:
            continue
        low = min(point[1] for point in points)
        bottom = [point for point in points if point[1] < low + .5]
        anchor = [sum(point[0] for point in bottom) / len(bottom), low,
                  -sum(point[2] for point in bottom) / len(bottom)]
        if all(sum((anchor[i] - other[i]) ** 2 for i in range(3)) > 4 for other in anchors):
            anchors.append(anchor)

    def save(filename, data):
        (out / 'data' / filename).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf8')

    save('texture_scroll.json', scroll)
    save('effects.json', {'sheets': {'water': sheets}, 'water_anchors': anchors,
                          'river_spray': True,
                          'source': {'scroll_header': 'WAR type 0x83', 'scroll_lists': list(identities),
                                     'reverse_mask': reverse, 'water_sprite': 'DAV_IDI_IGLTIDE_',
                                     'water_regions': 'WAR_IDO_WATERBOX (54)',
                                     'hazard': 'Native class 50/117 entities select their shared water hazard controller'}})
    # The existing switch controller already dispatches to each native target
    # resource. Supplement it with the cliff boulder's box/camera/TIMER record.
    pointer = next(value & 0xffffff for value in table if value >> 24 == 0x82)
    count = struct.unpack_from('<I', war, pointer)[0]
    pointer += 4
    war_exports = {}
    for _ in range(count):
        identity, length = struct.unpack_from('<HH', war, pointer)
        war_exports[identity] = struct.unpack_from('<%dI' % length, war, pointer + 4)
        pointer += 4 + length * 4

    entities = json.loads((out / 'data/entities.json').read_text(encoding='utf8'))
    manifest = json.loads((out / 'data/manifest.json').read_text(encoding='utf8'))
    solid_records = json.loads((out / 'data/solid_boxes.json').read_text(encoding='utf8'))
    switches = json.loads((out / 'data/switches.json').read_text(encoding='utf8'))
    stones = []
    for entity in entities:
        if entity['class_id'] != 52:
            continue
        props = entity['props']
        zones = []
        for pointer in war_exports.get(props['0x0'], []):
            values = struct.unpack_from('<I6h', war, pointer)
            zones.append({'flags': values[0], 'min': list(values[1:4]), 'max': list(values[4:])})
        camera = None
        if war_exports.get(props['0x4']):
            values = struct.unpack_from('<H6h', war, war_exports[props['0x4']][0])
            camera = {'focal': values[0], 'rotation': list(values[1:4]), 'eye': list(values[4:])}
        model = manifest['models'][str(entity['model_res'])]
        solids = next((record['boxes'] for record in solid_records if record['res'] == entity['res']), [])
        stones.append({**entity, 'directory': model['directory'], 'boxes': solids,
                       'crush_zones': zones, 'camera': camera, 'trigger_delay_ms': props['0x8'],
                       'crush_fraction': 11 / 16,
                       'source': 'objects/triggedstone.cpp::PostLoadInit/Update/CrushVictims/HandleMessage'})
    switches['triggered_stones'] = stones
    save('switches.json', switches)
    print(slug, 'scroll regions', len(scroll), 'water sprite frames', len(sheets),
          'waterfall spray anchors', len(anchors), 'button boulders', len(stones))


if __name__ == '__main__':
    extract(*sys.argv[1:3])
