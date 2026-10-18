"""Reusable native Sam/checkpoint/mailbox data for imported level foundations."""
import json, struct, sys
from pathlib import Path
from extract_shared_items import read_rig, page_image
from extract_run_assets import decode
ROOT = Path(__file__).resolve().parents[1]

def main():
    decomp, folder = map(Path,sys.argv[1:3])
    sys.path.insert(0,str(decomp/'tools'))
    import level_editor as editor, war_meshes
    slug = folder.name.lower().replace('-','_')
    out = ROOT/'assets/levels'/slug
    w = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    dav_path = next(folder.glob('*.[dD][aA][vV]'))
    raw = dav_path.read_bytes(); dav = war_meshes.read_dav(dav_path)
    tables = editor.dav_tables(raw)
    t = struct.unpack_from('<%dI'%struct.unpack_from('<I',w,12)[0],w,16)
    at = next(e&0xffffff for e in t if e>>24 == 0x82)
    n = struct.unpack_from('<I',w,at)[0]; at += 4; ex = {}
    for _ in range(n):
        identity,count = struct.unpack_from('<HH',w,at)
        ex[identity] = struct.unpack_from('<%dI'%count,w,at+4); at += 4+count*4
    entities = json.loads((out/'data/entities.json').read_text(encoding='utf8'))
    manifest = json.loads((out/'data/manifest.json').read_text(encoding='utf8'))
    def save(path,data):
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')),encoding='utf8')
    def boxes(identity):
        return [dict(flags=struct.unpack_from('<I',w,p)[0],min=list(struct.unpack_from('<3h',w,p+4)),max=list(struct.unpack_from('<3h',w,p+10))) for p in ex.get(identity,[])]
    def model_boxes(model):
        p = struct.unpack_from('<I',w,(t[model]&0xffffff)+12)[0]
        return [dict(flags=struct.unpack_from('<I',w,p+4+i*16)[0],min=list(struct.unpack_from('<3h',w,p+8+i*16)),max=list(struct.unpack_from('<3h',w,p+14+i*16))) for i in range(struct.unpack_from('<I',w,p)[0])] if p else []
    sam = next(e for e in entities if e['class_id']==1); props = sam['props']
    routes = []
    for p in ex.get(52,[]): # WAR_IDO_SAMTRAJ
        count = struct.unpack_from('<H',w,p)[0]
        routes.append([list(struct.unpack_from('<3h',w,p+2+i*6)) for i in range(count)])
    save(out/'data/sam.json',dict(resource=sam['res'],head_speed=props['0x30'],max_angle=props['0x3c'],mode=props['0x40'],knockout_seconds=props['0x20']/1000,
         green=boxes(props['0x2c']),orange=boxes(props['0x44']),authorized=boxes(props['0x4']),hit=boxes(props['0x54']),hiding=boxes(props['0x34']),routes=routes,head_directory=f'res://assets/levels/{slug}/sam_head'))
    body_path = out/'models'/str(sam['model_res'])/'worn_data.json'
    body = json.loads(body_path.read_text(encoding='utf8'))
    at = t[sam['model_res']]&0xffffff; p = struct.unpack_from('<I',w,at+16)[0]
    ptrs = struct.unpack_from('<%dI'%struct.unpack_from('<I',w,p)[0],w,p+4)
    names = {w[q:q+8].split(b'\0')[0].decode().lower():q for q in ptrs if q}
    for name, prior in [('head2','start'),('win','punch7')]:
        body['animations'][name] = decode(w,names[name],len(body['joints']),body['animations'][prior]['frames'][-1]['joints'])
    body.update(rotation_order='ZXY',rotation_axis_sign=[1,1,-1]); save(body_path,body)
    head_model = next(e for e in t if (e&0xffffff)==ex[5][0])
    p = struct.unpack_from('<I',w,(head_model&0xffffff)+16)[0]
    ptrs = struct.unpack_from('<%dI'%struct.unpack_from('<I',w,p)[0],w,p+4)
    names = [w[q:q+8].split(b'\0')[0].decode().lower() for q in ptrs if q]
    head = read_rig(w,head_model,editor,war_meshes,tables,{s:s for s in names})
    base = out/'sam_head'; save(base/'worn_data.json',head)
    materials = {}
    for page in head['surfaces']:
        if int(page)<0: continue
        record = dav['pages'][int(page)]; (base/'textures').mkdir(exist_ok=True)
        page_image(raw,record).save(base/'textures'/f'page_{page}.png'); materials[page] = record['kind']
    save(base/'definition.json',dict(materials=materials))
    cp = next(e for e in entities if e['class_id']==25)['props']; entries=[]
    for i in range(8):
        p=i*16; trigger=cp.get(hex(p),0)
        if not trigger: continue
        yaw=cp.get(hex(p+4),0); yaw=yaw if yaw<0x80000000 else yaw-0x100000000
        entries.append(dict(triggers=boxes(trigger),yaw=int(yaw*2048/180)&4095,wolf=boxes(cp.get(hex(p+12),0)),sheep=boxes(cp.get(hex(p+8),0)),joint=bool(cp['0x80']&(1<<i)),disable_earlier=bool(cp['0x80']&(1<<(i+20)))))
    save(out/'data/checkpoints.json',dict(entries=entries))
    sounds={}; snd=next(folder.glob('*.[sS][nN][dD]')).read_bytes(); p=12
    for _ in range(struct.unpack_from('<I',snd,8)[0]):
        identity,size,flags=struct.unpack_from('<III',snd,p)
        path=out/'audio'/f'{identity}.wav'; path.parent.mkdir(exist_ok=True)
        path.write_bytes(snd[p+12:p+12+size]); sounds[str(identity)]='res://'+path.relative_to(ROOT).as_posix(); p+=12+size
    save(out/'data/ai_audio.json',sounds)
    mailboxes=[]
    for e in entities:
        if e['class_id']!=4: continue
        e=e.copy(); props=e['props']; camera=None
        if props['0x14']:
            p=ex[props['0x14']][0]; focal,*v=struct.unpack_from('<H6h',w,p); camera=dict(focal=focal,rotation=v[:3],eye=v[3:])
        e.update(directory=manifest['models'][str(e['model_res'])]['directory'],boxes=model_boxes(e['model_res']),camera=camera,
                 item_resources=[next(i for i,r in enumerate(t) if (r&0xffffff)==q) for slot in ['0x24','0x28','0x2c','0x30'] for q in ex.get(props[slot],[])])
        e['placed_boxes'] = [{**b,'directory':manifest['models'][str(b['model_res'])]['directory'],'boxes':model_boxes(b['model_res'])} for slot in ['0x0','0x4','0x8','0xc'] for q in ex.get(props[slot],[]) for b in entities if t[b['res']]&0xffffff==q]
        e['rock_resource'] = next((b['res'] for q in ex.get(props['0x18'],[]) for b in entities if t[b['res']]&0xffffff==q),-1)
        mailboxes.append(e)
    placed_box=next((e for e in entities if e['class_id']==14),None)
    box={**placed_box,'directory':manifest['models'][str(placed_box['model_res'])]['directory'],'boxes':model_boxes(placed_box['model_res'])} if placed_box else next(e for e in json.loads((ROOT/'assets/levels/lvl_00/puzzle/definitions.json').read_text(encoding='utf8'))['objects'] if e['class_name']=='DeliveryBox')
    save(out/'data/runtime.json',dict(mailboxes=mailboxes,box=box,sounds=sounds))
    print(slug, 'Sam routes',len(routes),'checkpoints',len(entries),'mailboxes',len(mailboxes))

if __name__=='__main__': main()
