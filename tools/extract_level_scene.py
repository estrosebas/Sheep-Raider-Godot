"""Reusable WAR/DAV scene foundation: geometry, rigs, collision, objects and props.
python tools/extract_level_scene.py DECOMP LEVEL_FOLDER [--verify]
"""
import json,struct,sys
from pathlib import Path
from extract_shared_items import read_rig,page_image
ROOT=Path(__file__).resolve().parent.parent
def main():
    decomp,folder=map(Path,sys.argv[1:3]);verify='--verify' in sys.argv
    all_animations='--all-animations' in sys.argv
    runtime_adjusted='--runtime-adjusted' in sys.argv
    sys.path.insert(0,str(decomp/'tools'))
    import level_editor as editor,war_meshes,war_objects,war_collision
    war_objects.LEVELS=war_collision.LEVELS=folder.parent
    schema=war_objects.class_schema();war=war_objects.war_path(folder.name).read_bytes()
    dav_path=next(p for p in folder.iterdir() if p.suffix.lower()=='.dav');raw=dav_path.read_bytes();dav=war_meshes.read_dav(dav_path);dt=editor.dav_tables(raw)
    table=struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
    slug=folder.name.lower().replace('-','_');out=ROOT/'assets/levels'/slug
    (out/'data').mkdir(parents=True,exist_ok=True);(out/'textures').mkdir(exist_ok=True)
    def save(path,data):
        if verify:assert json.loads(path.read_text(encoding='utf8'))==data,path
        else:path.write_text(json.dumps(data,separators=(',',':'),ensure_ascii=False),encoding='utf8')
    def groups(geometry):
        result={}
        for page,values in geometry['groups'].items():
            g={'verts':[],'uvs':[],'cols':[]}
            for i in range(0,len(values),8):
                x,y,z,u,v,r,bg,b=values[i:i+8];divisor=128 if int(page)>=0 else 255
                g['verts'].append([x*.01,-y*.01,z*.01]);g['uvs'].append([u,v]);g['cols'].append([r/divisor,bg/divisor,b/divisor])
            result[str(page)]=g
        return result
    banks={'scenery':{},'sky':{}}
    for entry in table:
        kind=entry>>24
        if kind not in [3,11,38]:continue
        target=banks['sky' if kind==38 else 'scenery']
        for page,g in groups(editor.geometry(war,dt,entry&0xffffff,False)).items():
            existing=target.setdefault(page,{'verts':[],'uvs':[],'cols':[]})
            for key in existing:existing[key].extend(g[key])
    for name,bank in banks.items():save(out/'data'/f'{name}.json',bank)
    entities=[];models={};solids=[]
    for o in war_objects.objects(folder.name):
        cid=o['class'];rec=o['offset'];model=struct.unpack_from('<H',war,rec)[0];sc=schema.get(cid,{})
        props={hex(p['offset']):struct.unpack_from('<I',war,rec+20+p['offset'])[0] for p in sc.get('props',[])}
        entity={'res':o['res'],'class_id':cid,'class_name':sc.get('name',str(cid)),'model_res':model,
            'pos':[o['x']*.01,-o['y']*.01,o['z']*.01],'rot':list(o['rot']),'props':props}
        entities.append(entity)
        if cid==0 or model>=len(table) or table[model]>>24 not in [67,68]:continue
        at=table[model]&0xffffff
        if model not in models:
            base=out/'models'/str(model);base.mkdir(parents=True,exist_ok=True)
            animated=table[model]>>24==68
            if animated:
                ptr=struct.unpack_from('<I',war,at+16)[0];n=struct.unpack_from('<I',war,ptr)[0];pointers=struct.unpack_from('<%dI'%n,war,ptr+4)
                names=[war[p:p+8].split(b'\0')[0].decode().lower() for p in pointers if p]
                selected=[name for name in names if name in ['stand1','stand','stand0','default','idle','closed','close1']]
                if cid in [1,11,4,2,13]: selected=names
                if all_animations: selected=names
                if cid==38: selected=sorted(names,key=lambda name: name!='clock1')
                if cid==1: selected=sorted(names,key=lambda name: name!='head2')
                if not selected:selected=names[:1]
                rig=read_rig(war,table[model],editor,war_meshes,dt,{name:name for name in selected})
                if cid==1 and 'head1' in rig['animations'] and 'head2' in rig['animations']:
                    # Anim_DecodeFirstKey only changes listed joints. Sam::Reset
                    # plays START before lookout HEAD2 (head-only animation).
                    # Preserve that original body pose instead of identity/T-pose.
                    from extract_run_assets import decode
                    pointer=next(q for q in pointers if q and war[q:q+8].split(b'\0')[0].decode().lower()=='head2')
                    rig['animations']['head2']=decode(war,pointer,len(rig['joints']),rig['animations']['start']['frames'][-1]['joints'])
                if runtime_adjusted:
                    # Renderer convention plus Sam's native partial WIN pose.
                    rig.update(rotation_order='ZXY',rotation_axis_sign=[1,1,-1])
                    if cid==1 and 'win' in rig['animations'] and 'punch7' in rig['animations']:
                        from extract_run_assets import decode
                        pointer=next(q for q in pointers if q and war[q:q+8].split(b'\0')[0].decode().lower()=='win')
                        rig['animations']['win']=decode(war,pointer,len(rig['joints']),rig['animations']['punch7']['frames'][-1]['joints'])
                idle=selected[0] if selected else ''
            else:rig={'static':True,'joints':[],'animations':{},'surfaces':groups(editor.geometry(war,dt,at,False))};idle=''
            save(base/'worn_data.json',rig)
            models[str(model)]={'directory':'res://'+base.relative_to(ROOT).as_posix(),'idle':idle,'animated':animated}
        ptr=struct.unpack_from('<I',war,at+12)[0]
        boxes=[]
        if ptr:
            for i in range(struct.unpack_from('<I',war,ptr)[0]):
                flags,*corners=struct.unpack_from('<I6h',war,ptr+4+i*16)
                if not flags&1:boxes.append({'flags':flags,'min':corners[:3],'max':corners[3:]})
        if boxes and cid not in [0,1,11,19,23,25,30,32,33,70,74,106,137,160,161,176]:
            solids.append({'res':o['res'],'class_name':entity['class_name'],'position':entity['pos'],'rotation':entity['rot'],'model_res':model,'boxes':boxes})
    save(out/'data/entities.json',entities);save(out/'data/solid_boxes.json',solids)
    materials={str(i):p['kind'] for i,p in enumerate(dav['pages'])}
    for i,p in enumerate(dav['pages']):
        image=page_image(raw,p);path=out/'textures'/f'page_{i}.png'
        if verify:
            from PIL import Image
            assert Image.open(path).convert('RGBA').tobytes()==image.tobytes(),path
        else:image.save(path)
    name,grid,triangles=war_collision.load(folder.name)
    # war_collision exposes original x,y-down,z; write native x,-y,-z.
    collision=[[ [x*.01,-y*.01,-z*.01] for x,y,z in tri['verts']] for tri in triangles]
    save(out/'data/collision.json',collision)
    manifest={'level':slug,'source':folder.name,'models':models,'materials':materials,
        'texture_directory':'res://'+out.relative_to(ROOT).as_posix(),
        'spawn':next(e for e in entities if e['class_id']==0),'collision_triangles':len(triangles),
        'scenery_vertices':sum(len(g['verts']) for g in banks['scenery'].values()),'sky_vertices':sum(len(g['verts']) for g in banks['sky'].values())}
    save(out/'data/manifest.json',manifest)
    if not verify:
        from extract_level_background import extract
        extract(folder)
    print(folder.name,'entities',len(entities),'models',len(models),'triangles',len(triangles),'pages',len(materials),'verified=',verify)
if __name__=='__main__':main()
