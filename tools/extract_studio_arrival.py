"""Scene.WAR CIN0: native sheep return, Ralph poses, camera and SND cues.
Usage: python tools/extract_studio_arrival.py DECOMP_REPO ORIGINAL_SCENE_FOLDER
"""
import json
import struct
import sys
from pathlib import Path
from extract_shared_items import read_rig, page_image

ROOT = Path(__file__).resolve().parents[1]
STRIDES = [0, 8, 8, 4, 2, 2, 4, 2, 2]

def main():
    decomp, folder = map(Path, sys.argv[1:3])
    sys.path.insert(0, str(decomp / 'tools'))
    import level_editor as editor
    import war_meshes
    out = ROOT / 'assets/levels/scene/arrival'
    out.mkdir(parents=True, exist_ok=True)
    war = (folder / 'Scene.WAR').read_bytes()
    raw = (folder / 'Scene.DAV').read_bytes()
    dav = war_meshes.read_dav(folder / 'Scene.DAV')
    tables = editor.dav_tables(raw)
    table = struct.unpack_from('<%dI' % struct.unpack_from('<I', war, 12)[0], war, 16)
    cursor = next(value & 0xffffff for value in table if value >> 24 == 0x85)
    pairs = [struct.unpack_from('<2I', war, cursor+4+i*8)
             for i in range(struct.unpack_from('<I', war, cursor)[0])]
    header, cursor = next((h, p) for h, p in pairs if h & 65535 == 0)
    voice = struct.unpack_from('<I', war, cursor)[0]
    cursor += 4
    tracks, actors, definitions, required = [], {}, [], set()
    end = 0
    for _ in range((header >> 16) & 0x7fff):
        selector, count, resource, _ = struct.unpack_from('<BBHI', war, cursor)
        cursor += 8
        track = dict(selector=selector, index=resource, records=[])
        for _ in range(count):
            op, count, _ = struct.unpack_from('<HHI', war, cursor)
            cursor += 8
            keys = []
            for index in range(count):
                word = struct.unpack_from('<H', war, cursor+index*STRIDES[op])[0]
                value = list(struct.unpack_from('<%dh' % ((STRIDES[op]-2)//2), war, cursor+index*STRIDES[op]+2))
                time = (word & 0x3fff)*.016
                keys.append(dict(time=time, mode=word >> 14, value=value))
                end = max(end, time)
            track['records'].append(dict(opcode=op, keys=keys))
            cursor = (cursor+count*STRIDES[op]+3) & ~3
        tracks.append(track)
        if not selector:
            continue
        assert selector == 2
        model = struct.unpack_from('<H', war, table[resource] & 0xffffff)[0]
        at = struct.unpack_from('<I', war, (table[model] & 0xffffff)+16)[0]
        direct = struct.unpack_from('<I', war, at)[0]
        at += 4+direct*4
        count = struct.unpack_from('<I', war, at)[0]
        mapped = struct.unpack_from('<%dI' % count, war, at+4)
        used = {key['value'][0] & 0x7fff for record in track['records'] if record['opcode'] == 3 for key in record['keys']}
        ids = {str(i): war[mapped[i]:mapped[i]+8].split(b'\0')[0].decode().lower() for i in used}
        directory = out / ('model_%d' % model)
        directory.mkdir(exist_ok=True)
        rig = read_rig(war, table[model], editor, war_meshes, tables, {name: name for name in ids.values()})
        rig.update(rotation_order='ZXY', rotation_axis_sign=[1, 1, -1])
        (directory / 'worn_data.json').write_text(json.dumps(rig, separators=(',', ':')))
        materials = {}
        for page in rig['surfaces']:
            if int(page) < 0:
                continue
            (directory / 'textures').mkdir(exist_ok=True)
            record = dav['pages'][int(page)]
            page_image(raw, record).save(directory / 'textures' / ('page_%s.png' % page))
            materials[page] = record['kind']
        for clip in rig['animations'].values():
            required.update(cue['sound_id'] for cue in clip['sound_cues'])
        definition = dict(directory='res://'+directory.relative_to(ROOT).as_posix(), materials=materials)
        definitions.append(definition)
        actors['%d:%d' % (selector, resource)] = dict(**definition, name='ArrivalActor_%d' % resource,
                                                   resource=resource, model=model, animation_ids=ids)
    sounds = {}
    snd = (folder / 'Scene.SND').read_bytes()
    cursor = 12
    (out / 'audio').mkdir(exist_ok=True)
    for _ in range(struct.unpack_from('<I', snd, 8)[0]):
        identity, size, flags = struct.unpack_from('<III', snd, cursor)
        if identity in required:
            path = out / 'audio' / ('%d.wav' % identity)
            path.write_bytes(snd[cursor+12:cursor+12+size])
            sounds[str(identity)] = 'res://'+path.relative_to(ROOT).as_posix()
        cursor += 12+size
    assert required.issubset({int(key) for key in sounds}), required-set(map(int, sounds))
    sequence = dict(cine_id=0, duration=end, voice_id=voice, tracks=tracks, actors=actors,
                    sounds=sounds, trigger=dict(min=[0,0,0], max=[0,0,0]),
                    source='SceneSheepPanel::Update -> Scene.WAR CIN0')
    (out / 'sequence.json').write_text(json.dumps(sequence, separators=(',', ':')))
    (out / 'models.json').write_text(json.dumps(definitions, indent=2))
    catalog_path = ROOT / 'assets/cinematics/camera_catalog.json'
    catalog = json.loads(catalog_path.read_text(encoding='utf8'))
    catalog['sequences']['studio_sheep_arrival'] = dict(
        source='res://assets/levels/scene/arrival/sequence.json', level='scene', cine_id=0,
        kind='intro_cinematic', return_transition='none',
        description='Regreso de una oveja nueva al corral del plato (SceneSheepPanel CIN0)')
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
    print('Studio CIN0:', end, 'seconds;', [(key, value['animation_ids']) for key, value in actors.items()], 'sounds', sorted(required))

if __name__ == '__main__':
    main()
