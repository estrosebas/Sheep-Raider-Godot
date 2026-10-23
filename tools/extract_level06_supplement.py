"""Audit Lv06 mechanics and preserve native tutorial metadata after shared import."""
import json
import struct
import sys
from pathlib import Path
from extract_run_assets import decode

ROOT = Path(__file__).resolve().parents[1]

def main():
    folder = Path(sys.argv[1])
    assert folder.name.lower() == 'lvl-06'
    out = ROOT/'assets/levels/lvl_06'
    def read(name): return json.loads((out/name).read_text(encoding='utf8'))
    def save(name, value): (out/name).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
    war = (folder/'Lvl-06.WAR').read_bytes()
    table = struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
    cursor = next(value&0xffffff for value in table if value>>24==0x82)
    count = struct.unpack_from('<I',war,cursor)[0]; cursor += 4; exports = {}
    for _ in range(count):
        identity, length = struct.unpack_from('<HH',war,cursor)
        exports[identity] = struct.unpack_from('<%dI'%length,war,cursor+4); cursor += 4+length*4
    def boxes(identity):
        return [dict(flags=v[0],min=list(v[1:4]),max=list(v[4:])) for p in exports.get(identity,[]) for v in [struct.unpack_from('<I6h',war,p)]]
    entities = read('data/entities.json'); manifest = read('data/manifest.json')
    solids = read('data/solid_boxes.json')
    def common(entity):
        return {**entity,'directory':manifest['models'][str(entity['model_res'])]['directory'],
                'boxes':next((record['boxes'] for record in solids if record['res']==entity['res']),[])}
    texts = json.loads((ROOT/'assets/localization/levels/lvl_06/es.json').read_text(encoding='utf8'))['lists'][58]
    daffy = next(e for e in entities if e['class_id']==57)
    ice = next(e for e in entities if e['class_id']==60)
    mines = [common(e) for e in entities if e['class_id']==64]
    for mine in mines:
        mine.update(code=mine['props']['0x0'],phase_offset_centiseconds=mine['props']['0x4'],code_length=mine['props']['0x8'],radius_cm=mine['props']['0xc'])
    metadata = dict(daffy={**common(daffy),'text_list':58,'cine_id':1,'cinematic_text':texts[0],
                            'question':texts[1],'choices':[texts[2],texts[4],texts[6]],
                            'answers':[texts[3],texts[5],texts[7]],'punish_text':texts[8],
                            'source':'daffymilitary.cpp::PostLoadInit/HandleMessage/SetState'},
                    ice={**common(ice),'prisoner':daffy['res'],'heat_seconds':1.0,'source':'icecube.cpp::Update'},
                    hairdryer={**common(next(e for e in entities if e['class_id']==58)),
                               'range_m':4.0,'half_angle_degrees':409*360/4096,'heat_message':65,
                               'source':'hairdryer.cpp::Blow'},
                    mines=mines,mine_timing={'cycle_seconds':3.0,'half_cycle_seconds':1.5,
                                             'input_tolerance_seconds':.25,'late_timeout_seconds':.5,
                                             'source':'mine.cpp::DefusableMine::Update'},
                    pending_classes=[57,58,60,74],
                    pending=['DaffyMilitary dialogue and thaw-triggered CIN1','HairDryer heating and original hand animations',
                             'IceCube melting/collision/prisoner release','Native fog-manager adaptation'])
    languages = json.loads((ROOT/'assets/localization/manifest.json').read_text(encoding='utf8'))
    metadata['daffy']['answer_voice_ids'] = [96,97,98]
    metadata['daffy']['answer_voice_paths'] = [languages['languages']['es']['voices'][str(i)] for i in [96,97,98]]
    save('data/exclusive_mechanics.json',metadata)
    telescope = common(next(e for e in entities if e['class_id']==28))
    telescope['normal_box'] = (boxes(telescope['props']['0x18']) or [None])[0]
    telescope['reverse_box'] = (boxes(telescope['props']['0x20']) or [None])[0]
    save('data/telescopes.json',[telescope])
    save('data/preview_actors.json',{'56':{'clip':'stand2','frozen':True},'55':{'clip':'stand1','frozen':True}})
    sequence = read('cinematics/sequence_1.json'); sequence['text'] = texts[0]
    save('cinematics/sequence_1.json',sequence)
    audit = read('data/import_audit.json')
    audit.update(intro_cine_id=0,tutorial_cine_ids=[1],cinematic_symbols={'0':'INTRO','1':'DAFFY_MILITARY','2':'MINE_DEMO'},
                 cinematic_descriptors={'0':{'name':'intro_camera','description':'Entrada original al nivel06'},
                                        '1':{'name':'military_lesson','description':'Lucas explica las minas tras descongelarlo'},
                                        '2':{'name':'mine_demo','description':'Demostracion original de las minas'}},
                 implemented_exclusive_classes=[15,16,24,28,35,38,41,56,65,78],pending_exclusive_classes=[57,58,60,64,74])
    save('data/import_audit.json',audit)
    # HIT must retain PUNCH3 arms during WIN, as on all previous imported Sams.
    sam = next(e for e in entities if e['class_id']==1)
    path = out/'models'/str(sam['model_res'])/'worn_data.json'; rig = json.loads(path.read_text(encoding='utf8'))
    at = table[sam['model_res']]&0xffffff; p = struct.unpack_from('<I',war,at+16)[0]
    n = struct.unpack_from('<I',war,p)[0]
    names = {war[q:q+8].split(b'\0')[0].lower():q for q in struct.unpack_from('<%dI'%n,war,p+4) if q}
    rig['animations']['win_after_hit'] = decode(war,names[b'win'],len(rig['joints']),rig['animations']['punch3']['frames'][-1]['joints'])
    path.write_text(json.dumps(rig,separators=(',',':')),encoding='utf8')
    print('Lv06: Lucas military, 11 mines, ice/secador metadata, telescope, CIN0/1/2 classified; new mechanics pending')

if __name__=='__main__': main()
