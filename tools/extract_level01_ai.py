"""Recover Lvl-01 actor rigs, AI zones, checkpoints, CIN tracks and Spanish dialogue."""
import json, struct, sys, re
from pathlib import Path
from extract_shared_items import read_rig, page_image
from extract_inventory_ui import read_lists

ROOT = Path(__file__).resolve().parent.parent
STRIDES = [0,8,8,4,2,2,4,2,2]

def decode_text(value):
    # A few Spanish strings mix UTF-8 accent pairs into their CP1252 payload.
    text = value.decode('cp1252')
    return re.sub(r'[\u00c2\u00c3][\u0080-\u00bf]', lambda m: m[0].encode('cp1252').decode('utf8'), text)

def main():
    decomp, game = map(Path, sys.argv[1:3])
    verify = '--verify' in sys.argv
    sys.path.insert(0, str(decomp/'tools'))
    import level_editor as editor, war_meshes
    folder = game/'Levels/Lvl-01'
    out = ROOT/'assets/levels/lvl_01'
    cine = out/'cinematics'
    w = (folder/'Lvl-01.WAR').read_bytes()
    raw = (folder/'Lvl-01.DAV').read_bytes()
    dt = editor.dav_tables(raw)
    dav = war_meshes.read_dav(folder/'Lvl-01.DAV')
    t = struct.unpack_from('<%dI' % struct.unpack_from('<I',w,12)[0],w,16)
    def save(p, data):
        p.parent.mkdir(parents=True,exist_ok=True)
        if verify: assert json.loads(p.read_text(encoding='utf8')) == data, p
        else: p.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')),encoding='utf8')
    def blob(p, data):
        p.parent.mkdir(parents=True,exist_ok=True)
        if verify: assert p.read_bytes() == data, p
        else: p.write_bytes(data)
    def png(p, img):
        p.parent.mkdir(parents=True,exist_ok=True)
        if verify:
            from PIL import Image
            assert Image.open(p).convert('RGBA').tobytes() == img.tobytes(), p
        else: img.save(p)
    p = next(e&0xffffff for e in t if e>>24 == 0x82)
    n = struct.unpack_from('<I',w,p)[0]
    p += 4
    ex = {}
    for _ in range(n):
        i,c = struct.unpack_from('<HH',w,p)
        ex[i] = struct.unpack_from('<%dI'%c,w,p+4)
        p += 4+c*4
    def boxes(i):
        result = []
        for p in ex.get(i,[]):
            flags,*v = struct.unpack_from('<I6h',w,p)
            result.append({'flags':flags,'min':v[:3],'max':v[3:]})
        return result
    es = json.loads((out/'data/entities.json').read_text(encoding='utf8'))
    sam = next(e for e in es if e['class_id'] == 1)
    props = sam['props']
    routes = []
    for p in ex[52]:
        n = struct.unpack_from('<H',w,p)[0]
        routes.append([list(struct.unpack_from('<3h',w,p+2+i*6)) for i in range(n)])
    save(out/'data/sam.json',{'resource':sam['res'],'head_speed':props['0x30'],'max_angle':props['0x3c'],'mode':props['0x40'],'knockout_seconds':props['0x20']/1000,
         'green':boxes(props['0x2c']),'orange':boxes(props['0x44']),'authorized':boxes(props['0x4']),'hit':boxes(props['0x54']),'hiding':boxes(props['0x34']),'routes':routes,'head_directory':'res://assets/levels/lvl_01/sam_head'})
    cp = next(e for e in es if e['class_id'] == 25)['props']
    entries = []
    for i in range(8):
        base = i*16
        trigger = cp.get(hex(base),0)
        if not trigger: continue
        yaw = cp.get(hex(base+4),0)
        yaw = yaw if yaw < 0x80000000 else yaw-0x100000000
        entries.append({'triggers':boxes(trigger),'yaw':int(yaw*2048/180)&4095,'wolf':boxes(cp.get(hex(base+12),0)),'sheep':boxes(cp.get(hex(base+8),0)),
                        'joint':bool(cp['0x80']&(1<<i)),'disable_earlier':bool(cp['0x80']&(1<<(i+20)))})
    save(out/'data/checkpoints.json',{'entries':entries})
    inv = {e&0xffffff:i for i,e in enumerate(t)}
    head_model = inv[ex[5][0]]
    rig_cache = {}
    def rig(model, directory, selected=None, defer_save=False):
        at = t[model]&0xffffff
        p = struct.unpack_from('<I',w,at+16)[0]
        if t[model]>>24 == 0x44:
            n = struct.unpack_from('<I',w,p)[0]
            ptrs = struct.unpack_from('<%dI'%n,w,p+4)
            names = {w[q:q+8].split(b'\0')[0].decode().lower() for q in ptrs if q}
            data = read_rig(w,t[model],editor,war_meshes,dt,{s:s for s in (selected or names)})
        else:
            g = editor.geometry(w,dt,at,False)
            surfaces = {}
            for page,vs in g['groups'].items():
                div = 128 if int(page) >= 0 else 255
                surfaces[page] = {'verts':[[vs[i]*.01,-vs[i+1]*.01,vs[i+2]*.01] for i in range(0,len(vs),8)],'uvs':[vs[i+3:i+5] for i in range(0,len(vs),8)],'cols':[[c/div for c in vs[i+5:i+8]] for i in range(0,len(vs),8)]}
            data = {'static':True,'surfaces':surfaces,'animations':{},'joints':[]}
        if model == sam['model_res']:
            # Animation keys are CLOCKWISE (load_warmeshes.cpp), unlike
            # joint overrides. Mat44 row vectors become Rz * Rx * Ry;
            # reflect native Y and undo decode()'s extra Z sign.
            data['rotation_order'] = 'ZXY'
            data['rotation_axis_sign'] = [1, 1, -1]
        if directory.parent == cine:
            if directory in rig_cache: data['animations'] = {**rig_cache[directory]['animations'],**data['animations']}
            rig_cache[directory] = data
        elif not defer_save: save(directory/'worn_data.json',data)
        materials = {}
        for page in data['surfaces']:
            if int(page) < 0: continue
            record = dav['pages'][int(page)]
            png(directory/'textures'/f'page_{page}.png',page_image(raw,record))
            materials[page] = record['kind']
        return data,materials
    # HEAD2 omits body joints: preserve START's final body pose.
    sam_model = sam['model_res']
    sam_dir = out/'models'/str(sam_model)
    body,materials = rig(sam_model,sam_dir,defer_save=True)
    from extract_run_assets import decode
    at = t[sam_model]&0xffffff
    p = struct.unpack_from('<I',w,at+16)[0]
    ptrs = struct.unpack_from('<%dI'%struct.unpack_from('<I',w,p)[0],w,p+4)
    head2 = next(q for q in ptrs if q and w[q:q+8].split(b'\0')[0].lower() == b'head2')
    body['animations']['head2'] = decode(w,head2,len(body['joints']),body['animations']['start']['frames'][-1]['joints'])
    win = next(q for q in ptrs if q and w[q:q+8].split(b'\0')[0].lower() == b'win')
    body['animations']['win'] = decode(w,win,len(body['joints']),body['animations']['punch7']['frames'][-1]['joints'])
    save(sam_dir/'worn_data.json',body)
    save(sam_dir/'definition.json',{'materials':materials,'model':sam_model})
    head,materials = rig(head_model,out/'sam_head')
    save(out/'sam_head/definition.json',{'materials':materials,'model':head_model})
    if ex.get(82):
        sleeping,materials = rig(inv[ex[82][0]],out/'sheep_sleep')
        save(out/'sheep_sleep/definition.json',{'materials':materials,'model':inv[ex[82][0]]})
    groups,_ = read_lists(raw)
    props_header = (decomp/'src/include/scenaric_props.h').read_text(encoding='utf8')
    crayon = int(re.search(r'DAV_IDI_IGLCRAI1\s*=\s*(\d+)',props_header)[1])
    if crayon:
        bitmap = groups[crayon][0]
        x,width,y,height,page = dav['rects'][bitmap]
        png(out/'sam_head/border.png',page_image(raw,dav['pages'][page]).crop((x,y,x+width,y+height)))
    m = (folder/'Lvl-01.MLT').read_bytes()
    blocks,lists = struct.unpack_from('<HH',m,8)
    p = 16
    langs = []
    for _ in range(blocks):
        bank = []
        for _ in range(lists):
            n = m[p]
            p += 1
            strings = []
            for _ in range(n):
                q = m.index(0,p)
                strings.append(decode_text(m[p:q]))
                p = q+1
            bank.append(strings)
        langs.append(bank)
    bank = langs[2]
    b = (game/'References/MusicVoice.BSV').read_bytes()
    p = 12
    names = []
    for _ in range(116):
        n = struct.unpack_from('<I',b,p)[0]
        p += 4
        names.append(b[p:p+n].split(b'\0')[0].decode())
        p += n
    voices = {}
    def voice(i):
        if not i: return None
        name = names[i-1]
        dest = out/'voices'/name
        blob(dest,(game/'Voices/spanish'/name).read_bytes())
        voices[str(i)] = 'res://'+dest.relative_to(ROOT).as_posix()
        return voices[str(i)]
    daffy = next(e for e in es if e['class_id'] == 33)
    dp = daffy['props']
    answers = [{'choice':bank[34][dp['0x4']+i],'text':bank[34][dp['0x0']+i],'voice_id':dp[hex(0x1c+4*i)],'voice_path':voice(dp[hex(0x1c+4*i)])} for i in range(dp['0xc'])]
    save(out/'data/daffy.json',{'resource':daffy['res'],'question':bank[34][dp['0x10']],'answers':answers,'burnt':{'text':bank[34][dp['0x14']],'voice_path':voice(dp['0x30'])}})
    porky = next(e for e in es if e['class_id'] == 30)
    pp = porky['props']
    pb = bank[31]
    pa = [{'choice':pb[pp['0xc']+i],'text':pb[pp['0x4']+i],'voice_id':59+i,'voice_path':voice(59+i)} for i in range(3)]
    save(out/'data/porky.json',{'resource':porky['res'],'question':pb[pp['0x8']],'answers':pa,'burnt':{'text':pb[9],'voice_id':65,'voice_path':voice(65)},
         'activation':boxes(pp['0x0']),'sheep_box':boxes(pp['0x28']),'cine_without':pp['0x14'],'cine_with':pp['0x1c'],'text_without':pb[pp['0x18']],
         'text_with':pb[pp['0x20']],'salad_delay_ms':pp['0x24']})
    for model in [5,17,37]:
        _,materials = rig(model,out/'models'/str(model))
        save(out/f'models/{model}/definition.json',{'materials':materials,'model':model})
    rig(16,out/'models/16')
    p = next(e&0xffffff for e in t if e>>24 == 0x85)
    pairs = [struct.unpack_from('<2I',w,p+4+i*8) for i in range(struct.unpack_from('<I',w,p)[0])]
    classless = [i for i,e in enumerate(t) if e>>24 == 10]
    sequences = []
    sound_ids = {61,274,248,249,250}
    for h,p in pairs:
        identity = h&65535
        count = (h>>16)&0x7fff
        voice_id = struct.unpack_from('<I',w,p)[0]
        p += 4
        tracks,end,actors = [],0,{}
        for _ in range(count):
            selector,records,index,_ = struct.unpack_from('<BBHI',w,p)
            p += 8
            track = {'selector':selector,'index':index,'records':[]}
            for _ in range(records):
                op,n,_ = struct.unpack_from('<HHI',w,p)
                p += 8
                keys = []
                for i in range(n):
                    word = struct.unpack_from('<H',w,p+i*STRIDES[op])[0]
                    v = list(struct.unpack_from('<%dh'%((STRIDES[op]-2)//2),w,p+i*STRIDES[op]+2))
                    time = (word&0x3fff)*.016
                    end = max(end,time)
                    keys.append({'time':time,'mode':word>>14,'value':v})
                track['records'].append({'opcode':op,'keys':keys})
                p = (p+n*STRIDES[op]+3)&~3
            tracks.append(track)
            if not selector: continue
            resource = index if selector in [1,2] else classless[index]
            model = struct.unpack_from('<H',w,t[resource]&0xffffff)[0]
            mp = struct.unpack_from('<I',w,(t[model]&0xffffff)+16)[0]
            ids = {}
            if t[model]>>24 == 0x44:
                n = struct.unpack_from('<I',w,mp)[0]
                mp += 4+n*4
                n = struct.unpack_from('<I',w,mp)[0]
                mapped = struct.unpack_from('<%dI'%n,w,mp+4)
                used = {k['value'][0]&0x7fff for r in track['records'] if r['opcode'] == 3 for k in r['keys']}
                ids = {str(i):w[mapped[i]:mapped[i]+8].split(b'\0')[0].decode().lower() for i in used}
            directory = cine/f'model_{model}'
            data,mats = rig(model,directory,set(ids.values()) or None)
            sound_ids.update(c['sound_id'] for a in data['animations'].values() for c in a['sound_cues'])
            actors[f'{selector}:{index}'] = {'name':f'Actor_{resource}','resource':resource,'model':model,'directory':'res://'+directory.relative_to(ROOT).as_posix(),'materials':mats,'animation_ids':ids}
        seq = {'cine_id':identity,'duration':end,'voice_id':voice_id,'tracks':tracks,'actors':actors,'sounds':{},'trigger':boxes(580)[0]}
        if identity == 4: seq['text'] = bank[33][1]
        if identity in [pp['0x14'],pp['0x1c']]:
            seq['text'] = pb[pp['0x18'] if identity == pp['0x14'] else pp['0x20']]
            seq['trigger'] = boxes(pp['0x0'])[0]
        if voice_id: seq['voice_path'] = voice(voice_id)
        sequences.append(seq)
    for directory,data in rig_cache.items(): save(directory/'worn_data.json',data)
    for model in [1,2]:
        data = json.loads((out/f'models/{model}/worn_data.json').read_text(encoding='utf8'))
        sound_ids.update(c['sound_id'] for a in data['animations'].values() for c in a['sound_cues'])
    snd = (folder/'Lvl-01.SND').read_bytes()
    p,sounds = 12,{}
    for _ in range(struct.unpack_from('<I',snd,8)[0]):
        i,n,f = struct.unpack_from('<III',snd,p)
        if i in sound_ids:
            dest = out/'audio'/f'{i}.wav'
            blob(dest,snd[p+12:p+12+n])
            sounds[str(i)] = 'res://'+dest.relative_to(ROOT).as_posix()
        p += 12+n
    for seq in sequences:
        seq['sounds'] = sounds
        save(cine/f"sequence_{seq['cine_id']}.json",seq)
    save(out/'data/ai_audio.json',sounds)
    blob(ROOT/'assets/audio/music/trip_v1.wav',(game/'Musics/Trip_v1.wav').read_bytes())
    print('Sam routes:',len(routes),'CIN:',[(s['cine_id'],s['duration'],s['voice_id']) for s in sequences],'Porky answers:',len(pa))

if __name__ == '__main__': main()
