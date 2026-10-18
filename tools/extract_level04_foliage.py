"""Isolate the native opaque leaf-heap triangles, retaining geometry/UV/RGB.
python tools/extract_level04_foliage.py DECOMP_REPO ORIGINAL_LEVEL_FOLDER
"""
import collections
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def main(decomp, folder):
    sys.path.insert(0, str(Path(decomp)/'tools'))
    import level_editor
    folder = Path(folder)
    base = ROOT/'assets/levels'/folder.name.lower().replace('-', '_')
    dav = next(folder.glob('*.[dD][aA][vV]')).read_bytes()
    rect = level_editor.dav_tables(dav)[1][166]  # Native04 heap foliage tile.
    x, width, y, height, page = rect
    assert list(rect)==[192, 64, 64, 64, 3]
    scenery = json.loads((base/'data/scenery.json').read_text())
    group = scenery[str(page)]
    selected = [i for i in range(0, len(group['verts']), 3)
                if all(x<=u*256<=x+width and y<=v*256<=y+height
                       for u, v in group['uvs'][i:i+3])]
    assert selected, 'No original leaf-heap geometry found'
    # Connected components preserve a complete native heap for the lab,
    # rather than inventing a bush mesh or changing the original scale.
    parents = {i:i for i in selected}
    def find(i):
        while parents[i]!=i:
            parents[i] = parents[parents[i]]
            i = parents[i]
        return i
    seen = {}
    for i in selected:
        for point in group['verts'][i:i+3]:
            key = tuple(round(v, 3) for v in point)
            if key in seen: parents[find(i)] = find(seen[key])
            else: seen[key] = i
    components = collections.defaultdict(list)
    for i in selected: components[find(i)].append(i)
    sample_ids = max(components.values(), key=len)
    points = [v for i in sample_ids for v in group['verts'][i:i+3]]
    origin = [round((min(v[a] for v in points)+max(v[a] for v in points))/2, 2)
              if a!=1 else min(v[a] for v in points) for a in range(3)]
    sample = {key:[v for i in sample_ids for v in group[key][i:i+3]] for key in group}
    sample['verts'] = [[round(v[a]-origin[a], 5) for a in range(3)] for v in sample['verts']]
    out = base/'foliage'; out.mkdir(exist_ok=True)
    (out/'sample_data.json').write_text(json.dumps({str(page):sample},separators=(',',':')))
    metadata = dict(page=page,rectangle_id=166,rectangle=list(rect),
                    triangles=[i//3 for i in selected],
                    source_origin=origin,sample_triangles=len(sample_ids),
                    components=[len(v) for v in components.values()],sample_leaf_zone=72,
                    shader='res://shaders/bush_backface_cutout.gdshader',
                    source='Original scenery WAR + DAV rectangle166; unchanged vertices, UV and colors')
    (base/'data/foliage.json').write_text(json.dumps(metadata,indent=2))
    print('Native04 heaps:',len(selected),'triangles; lab component:',len(sample_ids),'triangles; export origin',origin)

if __name__=='__main__': main(*sys.argv[1:3])
