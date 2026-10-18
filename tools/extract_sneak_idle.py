"""Native WOLF_ST_SNEAK_IDLE = STAND11, from Lvl-01 Ralph WAR.
Usage: python tools/extract_sneak_idle.py PATH_TO_LVL_01
"""
import json
from pathlib import Path
import struct
import sys
from extract_run_assets import decode

folder = Path(sys.argv[1])
source = next(folder.glob('*.[wW][aA][rR]'))
war = source.read_bytes()
table = struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
model = table[0]&0xffffff
pointer = struct.unpack_from('<I',war,model+16)[0]
joints = struct.unpack_from('<H',war,model+24)[0]
count = struct.unpack_from('<I',war,pointer)[0]
pointers = struct.unpack_from('<%dI'%count,war,pointer+4)
names = {war[p:p+8].split(b'\0')[0].decode().lower():p for p in pointers if p}
animation = decode(war,names['stand11'],joints)
root = Path(__file__).resolve().parent.parent
(root/'assets/models/ralph_sneak_data.json').write_text(json.dumps({'sneak_idle':animation},separators=(',',':')))
print('STAND11 -> sneak_idle:',animation['duration'],'seconds;',joints,'joints;',animation['sound_cues'])
