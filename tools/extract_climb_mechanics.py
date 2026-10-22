"""Wolf CLIMBBOXES and CLIMB1..5, shared across imported levels.
Usage: python tools/extract_climb_mechanics.py ORIGINAL_LEVEL_FOLDER
Only writes climb-specific outputs; does not reimport the map or its balance.
"""
import json
import struct
import sys
from pathlib import Path
from extract_run_assets import decode

ROOT = Path(__file__).resolve().parents[1]


def extract(folder):
    folder = Path(folder)
    war = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    table = struct.unpack_from('<%dI' % struct.unpack_from('<I', war, 12)[0], war, 16)
    at = next(e & 0xffffff for e in table if e >> 24 == 0x82)
    count = struct.unpack_from('<I', war, at)[0]
    at += 4
    exports = {}
    for _ in range(count):
        identity, length = struct.unpack_from('<HH', war, at)
        exports[identity] = struct.unpack_from('<%dI' % length, war, at + 4)
        at += 4 + length * 4
    slug = folder.name.lower().replace('-', '_')
    base = ROOT / 'assets/levels' / slug
    entities = json.loads((base / 'data/entities.json').read_text(encoding='utf8'))
    wolf = next(e for e in entities if e['class_id'] == 0)
    identity = wolf['props']['0x0']
    zones = []
    headings = [0, 2, 6, 0, 0, 1, 7, 0, 4, 3, 5, 0, 0, 0, 0, 0]
    for index, at in enumerate(exports.get(identity, [])):
        values = struct.unpack_from('<I6h', war, at)
        flags = values[0]
        zones.append({'index': index, 'flags': flags, 'min': list(values[1:4]),
                      'max': list(values[4:]), 'heading': headings[(flags >> 27) & 15] * 512,
                      'clamp_top': bool(flags & 0x2000000), 'walkable': bool(flags & 0x4000000)})
    rules = {'source': 'Wolf::PostLoadInit / ClimbStep / CLIMB_ZONE / ClampDeltaToBox',
             'source_level': folder.name, 'resource': identity, 'zones': zones,
             'speed': 1.0, 'acceleration': 10.0, 'deceleration': 10.0,
             'wall_push_seconds': 1.0, 'idle_sound_id': 40}
    (base / 'data/climb.json').write_text(json.dumps(rules, indent=2), encoding='utf8')
    model = table[wolf['model_res']] & 0xffffff
    at = struct.unpack_from('<I', war, model + 16)[0]
    count = struct.unpack_from('<I', war, at)[0]
    names = {war[p:p+8].split(b'\0')[0].decode().lower(): p
             for p in struct.unpack_from('<%dI' % count, war, at + 4) if p}
    joints = struct.unpack_from('<H', war, model + 24)[0]
    clips = {alias: decode(war, names[name], joints) for name, alias in [
        ('climb1', 'climb_up'), ('climb2', 'climb_down'), ('climb3', 'climb_left'),
        ('climb4', 'climb_right'), ('climb5', 'climb_idle')]}
    (ROOT / 'assets/models/ralph_climb_data.json').write_text(json.dumps(clips, separators=(',', ':')), encoding='utf8')
    sound_ids = {40} | {int(cue['sound_id']) for clip in clips.values() for cue in clip['sound_cues']}
    snd = next(folder.glob('*.[sS][nN][dD]')).read_bytes()
    at = 12
    sounds = {}
    for _ in range(struct.unpack_from('<I', snd, 8)[0]):
        identity, size, flags = struct.unpack_from('<III', snd, at)
        if identity in sound_ids:
            path = ROOT / 'assets/audio/sfx' / ('climb_%d.wav' % identity)
            path.write_bytes(snd[at+12:at+12+size])
            sounds[str(identity)] = {'path': 'res://' + path.relative_to(ROOT).as_posix(), 'loop': identity == 40}
        at += 12 + size
    assert sound_ids <= {int(i) for i in sounds}, ('Missing climb sounds', sound_ids - {int(i) for i in sounds})
    (ROOT / 'assets/models/ralph_climb_audio.json').write_text(json.dumps(sounds, indent=2), encoding='utf8')
    print('Climb zones:', json.dumps(zones))
    print('Clips:', [(k, v['original_name'], v['duration']) for k, v in clips.items()], 'sounds:', sorted(sound_ids))


if __name__ == '__main__':
    extract(sys.argv[1])
