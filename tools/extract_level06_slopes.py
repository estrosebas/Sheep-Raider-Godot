"""WAR SLIDEBOX/ICEBOX and CameraRestriction records; native Ralph slide poses."""
import json,struct,sys
from pathlib import Path
from extract_run_assets import decode
ROOT=Path(__file__).resolve().parents[1]
folder=Path(sys.argv[1]);w=next(folder.glob('*.[wW][aA][rR]')).read_bytes()
t=struct.unpack_from('<%dI'%struct.unpack_from('<I',w,12)[0],w,16)
p=next(x&0xffffff for x in t if x>>24==0x82);n=struct.unpack_from('<I',w,p)[0];p+=4;exports={}
for _ in range(n):
 k,c=struct.unpack_from('<HH',w,p);exports[k]=struct.unpack_from('<%dI'%c,w,p+4);p+=4+c*4
def boxes(k):
 return [dict(flags=v[0],min=list(v[1:4]),max=list(v[4:])) for a in exports.get(k,[]) for v in [struct.unpack_from('<I6h',w,a)]]
def signed(n):return n if n<0x80000000 else n-0x100000000
out=ROOT/'assets/levels/lvl_06/data'
(out/'slopes.json').write_text(json.dumps(dict(slide_boxes=boxes(104),ice_boxes=boxes(92),source='WAR_IDO_SLIDEBOX104 / ICEBOX92; Wolf_SurfaceVelocity'),indent=2)+'\n',encoding='utf8')
a=t[0]&0xffffff;p=struct.unpack_from('<I',w,a+16)[0];j=struct.unpack_from('<H',w,a+24)[0];n=struct.unpack_from('<I',w,p)[0]
names={w[q:q+8].split(b'\0')[0].decode().lower():q for q in struct.unpack_from('<%dI'%n,w,p+4) if q}
data={dest:decode(w,names[src],j) for src,dest in [('slide3','slope_slide'),('slide4','sheep_carry_slide')]}
(ROOT/'assets/models/ralph_slope_data.json').write_text(json.dumps(data,separators=(',',':')),encoding='utf8')
print('Lv06:8 native slide boxes,7 camera restrictions,SLIDE3/SLIDE4 poses')

# Keep camera imports in the shared file for all levels.
from extract_camera_zones import extract
extract(folder)
