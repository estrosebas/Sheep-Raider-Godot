"""Lvl01 original mailbox, dynamite/rocks, scroll regions and shared actors."""
import json,struct,sys,re
from pathlib import Path
from extract_shared_items import read_rig,page_image
from extract_inventory_ui import read_lists
ROOT=Path(__file__).resolve().parent.parent
def main():
    decomp,folder=map(Path,sys.argv[1:3]);verify='--verify' in sys.argv;sys.path.insert(0,str(decomp/'tools'))
    import level_editor as editor,war_meshes
    w=(folder/'Lvl-01.WAR').read_bytes();raw=(folder/'Lvl-01.DAV').read_bytes();dav=war_meshes.read_dav(folder/'Lvl-01.DAV');dt=editor.dav_tables(raw)
    t=struct.unpack_from('<%dI'%struct.unpack_from('<I',w,12)[0],w,16)
    out=ROOT/'assets/levels/lvl_01';entities=json.loads((out/'data/entities.json').read_text(encoding='utf8'))
    def save(path,data):
        path.parent.mkdir(parents=True,exist_ok=True)
        if verify:assert json.loads(path.read_text(encoding='utf8'))==data,path
        else:path.write_text(json.dumps(data,separators=(',',':'),ensure_ascii=False),encoding='utf8')
    at=next(e&0xffffff for e in t if e>>24==0x82);n=struct.unpack_from('<I',w,at)[0];at+=4;exports={}
    for _ in range(n):
        identity,count=struct.unpack_from('<HH',w,at);exports[identity]=struct.unpack_from('<%dI'%count,w,at+4);at+=4+count*4
    def camera(identity):
        if not identity:return None
        focal,*v=struct.unpack_from('<H6h',w,exports[identity][0]);return {'focal':focal,'rotation':v[:3],'eye':v[3:]}
    def boxes(model):
        at=t[model]&0xffffff;p=struct.unpack_from('<I',w,at+12)[0];result=[]
        if p:
            for i in range(struct.unpack_from('<I',w,p)[0]):
                flags,*v=struct.unpack_from('<I6h',w,p+4+i*16);result.append({'flags':flags,'min':v[:3],'max':v[3:]})
        return result
    mailbox=next(e for e in entities if e['class_id']==4).copy();props=mailbox['props']
    mailbox['directory']='res://assets/levels/lvl_01/models/7';mailbox['boxes']=boxes(7);mailbox['camera']=camera(props['0x14'])
    mailbox['item_resources']=[next(i for i,e in enumerate(t) if e&0xffffff==p) for slot in ['0x24','0x28','0x2c','0x30'] if props[slot] for p in exports[props[slot]]]
    # ACAISS01 used by generated boxes is shared with tutorial; contents use Lvl01 placement.
    box=next(d for d in json.loads((ROOT/'assets/levels/lvl_00/puzzle/definitions.json').read_text())['objects'] if d['class_name']=='DeliveryBox')
    dynamite=next(e for e in entities if e['class_id']==2)
    base=ROOT/'assets/items/dynamite';(base/'textures').mkdir(parents=True,exist_ok=True)
    at=t[8]&0xffffff;p=struct.unpack_from('<I',w,at+16)[0];n=struct.unpack_from('<I',w,p)[0];ptrs=struct.unpack_from('<%dI'%n,w,p+4)
    names={w[q:q+8].split(b'\0')[0].decode().lower() for q in ptrs if q}
    rig=read_rig(w,t[8],editor,war_meshes,dt,{name:name for name in names});rig.update(rotation_order='ZXY',rotation_axis_sign=[1,1,-1]);save(base/'worn_data.json',rig)
    geometry=editor.geometry(w,dt,t[8]&0xffffff,True);preview={}
    for page,v in geometry['groups'].items():
        divisor=128 if int(page)>=0 else 255
        preview[page]={'verts':[[v[i]*.01,-v[i+1]*.01,v[i+2]*.01] for i in range(0,len(v),8)],'uvs':[v[i+3:i+5] for i in range(0,len(v),8)],'cols':[[c/divisor for c in v[i+5:i+8]] for i in range(0,len(v),8)]}
    save(base/'mesh_data.json',preview)
    materials={}
    for page in rig['surfaces']:
        if int(page)<0:continue
        record=dav['pages'][int(page)];image=page_image(raw,record);path=base/'textures'/f'page_{page}.png'
        if verify:
            from PIL import Image
            assert Image.open(path).convert('RGBA').tobytes()==image.tobytes()
        else:image.save(path)
        materials[page]=record['kind']
    definitions=json.loads((ROOT/'assets/items/definitions.json').read_text(encoding='utf8'))
    definition={'slug':'dynamite','label':'Dinamita','mesh':'res://assets/items/dynamite/preview.tres','materials':materials}
    definitions['2']=definition;save(ROOT/'assets/items/definitions.json',definitions)
    inverse={entry&0xffffff:i for i,entry in enumerate(t)}
    explosion_model=inverse[exports[3][0]] # Dynamite_Create alternate WAR_IDO_AEXPLOS1.
    at=t[explosion_model]&0xffffff;p=struct.unpack_from('<I',w,at+16)[0];n=struct.unpack_from('<I',w,p)[0];ptrs=struct.unpack_from('<%dI'%n,w,p+4)
    explosion_names={w[q:q+8].split(b'\0')[0].decode().lower() for q in ptrs if q}
    explosion=read_rig(w,t[explosion_model],editor,war_meshes,dt,{name:name for name in explosion_names})
    alt=base/'explosion';(alt/'textures').mkdir(parents=True,exist_ok=True);save(alt/'worn_data.json',explosion);alt_materials={}
    for page in explosion['surfaces']:
        if int(page)<0:continue
        record=dav['pages'][int(page)];image=page_image(raw,record);path=alt/'textures'/f'page_{page}.png'
        if verify:
            from PIL import Image
            assert Image.open(path).convert('RGBA').tobytes()==image.tobytes()
        else:image.save(path)
        alt_materials[page]=record['kind']
    save(alt/'definition.json',{'model':explosion_model,'materials':alt_materials})
    telescope=next(e for e in entities if e['class_id']==28)
    telescope['directory']='res://assets/levels/lvl_01/models/25';telescope['boxes']=boxes(25)
    telescope['normal_box']=None
    if telescope['props']['0x18']:
        flags,*v=struct.unpack_from('<I6h',w,exports[telescope['props']['0x18']][0]);telescope['normal_box']={'flags':flags,'min':v[:3],'max':v[3:]}
    flags,*v=struct.unpack_from('<I6h',w,exports[telescope['props']['0x20']][0]);telescope['reverse_box']={'flags':flags,'min':v[:3],'max':v[3:]}
    enum=(decomp/'src/include/sdw_enums.h').read_text()
    fuse_sound=int(re.search(r'SND_SDYMECHE = (0x[0-9a-f]+|\d+)',enum)[1],0)
    ids={18,102,251,fuse_sound}
    ids.update(c['sound_id'] for a in explosion['animations'].values() for c in a['sound_cues'])
    for model in [7,8,34]:
        data=json.loads((out/'models'/str(model)/'worn_data.json').read_text())
        ids.update(c['sound_id'] for a in data['animations'].values() for c in a['sound_cues'])
    snd=(folder/'Lvl-01.SND').read_bytes();at=12;sounds={};(out/'audio').mkdir(exist_ok=True)
    for _ in range(struct.unpack_from('<I',snd,8)[0]):
        identity,size,flags=struct.unpack_from('<III',snd,at)
        if identity in ids:
            path=out/'audio'/f'{identity}.wav';blob=snd[at+12:at+12+size]
            if verify:assert path.read_bytes()==blob
            else:path.write_bytes(blob)
            sounds[str(identity)]='res://'+path.relative_to(ROOT).as_posix()
        at+=12+size
    save(out/'data/mechanics.json',{'mailbox':mailbox,'box':box,'dynamite':dynamite,'telescope':telescope,'sounds':sounds,'fuse_sound':fuse_sound,'dynamite_definition':definition})
    # WAR header 0x83 points into DAV id lists containing actual bitmap records.
    header=next(e&0xffffff for e in t if e>>24==0x83);lists=struct.unpack_from('<4H',w,header);reverse=struct.unpack_from('<H',w,header+8)[0]
    directory=struct.unpack_from('<I',raw,0x14)[0];rec_at=struct.unpack_from('<I',raw,directory+10)[0];p=struct.unpack_from('<I',raw,directory+18)[0];count=struct.unpack_from('<I',raw,p)[0];p+=4;dav_exports={}
    for _ in range(count):
        identity,n=struct.unpack_from('<HH',raw,p);dav_exports[identity]=struct.unpack_from('<%dI'%n,raw,p+4);p+=4+n*4
    scroll=[]
    for i,identity in enumerate(lists):
        if not identity:continue
        for pointer in dav_exports[identity]:
            index=(pointer-rec_at)//10;x,width,y,height,page=dav['rects'][index]
            scroll.append({'list':identity,'bitmap':index,'page':page,'rect':[x,y,width,height],'step':-1 if reverse&(1<<i) else 1})
    save(out/'data/texture_scroll.json',scroll)
    groups,bitmap_groups=read_lists(raw)
    ids=dict((name,int(v)) for name,v in re.findall(r'(DAV_IDI_\w+) = (\d+)',(decomp/'src/include/scenaric_props.h').read_text()))
    sheets={}
    for slug,symbol in [('water','DAV_IDI_IGLTIDE_'),('fuse','DAV_IDI_ITICPTR_')]:
        first=groups[ids[symbol]][0];frames=next(group for group in bitmap_groups if first in group)
        target=ROOT/'assets/effects'/slug;target.mkdir(parents=True,exist_ok=True);paths=[]
        for i,bitmap in enumerate(frames):
            x,width,y,height,page=dav['rects'][bitmap];image=page_image(raw,dav['pages'][page]).crop((x,y,x+width,y+height));path=target/f'frame_{i}.png'
            if verify:
                from PIL import Image
                assert Image.open(path).convert('RGBA').tobytes()==image.tobytes()
            else:image.save(path)
            paths.append('res://'+path.relative_to(ROOT).as_posix())
        sheets[slug]=paths
    mask_dir=ROOT/'assets/ui/telescope';mask_dir.mkdir(parents=True,exist_ok=True)
    for slug,symbol in [('outer','DAV_IDI_I01LVU4_'),('inner','DAV_IDI_I01LVU5_')]:
        bitmap=groups[ids[symbol]][0];x,width,y,height,page=dav['rects'][bitmap];image=page_image(raw,dav['pages'][page]).crop((x,y,x+width,y+height));path=mask_dir/(slug+'.png')
        if verify:
            from PIL import Image
            assert Image.open(path).convert('RGBA').tobytes()==image.tobytes()
        else:image.save(path)
    # Use the base of tall scrolling polygons to place optional spray sprites.
    scenery=json.loads((out/'data/scenery.json').read_text());anchors=[]
    for rec in scroll:
        group=scenery.get(str(rec['page']));points=[];x,ywidth,y,h=rec['rect']
        if group:
            for i in range(0,len(group['verts']),3):
                uv=group['uvs'][i:i+3]
                if all(x/256<=p[0]<=(x+ywidth)/256 and y/256<=p[1]<=(y+h)/256 for p in uv):points.extend(group['verts'][i:i+3])
        if points and max(p[1] for p in points)-min(p[1] for p in points)>2:
            low=min(p[1] for p in points);bottom=[p for p in points if p[1]<low+.5]
            anchors.append([sum(p[0] for p in bottom)/len(bottom),low,-sum(p[2] for p in bottom)/len(bottom)])
    save(out/'data/effects.json',{'sheets':sheets,'water_anchors':anchors})
    # Original note is content of the second delivery box (resource 66).
    raw_mlt=(folder/'Lvl-01.MLT').read_bytes();blocks,lists=struct.unpack_from('<HH',raw_mlt,8);at=16;languages=[]
    for _ in range(blocks):
        bank=[]
        for _ in range(lists):
            count=raw_mlt[at];at+=1;strings=[]
            for _ in range(count):
                end=raw_mlt.index(0,at);strings.append(raw_mlt[at:end].decode('cp1252'));at=end+1
            bank.append(strings)
        languages.append(bank)
    notes={str(e['res']):languages[2][e['class_id']+1][e['props']['0x8']] for e in entities if e['class_id']==78}
    save(out/'data/notes.json',notes)
    print('Mailbox ->',mailbox['item_resources'],'Dynamite fuse',dynamite['props']['0x0'],'ms; scroll',scroll,'sounds',len(sounds),'verified=',verify)
if __name__=='__main__':main()
