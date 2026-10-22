"""Native Lv05 supplements after the shared WAR importer (no invented tutorials).

python tools/extract_level05_supplement.py DECOMP PC_LVL_05
"""
import json
import re
import struct
import sys
from pathlib import Path
from extract_shared_items import read_rig, page_image

ROOT = Path(__file__).resolve().parents[1]


def main():
    decomp, folder = map(Path, sys.argv[1:3])
    if folder.name.lower() != 'lvl-05':
        raise ValueError('This audit applies to Lv05.')
    base = ROOT / 'assets/levels/lvl_05'
    def read(name):
        return json.loads((base / name).read_text(encoding='utf8'))
    def save(name, value):
        path = base / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
    war = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    table = struct.unpack_from('<%dI' % struct.unpack_from('<I', war, 12)[0], war, 16)
    at = next(value & 0xffffff for value in table if value >> 24 == 0x82)
    count = struct.unpack_from('<I', war, at)[0]
    at += 4
    exports = {}
    for _ in range(count):
        identity, length = struct.unpack_from('<HH', war, at)
        exports[identity] = struct.unpack_from('<%dI' % length, war, at+4)
        at += 4+length*4
    def trajectory(identity):
        at = exports[identity][0]
        count = struct.unpack_from('<H', war, at)[0]
        return [list(struct.unpack_from('<3h', war, at+2+i*6)) for i in range(count)]
    def boxes(identity):
        return [dict(flags=v[0], min=list(v[1:4]), max=list(v[4:]))
                for at in exports.get(identity, []) for v in [struct.unpack_from('<I6h', war, at)]]
    entities = read('data/entities.json')
    manifest = read('data/manifest.json')
    solids = read('data/solid_boxes.json')
    platforms = []
    catapults = []
    for entity in entities:
        kind, props = entity['class_id'], entity['props']
        common = {**entity, 'directory': manifest['models'].get(str(entity['model_res']), {}).get('directory'),
                  'boxes': next((row['boxes'] for row in solids if row['res']==entity['res']), [])}
        if kind == 118:
            platforms.append({**common, 'trajectory': trajectory(props['0x4']),
                              'speed_ratio': props['0x0']/100, 'switch_speed': 4.0,
                              'source': 'rcarpetmobile.cpp::PostLoadInit/HandleMessage/Move'})
        if kind == 56:
            catapults.append({**common, 'activation': boxes(props['0x0']),
                              'trajectory': trajectory(props['0x24']),
                              'max_throw_offset': props['0x14']*.01,
                              'arm_lengths': [props[key]*.01 for key in ['0x4','0x8','0xc']],
                              'source': 'catapult.cpp::PostLoadInit/Launch/Control',
                              'status': 'Imported model, animations, collision and native configuration; operating controller pending'})
    save('data/mobile_platforms.json', {'platforms': platforms})
    save('data/catapults.json', {'catapults': catapults})
    # FallingGate::PostLoadInit swaps its placeholder for one of five models.
    # Export those references too: they are not necessarily attached to an entity.
    sys.path.insert(0, str(decomp/'tools'))
    import level_editor as editor, war_meshes
    dp = next(folder.glob('*.[dD][aA][vV]'))
    raw = dp.read_bytes()
    dav = war_meshes.read_dav(dp)
    dt = editor.dav_tables(raw)
    symbols = dict((name, int(value)) for name, value in re.findall(
        r'(WAR_IDO_AGRILL\d+)\s*=\s*(\d+)', (decomp/'src/include/scenaric_props.h').read_text()))
    definitions = read('data/cinematic_models.json')
    switches = read('data/switches.json')
    for gate in switches['gates']:
        index = gate['props']['0x10']
        if index >= 10:
            index -= 10
        index = 0 if index < 1 else (4 if index > 5 else index-1)
        identity = symbols['WAR_IDO_AGRILL%02d' % (index+1)]
        model = next(value for value in table if value & 0xffffff == exports[identity][0])
        directory = base / 'gate_models' / str(index)
        relative = 'res://'+directory.relative_to(ROOT).as_posix()
        gate['directory'] = relative
        if any(row['directory']==relative for row in definitions):
            continue
        at = model & 0xffffff
        q = struct.unpack_from('<I', war, at+16)[0]
        count = struct.unpack_from('<I', war, q)[0]
        pointers = struct.unpack_from('<%dI' % count, war, q+4)
        names = [war[p:p+8].split(b'\0')[0].decode().lower() for p in pointers if p]
        rig = read_rig(war, model, editor, war_meshes, dt, {name:name for name in names})
        rig.update(rotation_order='ZXY', rotation_axis_sign=[1,1,-1])
        save(directory.relative_to(base)/'worn_data.json', rig)
        q = struct.unpack_from('<I', war, at+12)[0]
        gate['boxes'] = [dict(flags=v[0],min=list(v[1:4]),max=list(v[4:]))
                         for i in range(struct.unpack_from('<I',war,q)[0])
                         for v in [struct.unpack_from('<I6h',war,q+4+i*16)] if not v[0]&1]
        mats = {}
        for page in rig['surfaces']:
            if int(page)<0:
                continue
            path = directory/'textures'/f'page_{page}.png'
            path.parent.mkdir(parents=True, exist_ok=True)
            page_image(raw, dav['pages'][int(page)]).save(path)
            mats[page] = dav['pages'][int(page)]['kind']
        definitions.append({'directory': relative, 'materials': mats})
    # Reused variants need their own collider records, too.
    for gate in switches['gates']:
        exemplar = next(row for row in switches['gates'] if row['directory']==gate['directory'])
        gate['boxes'] = exemplar['boxes']
    save('data/switches.json', switches)
    save('data/cinematic_models.json', definitions)
    audit = read('data/import_audit.json')
    audit.update(intro_cine_id=0, tutorial_cine_ids=[],
                 cinematic_descriptors={'0': {'name': 'intro_camera', 'description': 'Recorrido nativo de entrada del nivel 05'}},
                 implemented_exclusive_classes=[118], pending_exclusive_classes=[56,65,159,162],
                 notes=['No Daffy entity or voiced tutorial exists in the Lv05 WAR.',
                        'Gate closedAtStart is 1 unless a Train exists; property0 alone does not select it.',
                        'Catapult and carryable SmallRock need operating controllers; ambient Firefly/Fish need motion.'])
    save('data/import_audit.json', audit)
    print('Lv05: native intro0, alternate gate models, mobile platform and catapult configuration')


if __name__ == '__main__':
    main()
