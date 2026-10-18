"""Recover Sam WIN with the original inherited PUNCH7 pose, preserving other assets."""
import json,struct,sys
from pathlib import Path
from extract_run_assets import decode
root=Path(__file__).resolve().parent.parent
war=(Path(sys.argv[1])/'Levels/Lvl-01/Lvl-01.WAR').read_bytes()
table=struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
base=root/'assets/levels/lvl_01/models/2';data=json.loads((base/'worn_data.json').read_text(encoding='utf8'))
a=table[2]&0xffffff;p=struct.unpack_from('<I',war,a+16)[0]
ptrs=struct.unpack_from('<%dI'%struct.unpack_from('<I',war,p)[0],war,p+4)
names={war[q:q+8].split(b'\0')[0].lower():q for q in ptrs if q}
data['animations']['win']=decode(war,names[b'win'],len(data['joints']),data['animations']['punch7']['frames'][-1]['joints'])
(base/'worn_data.json').write_text(json.dumps(data,separators=(',',':')),encoding='utf8')
print('WIN:',data['animations']['win']['duration'],data['animations']['win']['sound_cues'])
