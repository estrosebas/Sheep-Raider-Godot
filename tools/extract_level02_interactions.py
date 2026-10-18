"""Original push zones, bush disguise, animated fan/perfume and scent sheet."""
import json,struct,sys,re
from pathlib import Path
from extract_shared_items import read_rig,page_image
from extract_inventory_ui import read_lists
from extract_run_assets import decode
ROOT=Path(__file__).resolve().parents[1]
def main():
    decomp,folder=map(Path,sys.argv[1:3]);sys.path.insert(0,str(decomp/'tools'))
    import level_editor as editor,war_meshes
    w=next(folder.glob('*.WAR')).read_bytes();dp=next(folder.glob('*.DAV'));raw=dp.read_bytes();dav=war_meshes.read_dav(dp);dt=editor.dav_tables(raw)
    t=struct.unpack_from('<%dI'%struct.unpack_from('<I',w,12)[0],w,16)
    at=next(e&0xffffff for e in t if e>>24==0x82);n=struct.unpack_from('<I',w,at)[0];at+=4;ex={}
    for _ in range(n):
        identity,count=struct.unpack_from('<HH',w,at);ex[identity]=struct.unpack_from('<%dI'%count,w,at+4);at+=4+count*4
    es=json.loads((ROOT/'assets/levels/lvl_02/data/entities.json').read_text(encoding='utf8'))
    def save(p,data):
        p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(data,separators=(',',':')),encoding='utf8')
    def names(resource):
        p=struct.unpack_from('<I',w,(resource&0xffffff)+16)[0];qs=struct.unpack_from('<%dI'%struct.unpack_from('<I',w,p)[0],w,p+4)
        return {w[q:q+8].split(b'\0')[0].decode().lower():q for q in qs if q}
    definitions={}
    for slug,resource in [('fan',t[next(e['model_res'] for e in es if e['class_id']==7)]),('perfume',t[next(e['model_res'] for e in es if e['class_id']==39)]),('bush_disguise',next(e for e in t if e&0xffffff==ex[64][0])),('bush_world',t[next(e['model_res'] for e in es if e['class_id']==48)])]:
        base=ROOT/'assets/items'/slug;rig=read_rig(w,resource,editor,war_meshes,dt,{s:s for s in names(resource)})
        rig.update(rotation_order='ZXY',rotation_axis_sign=[1,1,-1]);save(base/'worn_data.json',rig)
        materials={}
        for page in rig['surfaces']:
            if int(page)<0:continue
            record=dav['pages'][int(page)];(base/'textures').mkdir(exist_ok=True)
            page_image(raw,record).save(base/'textures'/f'page_{page}.png');materials[page]=record['kind']
        definitions[slug]={'directory':'res://'+base.relative_to(ROOT).as_posix(),'materials':materials,'loop_animations':list(rig['animations'])}
    body_names=names(t[0]);joints=struct.unpack_from('<H',w,(t[0]&0xffffff)+24)[0]
    aliases={'push1a':'push_start','push1b':'push_loop','push1c':'push_end','standv1':'fan_blow_idle','walkv1':'fan_blow_turn','jump6':'bush_enter','out6':'bush_exit'}
    extra={alias:decode(w,body_names[name],joints) for name,alias in aliases.items()}
    save(ROOT/'assets/models/ralph_interaction_data.json',extra)
    # Emitting perfume uses sprite sheet 3 = DAV_IDI_IFLFUMEE.
    groups,banks=read_lists(raw);symbols=dict((s,int(v)) for s,v in re.findall(r'(DAV_IDI_\w+) = (\d+)',(decomp/'src/include/scenaric_props.h').read_text()))
    first=groups[symbols['DAV_IDI_IFLFUMEE']][0];frames=next(b for b in banks if first in b);paths=[]
    out=ROOT/'assets/effects/perfume';out.mkdir(parents=True,exist_ok=True)
    for i,bitmap in enumerate(frames):
        x,width,y,height,page=dav['rects'][bitmap];path=out/f'frame_{i}.png';page_image(raw,dav['pages'][page]).crop((x,y,x+width,y+height)).save(path);paths.append('res://'+path.relative_to(ROOT).as_posix())
    save(out/'source.json',{'frames':paths,'params':[450,-15,45056,1408,16,64,80,3]})
    rocks=[]
    for e in es:
        if e['class_id']!=16:continue
        p=struct.unpack_from('<I',w,(t[e['model_res']]&0xffffff)+12)[0]
        solid=next(p+4+i*16 for i in range(struct.unpack_from('<I',w,p)[0]) if not struct.unpack_from('<I',w,p+4+i*16)[0]&1)
        flags,*v=struct.unpack_from('<I6h',w,solid)
        zones=[]
        for q in ex.get(e['props']['0x0'],[]):
            f,*b=struct.unpack_from('<I6h',w,q);zones.append({'flags':f,'min':b[:3],'max':b[3:]})
        rocks.append({**e,'box':{'flags':flags,'min':v[:3],'max':v[3:]},'push_zones':zones})
    save(ROOT/'assets/levels/lvl_02/data/interactions.json',{'rocks':rocks,'definitions':definitions})
    print('Recovered native interactions:',list(definitions),'Ralph clips',list(extra),'scent frames',len(paths))
if __name__=='__main__':main()
