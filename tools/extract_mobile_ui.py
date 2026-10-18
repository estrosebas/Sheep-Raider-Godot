"""Extract native UI candidates for touch controls; no repainted artwork.
Usage: python tools/extract_mobile_ui.py DECOMP_REPO PC_LEVELS
"""
import json
import sys
from pathlib import Path
from extract_inventory_ui import read_lists
from extract_shared_items import page_image

def main():
    decomp, levels = map(Path, sys.argv[1:3])
    sys.path.insert(0, str(decomp / 'tools'))
    import war_meshes
    source = levels / 'Lvl-00/Lvl-00.DAV'
    raw = source.read_bytes()
    dav = war_meshes.read_dav(source)
    groups, _ = read_lists(raw)
    output = Path(__file__).resolve().parent.parent / 'assets/ui/mobile'
    output.mkdir(parents=True, exist_ok=True)
    records = {}
    for name, identity, symbol in [
        ('hand', 37, 'DAV_IDI_IGLUSEDA'),
        ('use_highlight', 38, 'DAV_IDI_IGLUSEDB'),
        ('arrow', 28, 'DAV_IDI_IGLFLEC_'),
        ('exit', 27, 'DAV_IDI_IGLEXITB'),
    ]:
        bitmap = groups[identity][0]
        x, w, y, h, page = dav['rects'][bitmap]
        image = page_image(raw, dav['pages'][page]).crop((x, y, x+w, y+h))
        image.save(output / (name+'.png'))
        records[name] = dict(resource=identity, symbol=symbol, bitmap=bitmap,
                             page=page, rect=[x,y,w,h], path='res://assets/ui/mobile/'+name+'.png')
    manifest = dict(source=str(source), native_usage='src/engine/map.cpp: Map_InitObject icon pairs',
                    icons=records, reused=dict(inventory='res://assets/ui/inventory/cloud_0.png',
                    equipped_item='InventoryComponent.state.get_selected_object().icon'),
                    missing_dedicated_art=['jump','run','sneak','pause','language'])
    (output/'source.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('Extracted four original DAV crops; inventory cloud and item icons reused.')

if __name__ == '__main__':
    main()
