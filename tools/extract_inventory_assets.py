"""Separate the tutorial rocket from the merged mesh, checking every triangle.
Usage: python tools/extract_inventory_assets.py DECOMP_REPO PC_LVL_00
The source WAR/DAV and the existing complete object JSON are read-only.
"""
from collections import Counter
import copy
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parent.parent

def main():
    sys.path.insert(0, str(Path(sys.argv[1]) / 'tools'))
    import level_editor as editor
    folder = Path(sys.argv[2])
    files = {p.suffix.lower(): p for p in folder.iterdir()}
    war = files['.war'].read_bytes()
    dav = files['.dav'].read_bytes()
    data_dir = ROOT / 'assets/levels/lvl_00/data'
    entities = json.loads((data_dir / 'entities.json').read_text())
    rocket = next(e for e in entities if e['class_id'] == 10)
    assert rocket['rot_deg'] == [0, 0, 0], 'Add the source rotation transform before extracting other levels'
    resource, = struct.unpack_from('<I', war, 16 + rocket['model_res'] * 4)
    geometry = editor.geometry(war, editor.dav_tables(dav), resource & 0xffffff, resource >> 24 == 0x44)
    static = copy.deepcopy(json.loads((data_dir / 'level_objects_data.json').read_text()))
    local = {}
    def key(verts, uvs):
        # The original export rounds positions to 4 and UVs to 5 decimal places.
        return tuple(round(c, 4) for v in verts for c in v) + tuple(round(c, 5) for uv in uvs for c in uv)
    removed = 0
    for page, packed in geometry['groups'].items():
        grp = {'page': int(page), 'verts': [], 'uvs': [], 'cols': []}
        world_verts = []
        for i in range(0, len(packed), 8):
            x, y, z, u, v, r, g, b = packed[i:i+8]
            pos = [round(x * .01, 4), round(-y * .01, 4), round(z * .01, 4)]
            grp['verts'].append(pos)
            grp['uvs'].append([u, v])
            grp['cols'].append([r / (128 if int(page) >= 0 else 255), g / (128 if int(page) >= 0 else 255), b / (128 if int(page) >= 0 else 255)])
            world_verts.append([round(a+b, 4) for a, b in zip(pos, rocket['pos'])])
        wanted = Counter(key(world_verts[i:i+3], grp['uvs'][i:i+3]) for i in range(0, len(world_verts), 3))
        local_indices = {}
        for i in range(0, len(world_verts), 3):
            local_indices.setdefault(key(world_verts[i:i+3], grp['uvs'][i:i+3]), []).append(i)
        merged = static[page]
        keep = {name: [] for name in ['verts', 'uvs', 'cols']}
        for i in range(0, len(merged['verts']), 3):
            triangle = key(merged['verts'][i:i+3], merged['uvs'][i:i+3])
            if wanted[triangle] > 0:
                wanted[triangle] -= 1
                at = local_indices[triangle].pop()
                divisor = 128 if int(page) >= 0 else 255
                for original, decoded in zip(merged['cols'][i:i+3], grp['cols'][at:at+3]):
                    assert [round(c * divisor) for c in original] == [round(c * divisor) for c in decoded], 'Rocket colour mismatch'
                grp['cols'][at:at+3] = merged['cols'][i:i+3]
                removed += 1
            else:
                for channel in keep:
                    keep[channel].extend(merged[channel][i:i+3])
        assert not +wanted, f'Unmatched rocket triangles: {sum((+wanted).values())}'
        static[page] = keep
        local[page] = grp
    def vertex_key(page, vertex, uv, color):
        return (page, tuple(round(c, 4) for c in vertex), tuple(round(c, 5) for c in uv), tuple(color))
    original = json.loads((data_dir / 'level_objects_data.json').read_text())
    before = Counter(vertex_key(page, v, uv, c) for page, grp in original.items()
                     for v, uv, c in zip(grp['verts'], grp['uvs'], grp['cols']))
    after = Counter(vertex_key(page, v, uv, c) for page, grp in static.items()
                    for v, uv, c in zip(grp['verts'], grp['uvs'], grp['cols']))
    after.update(vertex_key(page, [a+b for a, b in zip(v, rocket['pos'])], uv, c)
                 for page, grp in local.items() for v, uv, c in zip(grp['verts'], grp['uvs'], grp['cols']))
    assert before == after, 'Splitting changed positions, UVs, or colors'
    (data_dir / 'level_static_data.json').write_text(json.dumps(static, separators=(',', ':')))
    (data_dir / 'rocket_data.json').write_text(json.dumps(local, separators=(',', ':')))
    print(f'Separated {removed} original rocket triangles; all matched the merged mesh')
    print(f'Preserved all {sum(before.values())} object vertices, UVs and colors')
    if (data_dir/'tutorial_progress.json').exists():
        from extract_tutorial_progress import main as separate_progress_objects
        separate_progress_objects()

if __name__ == '__main__':
    main()
