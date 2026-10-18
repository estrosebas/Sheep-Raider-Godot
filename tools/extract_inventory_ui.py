"""Extract original DAV inventory sprites using interface.cpp/id_list.cpp.
Usage: python tools/extract_inventory_ui.py DECOMP_REPO PC_LEVELS
"""
import json
from pathlib import Path
import re
import struct
import sys
from extract_shared_items import page_image

ROOT = Path(__file__).resolve().parent.parent

def verify_extracted(decomp):
    sys.path.insert(0, str(decomp / 'tools'))
    import war_meshes
    from PIL import Image
    metadata = json.loads((ROOT / 'assets/ui/inventory/original_ui.json').read_text())
    resources = [(metadata['cloud']['source'], frame) for frame in metadata['cloud']['frames']]
    resources += [(icon['source'], icon) for icon in metadata['icons'].values()]
    cache = {}
    for source, record in resources:
        if source not in cache:
            path = Path(source)
            cache[source] = (path.read_bytes(), war_meshes.read_dav(path))
        raw, dav = cache[source]
        x,w,y,h,page = dav['rects'][record['bitmap']]
        assert record['rect'] == [x,y,w,h] and record['page'] == page
        expected = page_image(raw, dav['pages'][page]).crop((x,y,x+w,y+h))
        exported = Image.open(ROOT / record['path'][6:]).convert('RGBA')
        assert expected.size == exported.size and expected.tobytes() == exported.tobytes(), record['path']
    print('Verified', len(resources), 'original DAV crops: byte-exact RGBA')

def read_lists(raw):
    directory, = struct.unpack_from('<I', raw, 0x14)
    rec_at, = struct.unpack_from('<I', raw, directory + 0x0a)
    rec_count, = struct.unpack_from('<H', raw, directory + 2)
    at, = struct.unpack_from('<I', raw, directory + 0x12)
    count, = struct.unpack_from('<I', raw, at)
    at += 4
    groups = {}
    bitmap_groups = []
    for _ in range(count):
        identity, n = struct.unpack_from('<HH', raw, at)
        pointers = struct.unpack_from(f'<{n}I', raw, at + 4)
        if pointers and all(rec_at <= p < rec_at + rec_count*10 and (p-rec_at)%10 == 0 for p in pointers):
            bitmap_groups.append([(p-rec_at)//10 for p in pointers])
        else:
            groups[identity] = [struct.unpack_from('<H', raw, p)[0] for p in pointers]
        at += 4 + n * 4
    return groups, bitmap_groups

def main():
    decomp, levels = map(Path, sys.argv[1:3])
    if '--verify' in sys.argv:
        verify_extracted(decomp)
        return
    sys.path.insert(0, str(decomp / 'tools'))
    import war_meshes
    enums = (decomp / 'src/include/scenaric_props.h').read_text()
    ids = {name: int(value) for name, value in re.findall(r'(DAV_IDI_\w+) = (\d+)', enums)}
    registry = (decomp / 'src/engine/scn_register.cpp').read_text()
    classes = {name: int(value) for name, value in re.findall(r'CLASSID_(\w+) = (\d+)', enums)}
    icon_resources = {}
    for call in registry.split('Scenaric_RegisterClass_2(')[1:]:
        args = call.split(');')[0].split(',')
        if len(args) == 5 and args[0].strip().startswith('CLASSID_') and 'INVENTORY_ITEM' in args[2]:
            icon_resources[classes[args[0].strip()[8:]]] = args[3].strip()
    output = ROOT / 'assets/ui/inventory'
    output.mkdir(parents=True, exist_ok=True)
    metadata = {'cloud': None, 'icons': {}}
    for folder in sorted(levels.glob('Lvl-*')):
        files = list(folder.glob('*.[dD][aA][vV]'))
        if not files:
            continue
        raw = files[0].read_bytes()
        dav = war_meshes.read_dav(files[0])
        groups, bitmap_groups = read_lists(raw)
        pages = {}
        def extract(bitmap, filename):
            x,w,y,h,page = dav['rects'][bitmap]
            if page not in pages:
                pages[page] = page_image(raw, dav['pages'][page])
            pages[page].crop((x,y,x+w,y+h)).save(output / filename)
            return {'bitmap': bitmap, 'rect': [x,y,w,h], 'page': page, 'path': 'res://assets/ui/inventory/' + filename}
        resource = ids['DAV_IDI_IGLCRAI1']
        if metadata['cloud'] is None and groups.get(resource):
            first = groups[resource][0]
            # Res_FindBitmapGroup scans groups in directory order, including aliases.
            frames = next(values for values in bitmap_groups if first in values)[:10]
            metadata['cloud'] = {'resource': resource, 'source': str(files[0]),
                'frames': [extract(bitmap, f'cloud_{i}.png') for i,bitmap in enumerate(frames)]}
            _,width,_,height,_ = dav['rects'][first]
            metadata['cloud']['size'] = [width-1, height-1]
            print('Cloud', folder.name, 'bitmaps', frames, 'size', width, height)
        for kind, name in icon_resources.items():
            if str(kind) in metadata['icons'] or not groups.get(ids[name]):
                continue
            bitmap = groups[ids[name]][0]
            icon = extract(bitmap, f'icon_{kind}.png')
            icon.update({'resource': ids[name], 'resource_name': name, 'source': str(files[0])})
            metadata['icons'][str(kind)] = icon
    assert metadata['cloud'] and metadata['cloud']['frames']
    assert all(str(kind) in metadata['icons'] for kind in [3,7,10,39,66,80,125])
    (output / 'original_ui.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    print('Original icons:', len(metadata['icons']))

if __name__ == '__main__':
    main()
