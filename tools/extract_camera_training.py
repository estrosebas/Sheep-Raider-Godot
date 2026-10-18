"""Original Spanish MLT/BSV voices and first four DaffyTrainingLevel help paths."""
import json,re,struct,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent

def voice_name(identity, names):
    # StreamPlayer::PlayVoice 0x563940: clipNames[currentClip - 1].
    # Music uses another lookup; SND effects are IDs, not this voice bank.
    assert 1 <= identity <= len(names)
    return names[identity-1]

def main():
    game=Path(sys.argv[1])
    folder=game/'Levels/Lvl-00'
    verify='--verify' in sys.argv
    raw=(folder/'Lvl-00.MLT').read_bytes()
    blocks,lists=struct.unpack_from('<HH',raw,8)
    at=16
    languages=[]
    for _ in range(blocks):
        bank=[]
        for _ in range(lists):
            count=raw[at];at+=1
            strings=[]
            for _ in range(count):
                end=raw.index(0,at)
                strings.append(raw[at:end].decode('cp1252'));at=end+1
            bank.append(strings)
        languages.append(bank)
    assert at==len(raw)
    bank=languages[2] # Mlt_MapLanguageToBlock: Spanish -> block 2.
    bsv=(game/'References/MusicVoice.BSV').read_bytes()
    assert bsv.startswith(b'BSV_FILEV2.5')
    at=12;names=[]
    for _ in range(116):
        count,=struct.unpack_from('<I',bsv,at);at+=4
        names.append(bsv[at:at+count].split(b'\0')[0].decode());at+=count
    war=(folder/'Lvl-00.WAR').read_bytes()
    table=struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
    at=next(e&0xffffff for e in table if e>>24==0x82)
    count,=struct.unpack_from('<I',war,at);at+=4;exports={}
    for _ in range(count):
        identity,n=struct.unpack_from('<HH',war,at)
        exports[identity]=struct.unpack_from('<%dI'%n,war,at+4);at+=4+n*4
    entities=json.loads((ROOT/'assets/levels/lvl_00/data/entities.json').read_text())
    actor=next(e for e in entities if e['class_name']=='DaffyTrainingLevel')
    props=actor['props']
    assert voice_name(80,names)=='txt_lvl_001.wav'
    assert voice_name(81,names)=='txt_lvl_0010.wav'
    assert voice_name(88,names)=='txt_lvl_002.wav'
    assert voice_name(90,names)=='txt_lvl_004.wav'
    output=ROOT/'assets/cinematics/camera_training';output.mkdir(parents=True,exist_ok=True)
    (output/'voices').mkdir(exist_ok=True)
    voices={}
    for identity in range(80,96):
        name=voice_name(identity,names)
        source=game/'Voices/spanish'/name
        target=output/'voices'/name
        if verify:
            assert target.read_bytes()==source.read_bytes()
        else:
            target.write_bytes(source.read_bytes())
        voices[str(identity)]={'name':name,'bank_index':identity-1,'path':'res://'+target.relative_to(ROOT).as_posix()}
    slots=[]
    offsets=[(0x90,8,0xe0,0x130,0x180),(0x8c,4,0xdc,0x12c,0x17c),
             (0x88,0,0xd8,0x128,0x178),(0x94,12,0xe4,0x134,0x184)]
    offsets += [(0x94+4*i,12+4*i,0xe4+4*i,0x134+4*i,0x184+4*i) for i in range(1,17)]
    for index,(text,box,path,gait,voice) in enumerate(offsets):
        text_id=props[hex(text)];path_id=props[hex(path)];box_id=props[hex(box)]
        p=exports[path_id][0];n,=struct.unpack_from('<H',war,p)
        points=[list(struct.unpack_from('<3h',war,p+2+i*6)) for i in range(n)]
        box_record=None
        if box_id:
            p=exports[box_id][0];flags,*corners=struct.unpack_from('<I6h',war,p)
            box_record={'flags':flags,'min':corners[:3],'max':corners[3:]}
        slots.append({'index':index,'text_id':text_id,'original_text':bank[actor['class_id']+1][text_id],
            'voice_id':props[hex(voice)],'gait':props[hex(gait)],'path_export':path_id,'points':points,
            'box_export':box_id,'box':box_record})
    manager=next(e for e in entities if e['class_name']=='CinematicsManager')
    catalog=[]
    for index in range(20):
        text_offset=[0x90,0x8c,0x88][index] if index<3 else 0x94+4*(index-3)
        voice_offset=[0x180,0x17c,0x178][index] if index<3 else 0x184+4*(index-3)
        text_id=props[hex(text_offset)];identity=props[hex(voice_offset)]
        catalog.append({'slot':index,'text_id':text_id,'original_text':bank[actor['class_id']+1][text_id],
            'voice_id':identity,'voice_name':voice_name(identity,names) if identity else None})
    data={'source':'DaffyTrainingLevel::Update / MoveTo / SetHelpLine', 'focus_seconds':1.0,
        'follow_text':bank[manager['class_id']+1][1], 'voices':voices,'slots':slots,
        'voice_lookup':'StreamPlayer::PlayVoice: clipNames[currentClip - 1]',
        'tutorial_voice_catalog':catalog}
    def box(identity):
        p=exports[identity][0];flags,*corners=struct.unpack_from('<I6h',war,p)
        return {'flags':flags,'min':corners[:3],'max':corners[3:]}
    data['race']={'duration':props['0x84']*0.1,'start':box(props['0x7c']),'finish':box(props['0x80']),
                  'retry_text':bank[actor['class_id']+1][10],'retry_voice':82}
    data['flight_joke']={'text':bank[actor['class_id']+1][7],'voice_id':props['0x74']}
    runner=next(e for e in entities if e['class_name']=='bipbip')
    def path(identity):
        p=exports[identity][0];n,=struct.unpack_from('<H',war,p)
        return [list(struct.unpack_from('<3h',war,p+2+i*6)) for i in range(n)]
    rp=runner['props']
    data['roadrunner']={'resource':runner['res'],'model':runner['model_res'],
        'trigger_export':rp['0x0'],'trigger':box(rp['0x0']),
        'speed_one':rp['0x4']*.01,'speed_two':rp['0x8']*.01,
        'road_export':rp['0x10'],'road':path(rp['0x10']),
        'wall_export':rp['0xc'],'wall':path(rp['0xc'])}
    target=output/'lessons.json'
    if verify:
        assert json.loads(target.read_text(encoding='utf-8'))==data
    else:
        target.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Original camera lessons:',len(slots),'paths;',len(voices),'Spanish voices; verified=',verify)

if __name__=='__main__':
    main()
