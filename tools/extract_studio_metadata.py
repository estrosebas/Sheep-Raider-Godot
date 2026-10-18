"""Native studio counter animation IDs and DoorWorld links (Scene.WAR)."""
import json, struct, sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
w = (Path(sys.argv[1]) / 'Scene.WAR').read_bytes()
t = struct.unpack_from('<%dI' % struct.unpack_from('<I', w, 12)[0], w, 16)
p = next(e & 0xffffff for e in t if e >> 24 == 0x82)
count = struct.unpack_from('<I', w, p)[0]; p += 4; exports = {}
for _ in range(count):
    identity, n = struct.unpack_from('<HH', w, p)
    exports[identity] = struct.unpack_from('<%dI' % n, w, p+4); p += 4+n*4
entities = json.loads((root/'assets/levels/scene/data/entities.json').read_text())
at = struct.unpack_from('<I', w, (t[6] & 0xffffff)+16)[0]
direct = struct.unpack_from('<I', w, at)[0]; at += 4+direct*4
n = struct.unpack_from('<I', w, at)[0]
mapped = struct.unpack_from('<%dI' % n, w, at+4)
counter = {str(i): w[q:q+8].split(b'\0')[0].decode().lower() for i,q in enumerate(mapped) if q}
links = {}
for gate in (e for e in entities if e['class_id'] == 169):
    ptr = exports[gate['props']['0x4']][0]
    door = next(e for e in entities if t[e['res']] & 0xffffff == ptr)
    links[str(gate['res'])] = 'lvl_%02d' % door['props']['0x4']
collection = struct.unpack_from('<I6h',w,exports[563][0])
data = {'source':'SceneSheepPanel::Reset/Update, Crowd::HandleMessage, DoorWorld::PostLoadInit',
        'counter_animation_ids':counter,'world_door_levels':links,
        'sheep_collection_box':{'flags':collection[0],'min':collection[1:4],'max':collection[4:]}}
(root/'assets/levels/scene/data/studio.json').write_text(json.dumps(data, indent=2)+'\n')
print(data)
