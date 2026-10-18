"""Extract native MLT banks, BSV voice ids and localized overlays; no scene copies."""
import json, struct, sys, shutil, re
from pathlib import Path
from extract_level01_ai import decode_text
ROOT=Path(__file__).resolve().parent.parent
LANGS={'en':('english',0,1),'pt_BR':('brazilian',3,6),'es':('spanish',1,2),'it':('italian',2,3)}
def read_mlt(path):
 raw=path.read_bytes(); blocks,lists=struct.unpack_from('<HH',raw,8);p=16;result=[]
 for _ in range(blocks):
  bank=[]
  for _ in range(lists):
   count=raw[p];p+=1;strings=[]
   for _ in range(count):
    end=raw.index(0,p);strings.append(decode_text(raw[p:end]));p=end+1
   bank.append(strings)
  result.append(bank)
 assert p==len(raw),(path,p,len(raw))
 return result

def main():
 game=Path(sys.argv[1]); out=ROOT/'assets/localization';verify='--verify' in sys.argv
 def save(path,data):
  if verify: assert json.loads(path.read_text(encoding='utf8'))==data,path
  else: path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')),encoding='utf8')
 manifest={'fallback':'es','order':['en','pt_BR','es','it'],'languages':{},'levels':{},'files':{}}
 names=[];b=(game/'References/MusicVoice.BSV').read_bytes();p=12
 for _ in range(116):
  n=struct.unpack_from('<I',b,p)[0];p+=4;names.append(b[p:p+n].split(b'\0')[0].decode());p+=n
 # Every level can reuse text(level,list,index). Copy voices once, keyed by BSV id.
 for code,(folder,config,block) in LANGS.items():
  entry={'name':{'en':'english','pt_BR':'Português','es':'español','it':'italiano'}[code],'config_id':config,'mlt_block':block,'voices':{}}
  for identity,name in enumerate(names,1):
   source=game/'Voices'/folder/name
   if not source.exists(): continue
   dest=out/'voices'/code/name
   if verify: assert dest.read_bytes()==source.read_bytes(),dest
   else:
    dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,dest)
   entry['voices'][str(identity)]='res://'+dest.relative_to(ROOT).as_posix()
  manifest['languages'][code]=entry
 for folder in (game/'Levels').iterdir():
  files=list(folder.glob('*.[mM][lL][tT]'))
  if not files: continue
  banks=read_mlt(files[0]);slug=folder.name.lower().replace('-','_');manifest['levels'][slug]={}
  for code,(_,_,block) in LANGS.items():
   if block>=len(banks): continue
   dest=out/'levels'/slug/(code+'.json');save(dest,{'source':str(files[0].relative_to(game)),'block':block,'lists':banks[block]})
   manifest['levels'][slug][code]='res://'+dest.relative_to(ROOT).as_posix()
 for level in manifest['levels']:
  if not (ROOT/'assets/levels'/level/'data').exists() or not level.startswith('lvl_'): continue
  sourcefolder=game/'Levels'/level.replace('_','-',1).replace('lvl','Lvl');banks=read_mlt(next(sourcefolder.glob('*.[mM][lL][tT]')))
  indexes={}
  for i,strings in enumerate(banks[2]):
   for j,text in enumerate(strings):
    if text: indexes.setdefault(text,(i,j))
  paths=list((ROOT/'assets/levels'/level/'data').glob('*.json'))
  if level=='lvl_00':
   paths+=[ROOT/'assets/cinematics/camera_training/lessons.json']
   paths+=list((ROOT/'assets/cinematics/tutorial_intro').glob('*sequence.json'))
  else: paths+=list((ROOT/'assets/levels'/level/'cinematics').glob('sequence_*.json'))
  for path in paths:
   if path.stat().st_size>300000: continue
   original=json.loads(path.read_text(encoding='utf8'));res='res://'+path.relative_to(ROOT).as_posix()
   manifest['files'][res]={}
   for code,(voicefolder,_,block) in LANGS.items():
    count=[0]
    def localize(value):
     if isinstance(value,dict): return {k:localize(v) for k,v in value.items()}
     if isinstance(value,list): return [localize(v) for v in value]
     if not isinstance(value,str): return value
     if value in indexes:
      i,j=indexes[value];count[0]+=1;return banks[block][i][j]
     if value.startswith('res://') and Path(value).name in names and ('voices/' in value.lower()):
      count[0]+=1;return manifest['languages'][code]['voices'].get(str(names.index(Path(value).name)+1),value)
     return value
    result=localize(original)
    if count[0]:
     dest=out/'overlays'/level/code/path.name;save(dest,result);manifest['files'][res][code]='res://'+dest.relative_to(ROOT).as_posix()
   if not manifest['files'][res]: del manifest['files'][res]
 save(out/'manifest.json',manifest)
 print('Locales:',list(LANGS),'level banks:',len(manifest['levels']),'localized data files:',len(manifest['files']))
if __name__=='__main__': main()
