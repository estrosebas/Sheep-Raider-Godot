"""Import CameraRestriction records, influence boxes and paths from any PC WAR.
Usage: python tools/extract_camera_zones.py Levels/Lvl-00 [Levels/Lvl-01 ...]
"""
import json,struct,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def extract(folder):
 folder=Path(folder);slug=folder.name.lower().replace('-','_');out=ROOT/'assets/levels'/slug/'data'
 w=next(folder.glob('*.[wW][aA][rR]')).read_bytes();t=struct.unpack_from('<%dI'%struct.unpack_from('<I',w,12)[0],w,16)
 p=next(x&0xffffff for x in t if x>>24==0x82);n=struct.unpack_from('<I',w,p)[0];p+=4;ex={}
 for _ in range(n):
  k,c=struct.unpack_from('<HH',w,p);ex[k]=struct.unpack_from('<%dI'%c,w,p+4);p+=4+c*4
 def boxes(k):return [dict(flags=v[0],min=list(v[1:4]),max=list(v[4:])) for a in ex.get(k,[]) for v in [struct.unpack_from('<I6h',w,a)]]
 def signed(n):return n if n<0x80000000 else n-0x100000000
 def path(k):
  if not ex.get(k):return []
  a=ex[k][0];n=struct.unpack_from('<H',w,a)[0]
  return [list(struct.unpack_from('<3h',w,a+2+i*6)) for i in range(n)]
 cameras=[]
 for e in json.loads((out/'entities.json').read_text(encoding='utf8')):
  if e['class_id']!=19:continue
  d=e['props'];cameras.append(dict(resource=e['res'],boxes=boxes(d['0x44']),pitch=[signed(d['0x10']),signed(d['0xc'])],yaw=[signed(d['0x20']),signed(d['0x1c'])],roll=[signed(d['0x3c']),signed(d['0x38'])],distance=[d['0x2c']*.01,d['0x28']*.01],focal=d['0x30'],snap_yaw=bool(d['0x50']),forbid_pad=bool(d['0x34']),follow=bool(d['0x4c']&1),mirror_yaw=bool(d['0x48']),aim_offset=[signed(d['0x0'])*.01,signed(d['0x8'])*.01,-signed(d['0x4'])*.01],trajectory=path(d['0x54']),eye_vertical_max=-signed(d['0x18'])*.01))
 (out/'camera_zones.json').write_text(json.dumps(dict(level=slug,cameras=cameras,source='CameraRestriction::PostLoadInit / WAR class19'),indent=2)+'\n',encoding='utf8')
 print(slug,len(cameras),'native camera zones;',sum(bool(c['trajectory']) for c in cameras),'paths')
 return cameras
if __name__=='__main__':
 for folder in sys.argv[1:]:extract(folder)
