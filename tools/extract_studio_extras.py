"""Native BonusManager packs, DAV UI, pedestal cameras and models from Scene."""
import json,re,struct,sys
from pathlib import Path
from extract_inventory_ui import read_lists
from extract_shared_items import page_image
ROOT=Path(__file__).resolve().parents[1]
def main():
    decomp,game=map(Path,sys.argv[1:3]);sys.path.insert(0,str(decomp/'tools'))
    import war_meshes
    out=ROOT/'assets/hub/bonuses';out.mkdir(parents=True,exist_ok=True)
    entries=[]
    for name,price in [('Perso',1),('Decor',2),('Story',2),('Color',1),('Team',2),('Intro',3)]:
        data=(game/'Bonus'/f'{name}.sdw').read_bytes();count=struct.unpack_from('<I',data,8)[0]
        images=[]
        for i in range(count):
            p=12+i*24;offset=struct.unpack_from('<I',data,p)[0]
            filename=data[p+9:p+24].split(b'\0')[0].decode('ascii')
            end=data.find(b'\xff\xd9',offset)+2
            assert data[offset:offset+2]==b'\xff\xd8' and end>offset
            target=out/name.lower()/filename;target.parent.mkdir(exist_ok=True)
            target.write_bytes(data[offset:end]);images.append('res://'+target.relative_to(ROOT).as_posix())
        entries.append(dict(kind='images',pack=name.upper(),price=price,images=images))
    entries.extend([dict(kind='text',price=3,text_index=25),dict(kind='text',price=3,text_index=26)])
    folder=game/'Levels/Scene';raw=(folder/'Scene.DAV').read_bytes();dav=war_meshes.read_dav(folder/'Scene.DAV');groups,_=read_lists(raw)
    enums=(decomp/'src/include/scenaric_props.h').read_text()
    sprites={}
    for name,symbol in [('locked','IBOCKOI_'),('unlocked','IBOCKOI_'),('background','IMEMCMAP'),('arrow','IGLFLEC_')]:
        m=re.search(r'DAV_IDI_'+symbol+r'\s*=\s*(0x[0-9a-f]+|\d+)',enums)
        identity=int(m[1],0)+(1 if name=='unlocked' else 0);bitmap=groups[identity][0];x,w,y,h,page=dav['rects'][bitmap]
        target=out/(name+'.png');page_image(raw,dav['pages'][page]).crop((x,y,x+w,y+h)).save(target)
        sprites[name]=dict(path='res://'+target.relative_to(ROOT).as_posix(),resource=identity,bitmap=bitmap,page=page,rect=[x,y,w,h])
    w=(folder/'Scene.WAR').read_bytes();t=struct.unpack_from('<%dI'%struct.unpack_from('<I',w,12)[0],w,16)
    p=next(r&0xffffff for r in t if r>>24==0x82);n=struct.unpack_from('<I',w,p)[0];p+=4;ex={}
    for _ in range(n):
        identity,count=struct.unpack_from('<HH',w,p);ex[identity]=struct.unpack_from('<%dI'%count,w,p+4);p+=4+count*4
    entities=json.loads((ROOT/'assets/levels/scene/data/entities.json').read_text())
    pedestals=[]
    for e in entities:
        if e['class_id'] not in [98,190]:continue
        camera=struct.unpack_from('<H6h',w,ex[e['props']['0x0']][0])
        pedestals.append({**e,'camera':dict(focal=camera[0],rotation=camera[1:4],eye=camera[4:])})
        p=ROOT/f"assets/levels/scene/models/{e['model_res']}/worn_data.json"
        rig=json.loads(p.read_text());rig.update(rotation_order='ZXY',rotation_axis_sign=[1,1,-1]);p.write_text(json.dumps(rig,separators=(',',':')))
    manifest=dict(source='BonusManager::g_bonusEntries / PackJpeg::Open / MCardManager::PostLoadInit',entries=entries,pedestals=pedestals,sprites=sprites)
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2))
    print('Native extras:',len(entries),'entries,',sum(len(e.get('images',[])) for e in entries),'images,',len(pedestals),'pedestals')
if __name__=='__main__':main()
