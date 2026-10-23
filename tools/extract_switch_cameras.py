"""Recover FallingGate CamSetup at property 0x8 and map it to its buttons."""
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def main():
    extract(Path(sys.argv[1]))

def extract(folder):
    slug = folder.name.lower().replace('-','_')
    path = ROOT/'assets/levels'/slug/'data/switches.json'
    data = json.loads(path.read_text(encoding='utf8'))
    war = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    table = struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
    at = next(e&0xffffff for e in table if e>>24==0x82)
    count = struct.unpack_from('<I',war,at)[0]
    at += 4
    exports = {}
    for _ in range(count):
        identity,n = struct.unpack_from('<HH',war,at)
        exports[identity] = struct.unpack_from('<%dI'%n,war,at+4)
        at += 4+n*4
    cameras = {}
    for gate in data['gates']:
        identity = gate['props'].get('0x8',0)
        if not identity: continue
        focal,*values = struct.unpack_from('<H6h',war,exports[identity][0])
        camera = dict(export_id=identity,focal=focal,rotation=values[:3],eye=values[3:],
                      cut=bool(gate['props'].get('0x4',0)),keep_while_pressed=gate['props'].get('0x10',0)>=10)
        gate['camera'] = camera
        cameras[gate['res']] = camera
    for button in data['buttons']:
        linked = [cameras[target] for target in button['targets'] if target in cameras]
        if not linked: continue
        assert all(camera==linked[0] for camera in linked), 'Button targets have different camera setups'
        button['camera'] = linked[0]
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(slug,[(button['res'],button['camera']) for button in data['buttons'] if 'camera' in button])

if __name__=='__main__': main()
