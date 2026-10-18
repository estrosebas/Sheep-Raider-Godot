"""Recover the language wheel and Daffy from Wheel WAR/DAV (shared by locales)."""
import json,struct,sys
from pathlib import Path
from extract_shared_items import read_rig,page_image
ROOT=Path(__file__).resolve().parent.parent
D,G=map(Path,sys.argv[1:3]);sys.path.insert(0,str(D/'tools'))
import level_editor as editor,war_meshes,war_objects
folder=G/'Levels/Wheel';war_objects.LEVELS=G/'Levels'
w=(folder/'wheel.war').read_bytes();raw=(folder/'wheel.DAV').read_bytes();dav=war_meshes.read_dav(folder/'wheel.DAV');dt=editor.dav_tables(raw)
t=struct.unpack_from('<%dI'%struct.unpack_from('<I',w,12)[0],w,16)
out=ROOT/'assets/localization/wheel';out.mkdir(parents=True,exist_ok=True)
p=next(e&0xffffff for e in t if e>>24==0x82);n=struct.unpack_from('<I',w,p)[0];p+=4;exports={}
for _ in range(n):
 i,c=struct.unpack_from('<HH',w,p);exports[i]=struct.unpack_from('<%dI'%c,w,p+4);p+=4+c*4
actors=[];sounds=set()
for obj in war_objects.objects('Wheel'):
 if obj['class'] not in [187,152,12]:continue
 model=struct.unpack_from('<H',w,obj['offset'])[0];at=t[model]&0xffffff;p=struct.unpack_from('<I',w,at+16)[0];n=struct.unpack_from('<I',w,p)[0];ptrs=struct.unpack_from('<%dI'%n,w,p+4)
 names={w[q:q+8].split(b'\0')[0].decode().lower() for q in ptrs if q};data=read_rig(w,t[model],editor,war_meshes,dt,{name:name for name in names});data.update(rotation_order='ZXY',rotation_axis_sign=[1,1,-1])
 base=out/({187:'daffy',152:'wheel',12:'base'}[obj['class']]);(base/'textures').mkdir(parents=True,exist_ok=True);materials={}
 for page in data['surfaces']:
  if int(page)<0:continue
  record=dav['pages'][int(page)];page_image(raw,record).save(base/'textures'/f'page_{page}.png');materials[page]=record['kind']
 (base/'worn_data.json').write_text(json.dumps(data,separators=(',',':')))
 (base/'definition.json').write_text(json.dumps({'materials':materials}))
 for animation in data['animations'].values():sounds.update(c['sound_id'] for c in animation['sound_cues'])
 actor={'directory':'res://'+base.relative_to(ROOT).as_posix(),'class':obj['class'],'position':[obj['x']*.01,-obj['y']*.01,-obj['z']*.01],'yaw':-obj['rot'][1]*6.283185307/4096}
 if obj['class']==187:
  identity=struct.unpack_from('<I',w,obj['offset']+24)[0]
  focal,*v=struct.unpack_from('<H6h',w,exports[identity][0]);actor['camera']={'focal':focal,'rotation':v[:3],'eye':v[3:]}
 actors.append(actor)
# Placed GEOM records are the studio scenery, separate from actor rigs.
background={}
for entry in t:
 if entry>>24 not in [3,0x0b,0x26]: continue
 for page,packed in editor.geometry(w,dt,entry&0xffffff,False)['groups'].items():
  group=background.setdefault(page,{'verts':[],'uvs':[],'cols':[]})
  divisor=128 if int(page)>=0 else 255
  for i in range(0,len(packed),8):
   x,y,z,u,v,r,g,b=packed[i:i+8];group['verts'].append([x*.01,-y*.01,z*.01]);group['uvs'].append([u,v]);group['cols'].append([r/divisor,g/divisor,b/divisor])
base=out/'background';(base/'textures').mkdir(parents=True,exist_ok=True)
materials={}
for page in background:
 if int(page)<0: continue
 record=dav['pages'][int(page)];page_image(raw,record).save(base/'textures'/f'page_{page}.png');materials[page]=record['kind']
(base/'mesh_data.json').write_text(json.dumps(background,separators=(',',':')))
(base/'definition.json').write_text(json.dumps({'materials':materials}))
# StreamPlayer::LoadLevelMusic clamps frontend/Wheel to SCENE_LVL_00.
music=out/'audio'/'jungle_v1.wav';music.parent.mkdir(exist_ok=True)
music.write_bytes((G/'Musics/Jungle_v1.wav').read_bytes())
bank={};snd=(folder/'wheel.SND').read_bytes();p=12
for _ in range(struct.unpack_from('<I',snd,8)[0]):
 i,size,flags=struct.unpack_from('<III',snd,p)
 if i in sounds:
  dest=out/'audio'/f'{i}.wav';dest.parent.mkdir(exist_ok=True);dest.write_bytes(snd[p+12:p+12+size]);bank[str(i)]='res://'+dest.relative_to(ROOT).as_posix()
 p+=12+size
(out/'source.json').write_text(json.dumps({'actors':actors,'sounds':bank,'order':['en','pt_BR','es','it'],'angle_step':1.5707964,'music':'res://assets/localization/wheel/audio/jungle_v1.wav','source':'Scene_Wheel::Update / DaffyWheel::Update'}))
print(actors,'sounds',bank)
