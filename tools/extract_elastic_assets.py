"""elastic / ElasticTree WAR records and Wolf DRAU1 / DRAU2, without guessed bounds."""
import json, struct, sys
from pathlib import Path
from extract_run_assets import decode

ROOT = Path(__file__).resolve().parents[1]

def extract(folder):
    folder = Path(folder)
    slug = folder.name.lower().replace('-', '_')
    out = ROOT/'assets/levels'/slug
    w = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    table = struct.unpack_from('<%dI'%struct.unpack_from('<I', w, 12)[0], w, 16)
    p = next(v & 0xffffff for v in table if v >> 24 == 0x82)
    count = struct.unpack_from('<I', w, p)[0]; p += 4; exports = {}
    for _ in range(count):
        identity, n = struct.unpack_from('<HH', w, p)
        exports[identity] = struct.unpack_from('<%dI'%n, w, p+4); p += 4+n*4
    entities = json.loads((out/'data/entities.json').read_text(encoding='utf8'))
    manifest = json.loads((out/'data/manifest.json').read_text(encoding='utf8'))
    trees, items = [], []
    for e in entities:
        props = e['props']
        if e['class_id'] == 45:
            box = struct.unpack_from('<I6h', w, exports[props['0x4']][0])
            trees.append({**e, 'directory': manifest['models'][str(e['model_res'])]['directory'],
                          'pull_up_point': list(box[1:4]), 'pull_up_box':{'min':list(box[1:4]),'max':list(box[4:])}, 'restriction': props['0x0']})
        if e['class_id'] == 42:
            item = {**e, 'max_length': props['0xc']*.01, 'distance': props['0x0']*.01,
                    'height': props['0x4']*.01, 'speed': props['0x10']*.01}
            if exports.get(props['0x8']):
                cam = struct.unpack_from('<H6h', w, exports[props['0x8']][0])
                item['camera'] = {'focal':cam[0], 'rotation':list(cam[1:4]), 'eye':list(cam[4:])}
            items.append(item)
    (out/'data/elastic.json').write_text(json.dumps({'items':items,'trees':trees},ensure_ascii=False,indent=2),encoding='utf8')
    if not items: return
    model = table[0]&0xffffff
    ap = struct.unpack_from('<I', w, model+16)[0]
    joints = struct.unpack_from('<H', w, model+24)[0]
    n = struct.unpack_from('<I', w, ap)[0]
    names = {w[p:p+8].split(b'\0')[0].decode().lower():p for p in struct.unpack_from('<%dI'%n,w,ap+4) if p}
    bank = {alias:decode(w,names[name],joints) for name,alias in [('drau1','elastic_pull_idle'),('drau2','elastic_pull_move')]}
    (ROOT/'assets/models/ralph_elastic_data.json').write_text(json.dumps(bank,separators=(',',':')))
    print(slug, 'elastic:',len(items),'trees:',len(trees),[(k,v['original_name'],v['duration']) for k,v in bank.items()])

if __name__ == '__main__': extract(sys.argv[1])
