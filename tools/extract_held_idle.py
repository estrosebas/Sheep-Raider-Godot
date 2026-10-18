"""Wolf::SetIdleState / IdleAnimStep: STAND10, STAND9 and ROCKET1."""
import json
import struct
import sys
from pathlib import Path
from extract_run_assets import decode

ROOT = Path(__file__).resolve().parents[1]

def main():
    folder = Path(sys.argv[1])
    war = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    model = struct.unpack_from('<I',war,16)[0]&0xffffff
    table = struct.unpack_from('<I',war,model+16)[0]
    joints = struct.unpack_from('<H',war,model+24)[0]
    count = struct.unpack_from('<I',war,table)[0]
    pointers = struct.unpack_from('<%dI'%count,war,table+4)
    names = {war[p:p+8].split(b'\0')[0].decode().lower():p for p in pointers if p}
    animations = {alias:decode(war,names[name],joints) for name,alias in
                  [('stand10','held_item_idle'),('stand9','held_item_fidget'),('rocket1','rocket_idle')]}
    assert all(not clip['sound_cues'] for clip in animations.values())
    (ROOT/'assets/models/ralph_held_idle_data.json').write_text(json.dumps(animations,separators=(',',':')))
    print('Original held idles:',[(name,clip['original_name'],clip['duration']) for name,clip in animations.items()])

if __name__=='__main__': main()
