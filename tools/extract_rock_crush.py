"""Rock::CrushObjectsBelow / Wolf::WOLF_ST_DIE_CRUSHED: native SQUASH3."""
import json
import struct
import sys
from pathlib import Path
from extract_run_assets import decode

ROOT = Path(__file__).resolve().parents[1]

def main():
    folder = Path(sys.argv[1])
    war = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    model = struct.unpack_from('<I', war, 16)[0] & 0xffffff
    table = struct.unpack_from('<I', war, model+16)[0]
    joints = struct.unpack_from('<H', war, model+24)[0]
    count = struct.unpack_from('<I', war, table)[0]
    pointers = struct.unpack_from('<%dI' % count, war, table+4)
    names = {war[p:p+8].split(b'\0')[0].decode().lower():p for p in pointers if p}
    clip = decode(war, names['squash3'], joints)
    sounds = {}
    required = {cue['sound_id'] for cue in clip['sound_cues']}
    bank = next(folder.glob('*.[sS][nN][dD]')).read_bytes()
    offset = 12
    for _ in range(struct.unpack_from('<I', bank, 8)[0]):
        identity, size, flags = struct.unpack_from('<III', bank, offset)
        if identity in required:
            path = ROOT/'assets/audio/sfx'/f'rock_crush_{identity}.wav'
            path.write_bytes(bank[offset+12:offset+12+size])
            sounds[str(identity)] = {'path':'res://'+path.relative_to(ROOT).as_posix(),'loop':bool(flags&1)}
        offset += 12+size
    assert required == {int(identity) for identity in sounds}
    data = {'animations':{'crush_death':clip},'sounds':sounds,
            'source':'Rock::CrushObjectsBelow / Wolf::KILL_CRUSH / WOLF_ST_DIE_CRUSHED',
            'restart_extra_seconds':2.0,'inset_xz_m':.3,'under_bottom_m':.5,'above_bottom_m':.5}
    (ROOT/'assets/models/ralph_crush_data.json').write_text(json.dumps(data,separators=(',',':')))
    print('Native SQUASH3:',joints,'joints,',clip['duration'],'seconds, cues:',clip['sound_cues'])

if __name__=='__main__': main()
