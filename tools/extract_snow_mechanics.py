"""Reusable native snow/ice, detector, buried mine zones and footprint assets."""
import json, struct, sys
from pathlib import Path
from extract_inventory_ui import read_lists
from extract_shared_items import page_image
from extract_run_assets import decode
ROOT = Path(__file__).resolve().parents[1]
def main():
    decomp, folder = map(Path,sys.argv[1:3]); sys.path.insert(0,str(decomp/'tools'))
    import war_meshes
    slug = folder.name.lower().replace('-','_'); base = ROOT/'assets/levels'/slug
    w = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    table = struct.unpack_from('<%dI'%struct.unpack_from('<I',w,12)[0],w,16)
    p = next(v&0xffffff for v in table if v>>24==0x82); n = struct.unpack_from('<I',w,p)[0]; p += 4; exports = {}
    for _ in range(n):
        i,c = struct.unpack_from('<HH',w,p); exports[i] = struct.unpack_from('<%dI'%c,w,p+4); p += 4+c*4
    def boxes(i): return [dict(flags=v[0],min=list(v[1:4]),max=list(v[4:])) for a in exports.get(i,[]) for v in [struct.unpack_from('<I6h',w,a)]]
    entities = json.loads((base/'data/entities.json').read_text(encoding='utf8'))
    manifest = json.loads((base/'data/manifest.json').read_text(encoding='utf8'))
    solids = {e['res']:e['boxes'] for e in json.loads((base/'data/solid_boxes.json').read_text())}
    records = []
    for e in entities:
        if e['class_id'] not in [75,76,77,79,88]: continue
        rec = dict(e,directory=manifest['models'][str(e['model_res'])]['directory'],boxes=solids.get(e['res'],[]))
        if e['class_id'] in [75,79,88]: rec['zones'] = boxes(e['props']['0x0'])
        if e['class_id']==88: rec['safe_zones'] = boxes(e['props']['0xc'])
        records.append(rec)
    dp = next(folder.glob('*.[dD][aA][vV]')); raw = dp.read_bytes(); dav = war_meshes.read_dav(dp); groups,banks = read_lists(raw)
    target = base/'effects/snow'; target.mkdir(parents=True,exist_ok=True)
    def sprite(name,identity,animated=False):
        first = groups[identity][0]; frames = next(b for b in banks if first in b) if animated else [first]
        paths = []
        for i,b in enumerate(frames):
            x,width,y,height,page = dav['rects'][b]; path = target/f'{name}_{i}.png'
            page_image(raw,dav['pages'][page]).crop((x,y,x+width,y+height)).save(path)
            paths.append('res://'+path.relative_to(ROOT).as_posix())
        return paths
    import re
    symbols = dict((name,int(n)) for name,n in re.findall(r'(DAV_IDI_\w+)\s*=\s*(\d+)',(decomp/'src/include/scenaric_props.h').read_text()))
    sprites = dict(prints=sprite('print',symbols['DAV_IDI_IPASNE01'],True),gauge=sprite('gauge',symbols['DAV_IDI_IDTJAUG_'])[0],icon=sprite('detector',symbols['DAV_IDI_IDTICONC'])[0])
    # Ralph's four detector states use their original body animations.
    a=table[0]&0xffffff; p=struct.unpack_from('<I',w,a+16)[0]; joints=struct.unpack_from('<H',w,a+24)[0]
    n=struct.unpack_from('<I',w,p)[0]; names={w[q:q+8].split(b'\0')[0].decode().lower():q for q in struct.unpack_from('<%dI'%n,w,p+4) if q}
    clips={alias:decode(w,names[src],joints) for src,alias in [('detec3','detector_start'),('detec1','detector_idle'),('detec2','detector_walk'),('detec4','detector_end')]}
    (ROOT/'assets/models/ralph_detector_data.json').write_text(json.dumps(clips,separators=(',',':')),encoding='utf8')
    ice_clips={alias:decode(w,names[src],joints) for src,alias in [('icepush1','ice_push_start'),('icepush2','ice_push_end')]}
    (ROOT/'assets/models/ralph_ice_push_data.json').write_text(json.dumps(ice_clips,separators=(',',':')),encoding='utf8')
    data=dict(records=records,print_zones=boxes(123),sprites=sprites,slide_boxes=boxes(104),ice_boxes=boxes(92),
              source='SlidingIceCube, Snowball, IceGround, SnowyGround, GroundMine, MineDetector, Wolf::Fx_Update; native WAR/DAV')
    (base/'data/snow.json').write_text(json.dumps(data,indent=2),encoding='utf8')
    (base/'data/slopes.json').write_text(json.dumps(dict(slide_boxes=data['slide_boxes'],ice_boxes=data['ice_boxes']),indent=2),encoding='utf8')
    for name in ['import_audit','exclusive_mechanics']:
        path = base/'data'/f'{name}.json'
        if not path.exists(): continue
        audit = json.loads(path.read_text(encoding='utf8'))
        if name=='import_audit':
            audit['implemented_exclusive_classes'] = sorted(set(audit.get('implemented_exclusive_classes',[])+[61,75,76,77,79,88]))
            audit['pending_exclusive_classes'] = [175]
        else:
            audit['pending_classes'] = [175]
            audit['pending'] = ['Mirror rendering', 'Exact flat-ice movement profile; downhill zones already use shared slope controller']
        path.write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(slug,'snow records',len(records),'print zones',len(data['print_zones']),'prints',len(sprites['prints']),'slopes',len(data['slide_boxes']),'ice',len(data['ice_boxes']))
if __name__=='__main__': main()
