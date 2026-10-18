"""Recover Shark50 patrols/volumes, native effects and Wolf EAT from WAR/DAV.
python tools/extract_shark_mechanics.py DECOMP_REPO ORIGINAL_LEVEL_FOLDER
"""
import json
import re
import struct
import sys
from pathlib import Path
from extract_inventory_ui import read_lists
from extract_shared_items import page_image
from extract_run_assets import decode

ROOT = Path(__file__).resolve().parents[1]

def extract(decomp, folder):
    decomp, folder = Path(decomp), Path(folder)
    slug = folder.name.lower().replace('-', '_')
    base = ROOT / 'assets/levels' / slug
    entities = json.loads((base/'data/entities.json').read_text(encoding='utf8'))
    manifest = json.loads((base/'data/manifest.json').read_text(encoding='utf8'))
    solids = json.loads((base/'data/solid_boxes.json').read_text(encoding='utf8'))
    war = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    table = struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
    pointer = next(value&0xffffff for value in table if value>>24==0x82)
    count = struct.unpack_from('<I',war,pointer)[0]; pointer += 4
    exports = {}
    for _ in range(count):
        identity, size = struct.unpack_from('<HH',war,pointer)
        exports[identity] = struct.unpack_from('<%dI'%size,war,pointer+4)
        pointer += 4+size*4
    def boxes(identity):
        return [dict(flags=v[0],min=list(v[1:4]),max=list(v[4:]))
                for at in exports.get(identity,[]) for v in [struct.unpack_from('<I6h',war,at)]]
    def trajectory(identity):
        at = exports[identity][0]; count = struct.unpack_from('<H',war,at)[0]
        return [list(struct.unpack_from('<3h',war,at+2+i*6)) for i in range(count)]
    sharks = []
    for entity in entities:
        if entity['class_id']!=50: continue
        p = entity['props']
        sharks.append({**entity,'directory':manifest['models'][str(entity['model_res'])]['directory'],
                       'boxes':next(entry['boxes'] for entry in solids if entry['res']==entity['res']),
                       'watch_over_cave':bool(p['0x0']),'zones':boxes(p['0x4']),
                       'route':trajectory(p['0x10']), 'detect_height':p['0x8']*.01,
                       'authored_detect_range':p['0xc']*.01, 'detection_distance':96.0,
                       'patrol_speed':3.5,'lunge_speed':9.0,'bite_distance':1.6,'aim_seconds':2.0,
                       'corner_entry_distance':.8,'corner_blend_distance':1.6,
                       'source':'objects/shark.cpp::UpdateWolfChecks/UpdateAi/RunState/SetState/FollowPath'})
    sys.path.insert(0,str(decomp/'tools'))
    import war_meshes
    dav_path = next(folder.glob('*.[dD][aA][vV]'))
    raw = dav_path.read_bytes(); dav = war_meshes.read_dav(dav_path)
    groups, banks = read_lists(raw)
    symbols = dict((name,int(value)) for name,value in re.findall(r'(DAV_IDI_\w+)\s*=\s*(\d+)',(decomp/'src/include/scenaric_props.h').read_text()))
    frames = {}
    for name,symbol in [('bubbles','DAV_IDI_IGLBULL_'),('ripples','DAV_IDI_IGLTIDE_')]:
        first = groups[symbols[symbol]][0]; bitmaps = next(bank for bank in banks if first in bank)
        directory = base/'effects/shark'/name; directory.mkdir(parents=True,exist_ok=True)
        frames[name] = []
        for i,bitmap in enumerate(bitmaps):
            x,w,y,h,page = dav['rects'][bitmap]
            path = directory/f'frame_{i}.png'
            page_image(raw,dav['pages'][page]).crop((x,y,x+w,y+h)).save(path)
            frames[name].append('res://'+path.relative_to(ROOT).as_posix())
    for shark in sharks:
        shark['bubble_frames'] = frames['bubbles']; shark['ripple_frames'] = frames['ripples']
    audio = json.loads((base/'data/ai_audio.json').read_text(encoding='utf8'))
    (base/'data/sharks.json').write_text(json.dumps(dict(sharks=sharks,sounds=audio,scale=.01),ensure_ascii=False,indent=2),encoding='utf8')
    wolf = table[0]&0xffffff; ptr = struct.unpack_from('<I',war,wolf+16)[0]
    pointers = struct.unpack_from('<%dI'%struct.unpack_from('<I',war,ptr)[0],war,ptr+4)
    names = {war[p:p+8].split(b'\0')[0].decode().lower():p for p in pointers if p}
    death = decode(war,names['eat'],struct.unpack_from('<H',war,wolf+24)[0])
    (ROOT/'assets/models/ralph_shark_data.json').write_text(json.dumps({'shark_death':death},separators=(',',':')),encoding='utf8')
    print(slug, 'sharks',[(s['res'],len(s['route'])) for s in sharks], 'Wolf EAT',death['duration'],'sprites',{k:len(v) for k,v in frames.items()})

if __name__=='__main__': extract(*sys.argv[1:3])
