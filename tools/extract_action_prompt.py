"""Extract DAV_IDI_IGLCRAI2 used by Wolf::DrawActionPrompt."""
import json, sys
from pathlib import Path
from extract_inventory_ui import read_lists
from extract_shared_items import page_image

ROOT = Path(__file__).resolve().parent.parent
def main():
    decomp, folder = map(Path, sys.argv[1:3])
    sys.path.insert(0, str(decomp/'tools'))
    import war_meshes
    path = folder/'Lvl-00.DAV'
    raw = path.read_bytes()
    dav = war_meshes.read_dav(path)
    groups, _ = read_lists(raw)
    bitmap = groups[55][0]
    x, w, y, h, page = dav['rects'][bitmap]
    out = ROOT/'assets/ui/action_prompt'
    out.mkdir(parents=True, exist_ok=True)
    page_image(raw, dav['pages'][page]).crop((x,y,x+w,y+h)).save(out/'background.png')
    (out/'source.json').write_text(json.dumps({'resource':55,'bitmap':bitmap,'page':page,'rect':[x,y,w,h],
        'source':str(path),'duration':.5,'origin':[16,16],'text_origin':[32,24]},indent=2))
    print('Original action prompt panel', w, h)
if __name__ == '__main__': main()
