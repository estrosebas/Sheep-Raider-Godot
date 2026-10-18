"""Import common item assets once, independently of Godot level scenes.
python tools/extract_shared_items.py DECOMP_REPO PC_LEVELS_DIRECTORY
Reads the original WAR/DAV/SND; writes assets/items only.
"""
import json
from pathlib import Path
import re
import struct
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
WANTED = {3: ('lettuce', 'Lechuga'), 7: ('fan', 'Ventilador'), 10: ('rocket', 'Cohete'),
          39: ('perfume', 'Perfume'), 66: ('magnet', 'Imán'),
          80: ('sheep_costume', 'Disfraz de oveja'), 125: ('ghost_costume', 'Disfraz de fantasma')}

def read_rig(war, resource, editor, war_meshes, tables, animation_aliases=None):
    """Match each emitted triangle corner to its original joint, by vertex index."""
    from extract_run_assets import decode
    at = resource & 0xffffff
    vertex_at, entry_at, vertex_count, entry_count = struct.unpack_from('<IIHH', war, at)
    joint_at, joint_count = struct.unpack_from('<IH', war, at+20)
    joints, vertex_bones = [], []
    for index in range(joint_count):
        parent,x,y,z,count = struct.unpack_from('<H3hH', war, joint_at+index*10)
        joints.append({'parent': parent if index > 0 and parent < index else -1,
                       'offset': [x/800.0,-y/800.0,z/800.0]})
        vertex_bones.extend([index]*count)
    assert len(vertex_bones) == vertex_count
    geometry = editor.geometry(war, tables, at, True)
    # Reproduce only the emission order; positions/UVs/colors use the verified decoder.
    bones = {}
    cursor = entry_at
    for _ in range(entry_count):
        kind,count = struct.unpack_from('<HH', war, cursor)
        shape = editor.POLY.get(kind)
        stride = war_meshes.STRIDE[kind]
        if shape:
            corners,cols,tex = shape
            for n in range(count):
                el = cursor+4+n*stride
                indices = war[el:el+corners]
                page = -1
                if tex is not None:
                    texture, = struct.unpack_from('<I', war, el+(4 if tex=='square' else 12))
                    if texture < len(tables[0]) and tables[0][texture] < len(tables[1]):
                        page = tables[1][tables[0][texture]][4]
                triangles = [(0,1,2)] if corners == 3 else [(0,3,2),(0,1,3)]
                for triangle in triangles:
                    if any(indices[k] >= vertex_count for k in triangle):
                        continue
                    bones.setdefault(str(page), []).extend(vertex_bones[indices[k]] for k in triangle)
        cursor += 4+count*stride
    groups = {}
    for page, packed in geometry['groups'].items():
        group = {'verts': [], 'uvs': [], 'cols': [], 'bones': bones[page]}
        for i in range(0,len(packed),8):
            x,y,z,u,v,r,g,b = packed[i:i+8]
            group['verts'].append([x*.01,-y*.01,z*.01])
            group['uvs'].append([u,v])
            divisor = 128 if int(page)>=0 else 255
            group['cols'].append([r/divisor,g/divisor,b/divisor])
        assert len(group['verts']) == len(group['bones'])
        groups[page] = group
    animation_at, = struct.unpack_from('<I', war, at+16)
    count, = struct.unpack_from('<I', war, animation_at)
    pointers = struct.unpack_from('<%dI' % count, war, animation_at+4)
    aliases = {'stand1':'idle','walk1':'walk','walk':'walk','run':'walk','tiptoe':'sneak','talk1':'action',
               'hoo':'action','jump':'jump','fall1':'fall','fall':'fall'}
    if animation_aliases is not None:
        aliases = animation_aliases
    animations = {}
    for pointer in pointers:
        if not pointer:
            continue
        name = war[pointer:pointer+8].split(b'\0')[0].decode().lower()
        if name in aliases:
            animations[aliases[name]] = decode(war, pointer, joint_count)
    if animation_aliases is None:
        assert 'idle' in animations and 'walk' in animations
    return {'joints':joints,'surfaces':groups,'animations':animations}

def page_image(raw, page):
    pixels = []
    for value, in struct.iter_unpack('<H', raw[page['offset']+10:page['offset']+page['bytes']]):
        kind = page['format'] & 3
        if kind == 2:
            rgba = [((value >> 8) & 15)*17, ((value >> 4) & 15)*17, (value & 15)*17, (value >> 12)*17]
        elif kind == 1:
            rgba = [int(((value >> 10) & 31)*255/31), int(((value >> 5) & 31)*255/31),
                    int((value & 31)*255/31), 255 if value & 0x8000 else 0]
        else:
            rgba = [int((value >> 11)*255/31), int(((value >> 5) & 63)*255/63), int((value & 31)*255/31), 255]
        rgba[3] = 255 if page['kind'] == 'opaque' else 255-rgba[3]
        pixels.append(tuple(rgba))
    image = Image.new('RGBA', (page['w'], page['h']))
    image.putdata(pixels)
    return image

def main():
    decomp, levels = map(Path, sys.argv[1:3])
    sys.path.insert(0, str(decomp / 'tools'))
    import level_editor as editor
    import war_meshes
    output = ROOT / 'assets/items'
    output.mkdir(parents=True, exist_ok=True)
    # Supplemental item adapters (e.g. Lvl01 dynamite) have their own source
    # extractor; preserve those entries when rebuilding the original shared set.
    definitions = {k:v for k,v in json.loads((output/'definitions.json').read_text(encoding='utf8')).items() if int(k) not in WANTED} if (output/'definitions.json').exists() else {}
    sound_ids = {0x6b: 'fan_start', 0x6c: 'fan_loop', 0x92: 'magnet_hum',
                 0x154: 'ghost_boo', 49: 'sheep_bleat', 0x128: 'rocket_start', 0x6e: 'rocket_loop'}
    source_enums = (decomp / 'src/include/scenaric_props.h').read_text()
    ids = {name: int(number) for name, number in re.findall(r'CLASSID_(\w+) = (\d+)', source_enums)}
    registry = (decomp / 'src/engine/scn_register.cpp').read_text()
    catalog = []
    for call in registry.split('Scenaric_RegisterClass_2(')[1:]:
        call = call.split(');')[0]
        match = re.search(r'CLASSID_(\w+)', call)
        if match and 'SCN_CF_INVENTORY_ITEM' in call:
            name = match[1]
            catalog.append({'class_id': ids[name], 'original_name': name, 'implemented': ids[name] in WANTED or str(ids[name]) in definitions})
    for folder in sorted(levels.glob('Lvl-*')):
        files = {p.suffix.lower(): p for p in folder.iterdir()}
        if '.war' not in files:
            continue
        war = files['.war'].read_bytes()
        table = struct.unpack_from('<%dI' % struct.unpack_from('<I', war, 12)[0], war, 16)
        for res, entry in enumerate(table):
            if (entry >> 24) & 0xbf != 5:
                continue
            at = entry & 0xffffff
            kind, = struct.unpack_from('<H', war, at+10)
            if kind not in WANTED or str(kind) in definitions:
                continue
            model, = struct.unpack_from('<H', war, at)
            if model >= len(table) or not table[model]:
                continue
            dav_raw = files['.dav'].read_bytes()
            dav = war_meshes.read_dav(files['.dav'])
            resource = table[model]
            geom = editor.geometry(war, editor.dav_tables(dav_raw), resource & 0xffffff, resource >> 24 == 0x44)
            slug, label = WANTED[kind]
            item_dir = output / slug
            textures = item_dir / 'textures'
            textures.mkdir(parents=True, exist_ok=True)
            groups, materials = {}, {}
            for page_key, packed in geom['groups'].items():
                page_id = int(page_key)
                group = {'page': page_id, 'verts': [], 'uvs': [], 'cols': []}
                for i in range(0, len(packed), 8):
                    x,y,z,u,v,r,g,b = packed[i:i+8]
                    group['verts'].append([x*.01, -y*.01, z*.01])
                    group['uvs'].append([u,v])
                    divisor = 128 if page_id >= 0 else 255
                    group['cols'].append([r/divisor,g/divisor,b/divisor])
                groups[page_key] = group
                if page_id >= 0:
                    page = dav['pages'][page_id]
                    page_image(dav_raw, page).save(textures / f'page_{page_id}.png')
                    materials[page_key] = page['kind']
            (item_dir / 'mesh_data.json').write_text(json.dumps(groups, separators=(',', ':')))
            if kind in (80,125):
                # Verified animated player models (separate from the folded pickup).
                body_resource = 18 if kind == 80 else 13
                rig = read_rig(war, table[body_resource], editor, war_meshes, editor.dav_tables(dav_raw))
                for page_key in rig['surfaces']:
                    if int(page_key) >= 0:
                        page = dav['pages'][int(page_key)]
                        page_image(dav_raw,page).save(textures / f'page_{page_key}.png')
                        materials[page_key] = page['kind']
                (item_dir / 'worn_data.json').write_text(json.dumps(rig, separators=(',', ':')))
            props = list(struct.unpack_from('<4i', war, at+20)) if kind == 10 else []
            definitions[str(kind)] = {'class_id': kind, 'slug': slug, 'label': label,
                'mesh': f'res://assets/items/{slug}/model.tres', 'materials': materials,
                'source_level': folder.name, 'source_resource': res, 'source_model': model,
                'props': props, 'bounds': {'lo': geom['lo'], 'hi': geom['hi']}}
            print(label, folder.name, 'resource', res, 'model', model)
        if '.snd' in files and sound_ids:
            snd = files['.snd'].read_bytes()
            at = 12
            for _ in range(struct.unpack_from('<I', snd, 8)[0]):
                sound_id, size, flags = struct.unpack_from('<III', snd, at)
                if sound_id in sound_ids:
                    sounds = output / 'audio'
                    sounds.mkdir(exist_ok=True)
                    (sounds / (sound_ids.pop(sound_id) + '.wav')).write_bytes(snd[at+12:at+12+size])
                at += 12+size
    assert set(WANTED).issubset(set(map(int,definitions))), 'Missing requested items'
    (output / 'definitions.json').write_text(json.dumps(definitions, indent=2, ensure_ascii=False), encoding='utf-8')
    (output / 'original_catalog.json').write_text(json.dumps(sorted(catalog, key=lambda c:c['class_id']), indent=2))
    print('Common models:', len(definitions), 'Original inventory classes:', len(catalog))

if __name__ == '__main__':
    main()
