"""Compare local PNG/geometry data to the decomp repository's PC decoder.

python tools/audit_source.py --decomp PATH --level PATH_TO_LVL_00
Requires Pillow. Reads the source game and repository without modifying them.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import struct
import sys
from PIL import Image

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--decomp', type=Path, required=True)
    parser.add_argument('--level', type=Path, required=True)
    args = parser.parse_args()
    sys.path.insert(0, str(args.decomp / 'tools'))
    import level_editor as editor
    import war_meshes
    root = Path(__file__).resolve().parent.parent
    files = {p.suffix.lower(): p for p in args.level.iterdir()}
    dav_path = files['.dav']
    raw = dav_path.read_bytes()
    dav = war_meshes.read_dav(dav_path)
    report = {'source': str(args.level), 'pages': [], 'geometry': [], 'passed': True}
    for page in dav['pages']:
        expected = []
        start = page['offset'] + 10
        for v, in struct.iter_unpack('<H', raw[start:page['offset'] + page['bytes']]):
            typ = page['format'] & 3
            if typ == 2:
                rgba = [((v >> 8) & 15) * 17, ((v >> 4) & 15) * 17, (v & 15) * 17, (v >> 12) * 17]
            elif typ == 1:
                rgba = [int(((v >> 10) & 31) * 255 / 31), int(((v >> 5) & 31) * 255 / 31),
                        int((v & 31) * 255 / 31), 255 if v & 0x8000 else 0]
            else:
                rgba = [int((v >> 11) * 255 / 31), int(((v >> 5) & 63) * 255 / 63), int((v & 31) * 255 / 31), 255]
            rgba[3] = 255 if page['kind'] == 'opaque' else 255 - rgba[3]
            expected.append(tuple(rgba))
        image = Image.open(root / f"assets/levels/lvl_00/textures/page_{page['index']}.png").convert('RGBA')
        actual = list(image.get_flattened_data())
        matched = (image.size == (page['w'], page['h']) and actual == expected)
        report['pages'].append({'page': page['index'], 'kind': page['kind'], 'format': page['format'], 'matched': matched})
        report['passed'] &= matched
    war = files['.war'].read_bytes()
    table = editor.dav_tables(raw)
    count, = struct.unpack_from('<I', war, 12)
    groups = {}
    for entry, in struct.iter_unpack('<I', war[16:16 + count * 4]):
        if entry >> 24 in (3, 0x0b, 0x26):
            for page, vertices in editor.geometry(war, table, entry & 0xffffff, False)['groups'].items():
                groups.setdefault(page, []).extend(vertices)
    current = json.loads((root / 'assets/levels/lvl_00/data/scenery_data.json').read_text())
    def key(values):
        return tuple(round(v, 4) for v in values)
    report['passed'] &= set(groups) == set(current)
    for page, vertices in groups.items():
        group = current[page]
        divisor = 128 if int(page) >= 0 else 255
        actual = Counter(key(pos + uv + [round(c * divisor) for c in col])
                         for pos, uv, col in zip(group['verts'], group['uvs'], group['cols']))
        expected = Counter(key([vertices[i] * .01, -vertices[i+1] * .01, vertices[i+2] * .01]
                               + vertices[i+3:i+8]) for i in range(0, len(vertices), 8))
        matched = actual == expected
        report['geometry'].append({'page': int(page), 'vertices': len(vertices) // 8, 'matched': matched})
        report['passed'] &= matched
    destination = root / 'validation/source_audit.json'
    destination.parent.mkdir(exist_ok=True)
    destination.write_text(json.dumps(report, indent=2) + '\n')
    print(f"{len(report['pages'])} pages; {sum(g['vertices'] for g in report['geometry'])} scenery vertices; passed={report['passed']}")
    return 0 if report['passed'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
