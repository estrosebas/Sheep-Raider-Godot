"""Extract STRIKE1/STAND7 and run sound cues from the original PC WAR/SND.
Format: sdw-decomp src/objects/animation.cpp (Anim_DecodeKey).
Usage: python tools/extract_run_assets.py PATH_TO_LVL_00
"""
import copy
import json
import math
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parent.parent
WANTED = {'strike1': 'run_crash', 'stand7': 'run_recover', 'slide1': 'run_stop',
          'runf1': 'run_start', 'runf2': 'run', 'rocket3': 'rocket_ride',
          'strike2': 'pit_fall', 'dead1': 'fall_death', 'letter1a':'mailbox_hit', 'letter1b':'mailbox_end', 'take1a':'pickup_start', 'take1b':'pickup_end', 'take4':'item_take_out', 'put4':'item_stow', 'rocket0':'rocket_mount', 'rocket2':'rocket_ignite', 'take2a':'sheep_lift', 'take2b':'sheep_lift_end', 'stand2':'sheep_carry_idle', 'run2':'sheep_carry_walk', 'put2a':'sheep_drop', 'put2b':'sheep_drop_end'}

AUX_WANTED = {'fall1':'fall','stand0':'idle','stand1':'idle_stand1','stand2':'idle_stand2','stand3':'idle_stand3','stand5':'idle_stand5',
              'stand10':'held_item_idle','standno':'placement_refused','clock2':'timekeeper_use','put1a':'throw_place','put1b':'throw_end','explos1':'blast_death','punch7':'sam_caught','diepnch2':'sam_death',
              'stand8':'sheep_carry_idle','stand12':'sheep_carry_tired','sneak2':'sheep_carry_sneak',
              'jump0b':'sheep_carry_jump_start','jump4':'sheep_carry_jump','jump5':'sheep_carry_apex',
              'fall2':'sheep_carry_fall','recept4':'sheep_carry_land_idle','recept3':'sheep_carry_land_move'}

def decode(war, pointer, joints, initial_poses=None):
    name = war[pointer:pointer+8].split(b'\0')[0].decode().lower()
    count, = struct.unpack_from('<H', war, pointer+8)
    offset = pointer + 10
    poses = copy.deepcopy(initial_poses) if initial_poses is not None else [{'rot': [0.0]*3, 'pos': [0.0]*3, 'scale': [1.0]*3} for _ in range(joints)]
    frames, cues, elapsed = [], [], 0.0
    for _ in range(count):
        duration, entries, words, sound = struct.unpack_from('<4H', war, offset)
        cursor = offset + 8
        if sound:
            cues.append({'time': elapsed, 'sound_id': sound})
        for _ in range(entries):
            control, = struct.unpack_from('<H', war, cursor)
            cursor += 2
            joint = control & 63
            assert joint < joints
            pose = {'rot': [0.0]*3, 'pos': [0.0]*3, 'scale': [1.0]*3}
            packed = bool(control & 0x8000)
            for bit, channel in [(0x40, 'rot'), (0x200, 'pos'), (0x1000, 'scale')]:
                for axis in range(3):
                    if control & (bit << axis):
                        code = ('B' if packed else 'H') if channel == 'scale' else ('b' if packed else 'h')
                        value, = struct.unpack_from('<' + code, war, cursor)
                        cursor += 1 if packed else 2
                        if channel == 'rot':
                            value *= math.tau / (128 if packed else 4096)
                            if axis != 0:
                                value = -value
                        elif channel == 'pos':
                            value /= 800.0
                            if axis == 1:
                                value = -value
                        else:
                            value /= 128 if packed else 1024
                        pose[channel][axis] = value
            if packed and cursor % 2:
                cursor += 1
            poses[joint] = pose
        assert cursor == offset + 8 + words * 2
        elapsed += duration / 1000.0
        frames.append({'time': elapsed, 'joints': copy.deepcopy(poses)})
        offset = cursor
    return {'original_name': name, 'duration': elapsed, 'frames': frames, 'sound_cues': cues}

def main():
    folder = Path(sys.argv[1])
    files = {p.suffix.lower(): p for p in folder.iterdir()}
    war = files['.war'].read_bytes()
    count, = struct.unpack_from('<I', war, 12)
    animations = {}
    for entry in struct.unpack_from('<%dI' % count, war, 16):
        if entry >> 24 != 0x44:
            continue
        offset = entry & 0xffffff
        table, = struct.unpack_from('<I', war, offset+16)
        joints, = struct.unpack_from('<H', war, offset+24)
        n, = struct.unpack_from('<I', war, table)
        pointers = struct.unpack_from('<%dI' % n, war, table+4)
        names = {war[p:p+8].split(b'\0')[0].decode(errors='replace').lower(): p for p in pointers if p}
        if not set(WANTED).issubset(names):
            continue
        animations = {alias: decode(war, names[name], joints) for name, alias in WANTED.items()}
        break
    assert animations, 'Ralph model not found'
    extra_folder = Path(sys.argv[2]) if len(sys.argv)>2 else folder.parent/'Lvl-01'
    extra_war=next(extra_folder.glob('*.[wW][aA][rR]')).read_bytes()
    extra_table=struct.unpack_from('<%dI'%struct.unpack_from('<I',extra_war,12)[0],extra_war,16)
    at=extra_table[0]&0xffffff;p,joints=struct.unpack_from('<I',extra_war,at+16)[0],struct.unpack_from('<H',extra_war,at+24)[0]
    n=struct.unpack_from('<I',extra_war,p)[0];pointers=struct.unpack_from('<%dI'%n,extra_war,p+4)
    extra_names={extra_war[q:q+8].split(b'\0')[0].decode().lower():q for q in pointers if q}
    animations.update({alias:decode(extra_war,extra_names[name],joints) for name,alias in AUX_WANTED.items()})
    sounds = {}
    snd = files['.snd'].read_bytes()
    offset = 12
    for _ in range(struct.unpack_from('<I', snd, 8)[0]):
        sound_id, size, flags = struct.unpack_from('<III', snd, offset)
        blob = snd[offset+12:offset+12+size]
        for local in (ROOT / 'assets/audio/sfx').glob('sfx_*.wav'):
            if local.read_bytes() == blob:
                sounds[str(sound_id)] = {'path': 'res://' + local.relative_to(ROOT).as_posix(), 'loop': bool(flags & 1)}
                break
        offset += 12 + size
    data = {'animations': animations, 'sounds': sounds}
    target = ROOT / 'assets/models/ralph_run_data.json'
    target.write_text(json.dumps(data, separators=(',', ':')))
    for alias, a in animations.items():
        print(alias, a['duration'], 'sound cues:', a['sound_cues'])
    # Preserve every sound referenced by the recovered death animations.
    required = {cue['sound_id'] for a in animations.values() for cue in a['sound_cues']}
    for sound_bank in [snd,next(extra_folder.glob('*.[sS][nN][dD]')).read_bytes()]:
        offset = 12
        for _ in range(struct.unpack_from('<I', sound_bank, 8)[0]):
            sound_id, size, flags = struct.unpack_from('<III', sound_bank, offset)
            if sound_id in required and str(sound_id) not in sounds:
                path = ROOT / f'assets/audio/sfx/original_{sound_id:04x}.wav'
                path.write_bytes(sound_bank[offset+12:offset+12+size])
                sounds[str(sound_id)] = {'path': 'res://' + path.relative_to(ROOT).as_posix(), 'loop': bool(flags&1)}
            offset += 12+size
    target.write_text(json.dumps(data, separators=(',', ':')))

    # FALL_TO_DEATH uses explicit state sounds rather than animation key cues.
    bank = next(extra_folder.glob('*.[sS][nN][dD]')).read_bytes()
    offset = 12
    for _ in range(struct.unpack_from('<I', bank, 8)[0]):
        sound_id, size, flags = struct.unpack_from('<III', bank, offset)
        label = {202:'original_void_fall',81:'original_void_impact'}.get(sound_id)
        if label:
            (ROOT/f'assets/audio/sfx/{label}.wav').write_bytes(bank[offset+12:offset+12+size])
        offset += 12+size

if __name__ == '__main__':
    main()
