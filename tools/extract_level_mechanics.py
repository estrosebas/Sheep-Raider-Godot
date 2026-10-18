"""Extract original model collision boxes and run dust sprite group from Lvl-00."""
import json
from pathlib import Path
import re
import struct
import sys
from PIL import Image
from extract_inventory_ui import read_lists
from extract_shared_items import page_image

ROOT = Path(__file__).resolve().parent.parent

def main():
    decomp, folder = map(Path, sys.argv[1:3])
    verify = '--verify' in sys.argv
    sys.path.insert(0,str(decomp/'tools'))
    import war_meshes
    files = {p.suffix.lower():p for p in folder.iterdir()}
    raw = files['.war'].read_bytes()
    table = struct.unpack_from('<%dI'%struct.unpack_from('<I',raw,12)[0],raw,16)
    entities = json.loads((ROOT/'assets/levels/lvl_00/data/entities.json').read_text())
    wanted = {'Cactus','Rock','FallingRock','MiscStatic','SignPost','Anvil','Mailbox','FallingGate','SensibleButton','seesaw'}
    collisions = []
    for entity in entities:
        if entity['class_name'] not in wanted:
            continue
        resource = table[entity['model_res']]
        at = resource&0xffffff
        pointer, = struct.unpack_from('<I',raw,at+12)
        if not pointer:
            continue
        count, = struct.unpack_from('<I',raw,pointer)
        boxes = []
        for i in range(count):
            flags,*corners = struct.unpack_from('<I6h',raw,pointer+4+i*16)
            if flags&1: # original COLLBOX_NON_SOLID: do not turn triggers into walls
                continue
            boxes.append({'flags':flags,'min':corners[:3],'max':corners[3:]})
        if boxes:
            collisions.append({'res':entity['res'],'class_name':entity['class_name'],
                'model_res':entity['model_res'],'position':entity['pos'],'boxes':boxes})
    collision_path = ROOT/'assets/levels/lvl_00/data/solid_boxes.json'
    if verify:
        assert json.loads(collision_path.read_text()) == collisions, 'Collision source mismatch'
    else:
        collision_path.write_text(json.dumps(collisions,indent=2))
    davraw = files['.dav'].read_bytes()
    dav = war_meshes.read_dav(files['.dav'])
    enums = (decomp/'src/include/scenaric_props.h').read_text()
    resource = int(re.search(r'DAV_IDI_IGLSMOK_ = (\d+)',enums)[1])
    aliases, groups = read_lists(davraw)
    first = aliases[resource][0]
    frames = next(group for group in groups if first in group)[:10]
    output = ROOT/'assets/effects/run_dust'
    output.mkdir(parents=True,exist_ok=True)
    records = []
    for i,bitmap in enumerate(frames):
        x,w,y,h,page = dav['rects'][bitmap]
        image = page_image(davraw,dav['pages'][page]).crop((x,y,x+w,y+h))
        path = output/f'frame_{i}.png'
        if verify:
            assert Image.open(path).convert('RGBA').tobytes() == image.tobytes(), path
        else:
            image.save(path)
        records.append({'bitmap':bitmap,'page':page,'rect':[x,y,w,h], 'path':f'res://assets/effects/run_dust/frame_{i}.png'})
    manifest = {'resource':resource,'source':str(files['.dav']),
        'frames':records,'life_ticks':2608,'interval_ticks':163,'h_speed':100,'v_speed':-20,'size_start':40,'size_end':120}
    if verify:
        assert json.loads((output/'source.json').read_text()) == manifest
    else:
        (output/'source.json').write_text(json.dumps(manifest,indent=2))
    print('Solids:',len(collisions),'entities /',sum(len(c['boxes']) for c in collisions),'boxes; original dust:',len(frames),'frames')
    if verify:
        print('Verified against original WAR/DAV: exact box records and RGBA sprites')

if __name__ == '__main__':
    main()
