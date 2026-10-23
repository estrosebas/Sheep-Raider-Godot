"""Wolf::MSG_WOLF_CAUGHT: PUNCH3 hit, PUNCH7 grab, DIEPNCH2 finish."""
import json
import struct
import sys
from pathlib import Path
from extract_run_assets import decode

ROOT = Path(__file__).resolve().parents[1]

def main():
    folder = Path(sys.argv[1])
    war = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    at = struct.unpack_from('<I',war,16)[0] & 0xffffff
    pointer = struct.unpack_from('<I',war,at+16)[0]
    count = struct.unpack_from('<I',war,pointer)[0]
    joints = struct.unpack_from('<H',war,at+24)[0]
    names = {war[p:p+8].split(b'\0')[0].lower():p for p in struct.unpack_from('<%dI'%count,war,pointer+4) if p}
    aliases = {'punch3':'sam_hit','punch7':'sam_caught','diepnch2':'sam_death'}
    clips = {alias:decode(war,names[name.encode()],joints) for name,alias in aliases.items()}
    required = {cue['sound_id'] for clip in clips.values() for cue in clip['sound_cues']}
    required.discard(0x158)  # SND_RUMBLE is a controller cue, deliberately silent on PC.
    sounds = {}
    for bank_folder in [folder.parent/'Lvl-00',folder]:
        bank = next(bank_folder.glob('*.[sS][nN][dD]')).read_bytes()
        cursor = 12
        for _ in range(struct.unpack_from('<I',bank,8)[0]):
            identity,size,flags = struct.unpack_from('<III',bank,cursor)
            if identity in required:
                path = ROOT/'assets/audio/sfx'/f'sam_attack_{identity}.wav'
                path.write_bytes(bank[cursor+12:cursor+12+size])
                sounds[str(identity)] = dict(path='res://'+path.relative_to(ROOT).as_posix(),loop=bool(flags&1))
            cursor += 12+size
    assert required == set(map(int,sounds)), required-set(map(int,sounds))
    result = dict(animations=clips,sounds=sounds,source='Sam::TryCatchWolf / Wolf::MSG_WOLF_CAUGHT',
                  grab_height_godot=[-.5,.3],hit_height_godot=[-1,1.5],grab_probability=.5,
                  hit_camera_switch_seconds=2.0,restart_extra_seconds=2.0)
    (ROOT/'assets/models/ralph_sam_attacks.json').write_text(json.dumps(result,separators=(',',':')),encoding='utf8')
    # WIN has sparse keys. Preserve the previous HIT pose, independently of
    # the existing WIN decoded from GRAB, so recovery does not twist his arms.
    for level, model in [(1,2),(2,4),(3,16),(4,7),(5,19)]:
        source = next((folder.parent/f'Lvl-{level:02}').glob('*.[wW][aA][rR]')).read_bytes()
        at = struct.unpack_from('<I',source,16+model*4)[0] & 0xffffff
        pointer = struct.unpack_from('<I',source,at+16)[0]
        count = struct.unpack_from('<I',source,pointer)[0]
        pointers = struct.unpack_from('<%dI'%count,source,pointer+4)
        names = {source[p:p+8].split(b'\0')[0].lower():p for p in pointers if p}
        path = ROOT/f'assets/levels/lvl_{level:02}/models/{model}/worn_data.json'
        data = json.loads(path.read_text(encoding='utf8'))
        data['animations']['win_after_hit'] = decode(source,names[b'win'],len(data['joints']),data['animations']['punch3']['frames'][-1]['joints'])
        path.write_text(json.dumps(data,separators=(',',':')),encoding='utf8')
    print({name:clip['duration'] for name,clip in clips.items()})

if __name__=='__main__': main()
