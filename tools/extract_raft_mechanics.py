"""Export reusable Raft53 rules from native Raft::Update/PostLoadInit.
python tools/extract_raft_mechanics.py assets/levels/lvl_04
Positions, model boxes and RESET remain level data; speeds are native units /100.
"""
import json
import sys
from pathlib import Path

def extract(base):
    base = Path(base)
    entities = json.loads((base/'data/entities.json').read_text(encoding='utf8'))
    models = json.loads((base/'data/manifest.json').read_text(encoding='utf8'))['models']
    solids = json.loads((base/'data/solid_boxes.json').read_text(encoding='utf8'))
    effects = json.loads((base/'data/effects.json').read_text(encoding='utf8'))
    rafts = []
    for entity in entities:
        if entity['class_id'] != 53:
            continue
        rafts.append({**entity, 'directory': models[str(entity['model_res'])]['directory'],
                      'boxes': next(s['boxes'] for s in solids if s['res'] == entity['res']),
                      'reset_position': bool(entity['props']['0x0']),
                      'fan_speed': 3.5, 'fan_acceleration': 2.0, 'fan_deceleration': 2.0,
                      'flow_acceleration': .5, 'flow_deceleration': 1.0,
                      'flow_turn_speed': 15.707963267948966,
                      'rider_tolerance': .1, 'anchor_radius': .5,
                      'wake_frames': effects['sheets']['water']})
    result = {'rafts': rafts, 'source': 'objects/raft.cpp::PostLoadInit/Update/Reset; '
              'objects/fan.cpp::Blow; engine/scenaric.cpp::Zone_GetFlowHeading',
              'units': 'metres, seconds; native X,Y,Z converted by GameSpace'}
    (base/'data/rafts.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf8')
    print('Rafts:', len(rafts))

if __name__ == '__main__':
    extract(sys.argv[1])
