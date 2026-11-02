"""Audit native Lvl-07 exclusive mechanics; preserve data for the next controllers."""
import json, struct, sys
from pathlib import Path
from extract_run_assets import decode

ROOT = Path(__file__).resolve().parents[1]

def main():
    folder = Path(sys.argv[1]); assert folder.name.lower() == 'lvl-07'
    out = ROOT/'assets/levels/lvl_07'
    def read(name): return json.loads((out/name).read_text(encoding='utf8'))
    def save(name, value): (out/name).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
    w = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    table = struct.unpack_from('<%dI'%struct.unpack_from('<I',w,12)[0],w,16)
    p = next(v&0xffffff for v in table if v>>24==0x82)
    n = struct.unpack_from('<I',w,p)[0]; p += 4; exports = {}
    for _ in range(n):
        identity, count = struct.unpack_from('<HH',w,p)
        exports[identity] = struct.unpack_from('<%dI'%count,w,p+4); p += 4+count*4
    def boxes(identity):
        return [dict(flags=v[0], min=list(v[1:4]), max=list(v[4:])) for a in exports.get(identity,[]) for v in [struct.unpack_from('<I6h',w,a)]]
    entities = read('data/entities.json'); manifest = read('data/manifest.json')
    solids = {e['res']:e['boxes'] for e in read('data/solid_boxes.json')}
    records = []
    for e in entities:
        if e['class_id'] not in [61,75,76,77,79,88,175]: continue
        record = {**e, 'directory':manifest['models'][str(e['model_res'])]['directory'], 'boxes':solids.get(e['res'],[])}
        if e['class_id'] in [75,79,88]: record['zones'] = boxes(e['props']['0x0'])
        records.append(record)
    save('data/exclusive_mechanics.json',dict(records=records,
         pending_classes=[61,75,76,77,79,88,175],
         pending=['Mine detector and buried minefield', 'Growing pushable snowball', 'Snow footprints and slippery ground', 'Sliding ice cubes', 'Mirror rendering'],
         source='objects/minedetector.cpp, mine.cpp, snowball.cpp, snowyground.cpp, iceground.cpp, slidingicecube.cpp, mirror.cpp'))
    audit = read('data/import_audit.json')
    audit.update(intro_cine_id=0, tutorial_cine_ids=[],
        cinematic_descriptors={'0':{'name':'intro_camera','description':'Recorrido de entrada y demostracion original del campo de minas'}},
        implemented_exclusive_classes=[24,26,38,64,78,80], pending_exclusive_classes=[61,75,76,77,79,88,175],
        daffy_present=False)
    save('data/import_audit.json',audit)
    # Sam's WIN delta animation must start from the end of PUNCH3.
    sam = next(e for e in entities if e['class_id']==1)
    path = out/'models'/str(sam['model_res'])/'worn_data.json'
    rig = json.loads(path.read_text(encoding='utf8'))
    a = table[sam['model_res']]&0xffffff; p = struct.unpack_from('<I',w,a+16)[0]
    n = struct.unpack_from('<I',w,p)[0]
    names = {w[q:q+8].split(b'\0')[0].lower():q for q in struct.unpack_from('<%dI'%n,w,p+4) if q}
    rig['animations']['win_after_hit'] = decode(w,names[b'win'],len(rig['joints']),rig['animations']['punch3']['frames'][-1]['joints'])
    path.write_text(json.dumps(rig,separators=(',',':')),encoding='utf8')
    print('Lv07: native intro, 4 reusable mines; exclusive mechanics catalogued for implementation')

if __name__ == '__main__': main()
