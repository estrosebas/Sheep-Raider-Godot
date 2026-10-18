"""Recover original Goal trigger boxes/radius from an imported level's WAR."""
from pathlib import Path
import json,struct,sys
root=Path(__file__).resolve().parent.parent
folder=Path(sys.argv[1]);level=folder.name.lower().replace('-','_');out=root/'assets/levels'/level/'data'
w=next(folder.glob('*.[wW][aA][rR]')).read_bytes();t=struct.unpack_from('<%dI'%struct.unpack_from('<I',w,12)[0],w,16)
result=[]
for e in json.loads((out/'entities.json').read_text(encoding='utf8')):
 if e['class_id']!=23:continue
 a=t[e['model_res']]&0xffffff;p=struct.unpack_from('<I',w,a+12)[0];flags,*v=struct.unpack_from('<I6h',w,p+4)
 box={'flags':flags,'min':v[:3],'max':v[3:]}
 result.append({**e,'box':box,'radius':(box['max'][0]*90//128)*.01})
(out/'goals.json').write_text(json.dumps(result,indent=2),encoding='utf8',newline='\n')
print(level,len(result),'original goals')
