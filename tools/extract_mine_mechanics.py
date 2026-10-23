"""Native DefusableMine codes, DAV panel and alternate explosion; reusable by level."""
import json,re,struct,sys
from pathlib import Path
from extract_inventory_ui import read_lists
from extract_shared_items import read_rig,page_image
ROOT=Path(__file__).resolve().parents[1]
def main():
    decomp,folder=map(Path,sys.argv[1:3]);sys.path.insert(0,str(decomp/'tools'))
    import level_editor as editor,war_meshes
    slug=folder.name.lower().replace('-','_');base=ROOT/'assets/levels'/slug
    war=next(folder.glob('*.[wW][aA][rR]')).read_bytes();table=struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
    p=next(v&0xffffff for v in table if v>>24==0x82);n=struct.unpack_from('<I',war,p)[0];p+=4;exports={}
    for _ in range(n):
        i,c=struct.unpack_from('<HH',war,p);exports[i]=struct.unpack_from('<%dI'%c,war,p+4);p+=4+c*4
    entities=json.loads((base/'data/entities.json').read_text(encoding='utf8'));manifest=json.loads((base/'data/manifest.json').read_text(encoding='utf8'))
    mines=[{**e,'directory':manifest['models'][str(e['model_res'])]['directory'],
            'pattern':[(e['props']['0x0']>>(i*2))&3 for i in range(e['props']['0x8'])],
            'phase_seconds':(3-e['props']['0x4']*.01)%3,'staged':False} for e in entities if e['class_id']==64]
    if not mines:return
    sam=next((e for e in entities if e['class_id']==1),None)
    if sam and sam['props']['0x40']&0x400:
        cine_id=sam['props']['0xc'];cine=json.loads((base/f'cinematics/sequence_{cine_id}.json').read_text(encoding='utf8'))
        ids={m['res'] for m in mines};staged=[]
        for track in cine['tracks']:
            if track['selector']!=2 or track['index'] not in ids:continue
            positions=next(r['keys'] for r in track['records'] if r['opcode']==1)
            staged.append(dict(resource=track['index'],position=positions[-1]['value']))
        for mine in mines:mine['staged']=any(m['resource']==mine['res'] for m in staged)
        p=exports[sam['props']['0x4c']][0];n=struct.unpack_from('<H',war,p)[0]
        patrol=[list(struct.unpack_from('<3h',war,p+2+i*6)) for i in range(n)]
        encounter=dict(guard=sam['res'],cine_id=cine_id,staged_mines=staged,patrol=patrol,patrol_speed=2.0,
                       flute_resource=next(e['res'] for e in entities if e['class_id']==41),
                       source='Sam::EnterCin01State / SAM_STT_CIN01 / EnterFollowTrajectoryState')
        (base/'data/sam_flute_encounter.json').write_text(json.dumps(encounter,indent=2))
    dp=next(folder.glob('*.[dD][aA][vV]'));raw=dp.read_bytes();dav=war_meshes.read_dav(dp);groups,_=read_lists(raw)
    symbols=(decomp/'src/include/scenaric_props.h').read_text();directory=base/'effects/mines';directory.mkdir(parents=True,exist_ok=True)
    sprites={}
    for name,symbol in [('panel','IMNINT1_'),('top','IMNINT3_'),('glyph','IMNINT2_'),('beat','IMNCHEK_')]:
        identity=int(re.search(r'DAV_IDI_'+symbol+r'\s*=\s*(\d+)',symbols)[1]);bitmap=groups[identity][0]
        x,w,y,h,page=dav['rects'][bitmap];path=directory/(name+'.png');page_image(raw,dav['pages'][page]).crop((x,y,x+w,y+h)).save(path)
        sprites[name]='res://'+path.relative_to(ROOT).as_posix()
    resource=next(r for r in table if r&0xffffff==exports[3][0])
    at=resource&0xffffff;p=struct.unpack_from('<I',war,at+16)[0];n=struct.unpack_from('<I',war,p)[0]
    names={war[q:q+8].split(b'\0')[0].decode().lower() for q in struct.unpack_from('<%dI'%n,war,p+4) if q}
    rig=read_rig(war,resource,editor,war_meshes,editor.dav_tables(raw),{s:s for s in names});rig.update(rotation_order='ZXY',rotation_axis_sign=[1,1,-1])
    target=directory/'explosion';target.mkdir(exist_ok=True);(target/'textures').mkdir(exist_ok=True)
    (target/'worn_data.json').write_text(json.dumps(rig,separators=(',',':')));materials={}
    for page in rig['surfaces']:
        if int(page)<0:continue
        rec=dav['pages'][int(page)];page_image(raw,rec).save(target/'textures'/f'page_{page}.png');materials[page]=rec['kind']
    data=dict(mines=mines,sprites=sprites,explosion={'directory':'res://'+target.relative_to(ROOT).as_posix(),'materials':materials},
              source='mine.cpp::DefusableMine::Update/PostLoadInit; triangle/circle/square/cross -> up/right/left/down')
    (base/'data/mines.json').write_text(json.dumps(data,indent=2));print(slug,'mines',[(m['res'],m['pattern'],m['staged']) for m in mines])
if __name__=='__main__':main()
