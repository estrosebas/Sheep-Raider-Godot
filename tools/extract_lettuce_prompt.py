"""Extract original lettuce HUD art from Level01 DAV, with source coordinates."""
import json, re, sys
from pathlib import Path
from extract_shared_items import page_image
from extract_inventory_ui import read_lists
ROOT = Path(__file__).resolve().parent.parent

def extract(decomp, folder):
    sys.path.insert(0, str(decomp / 'tools'))
    import war_meshes
    raw = (folder / 'Lvl-01.DAV').read_bytes()
    dav = war_meshes.read_dav(folder / 'Lvl-01.DAV')
    groups, bitmap_groups = read_lists(raw)
    header = (decomp / 'src/include/scenaric_props.h').read_text()
    out = ROOT / 'assets/ui/lettuce_prompt'
    out.mkdir(exist_ok=True)
    metadata = {'source': 'Levels/Lvl-01/Lvl-01.DAV', 'range_units': 600, 'y_range_units': 150, 'assets': {}}
    def resource(name):
        return int(re.search(r'\b' + name + r'\s*=\s*(\d+)', header)[1])
    def save(bitmap, filename):
        x, w, y, h, page = dav['rects'][bitmap]
        page_image(raw, dav['pages'][page]).crop((x, y, x+w, y+h)).save(out / filename)
        return {'bitmap': bitmap, 'page': page, 'rect': [x, y, w, h]}
    identity = resource('DAV_IDI_IGLCRAI1')
    first = groups[identity][0]
    frames = next((g for g in bitmap_groups if first in g), [first])[:10]
    metadata.update(resource=identity, frames=len(frames))
    metadata['assets']['DAV_IDI_IGLCRAI1'] = [save(b, f'frame_{i}.png') for i, b in enumerate(frames)]
    for name, filename in [('DAV_IDI_IMOICONB', 'sheep.png'), ('DAV_IDI_ILAICONB', 'lettuce.png')]:
        identity = resource(name)
        # RegisterClass_2 stores the resource named ICONB in registry.iconA.
        metadata['assets'][name] = {'resource': identity, **save(groups[identity][0], filename)}
    (out / 'source.json').write_text(json.dumps(metadata, indent=2))
    print(json.dumps(metadata))
if __name__ == '__main__':
    extract(Path(sys.argv[1]), Path(sys.argv[2]) / 'Levels/Lvl-01')
