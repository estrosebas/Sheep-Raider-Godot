"""Reusable WAR content: cinematics, Daffy lessons, rocks, switches and seesaws."""
import json, re, struct, sys
from pathlib import Path
from extract_shared_items import read_rig, page_image
from extract_run_assets import decode

ROOT = Path(__file__).resolve().parents[1]
STRIDES = [0,8,8,4,2,2,4,2,2]

def main():
    decomp, folder = map(Path,sys.argv[1:3]); sys.path.insert(0,str(decomp/'tools'))
    import level_editor as editor, war_meshes
    slug = folder.name.lower().replace('-','_'); out = ROOT/'assets/levels'/slug
    w = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    dp = next(folder.glob('*.[dD][aA][vV]')); raw = dp.read_bytes(); dav = war_meshes.read_dav(dp); dt = editor.dav_tables(raw)
    t = struct.unpack_from('<%dI'%struct.unpack_from('<I',w,12)[0],w,16)
    es = json.loads((out/'data/entities.json').read_text(encoding='utf8'))
    manifest = json.loads((out/'data/manifest.json').read_text())
    def save(path,data):
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')),encoding='utf8')
    p = next(e&0xffffff for e in t if e>>24==0x82); n = struct.unpack_from('<I',w,p)[0]; p+=4; ex={}
    for _ in range(n):
        i,c = struct.unpack_from('<HH',w,p); ex[i] = struct.unpack_from('<%dI'%c,w,p+4); p+=4+c*4
    def boxes(i):
        return [dict(flags=v[0],min=list(v[1:4]),max=list(v[4:])) for q in ex.get(i,[]) for v in [struct.unpack_from('<I6h',w,q)]]
    def model_boxes(model):
        q = struct.unpack_from('<I',w,(t[model]&0xffffff)+12)[0]
        return [dict(flags=v[0],min=list(v[1:4]),max=list(v[4:])) for i in range(struct.unpack_from('<I',w,q)[0]) for v in [struct.unpack_from('<I6h',w,q+4+i*16)]] if q else []
    def targets(identity): return [e['res'] for e in es if t[e['res']]&0xffffff in ex.get(identity,[])]
    def trajectory(identity):
        if identity not in ex:return None
        q=ex[identity][0]; n=struct.unpack_from('<H',w,q)[0]
        return [list(struct.unpack_from('<3h',w,q+2+i*6)) for i in range(n)]
    def camera(identity):
        if identity not in ex:return None
        focal,*v=struct.unpack_from('<H6h',w,ex[identity][0])
        return dict(focal=focal,rotation=v[:3],eye=v[3:])
    rocks = [{**e,'box':next(b for b in model_boxes(e['model_res']) if not b['flags']&1),'push_zones':boxes(e['props']['0x0'])} for e in es if e['class_id']==16]
    for rock in rocks:
        rock['cine_trigger'] = boxes(rock['props']['0x10'])
        rock['cine_camera_box'] = boxes(rock['props']['0x1c'])
    save(out/'data/interactions.json',{'rocks':rocks})
    switches = {'buttons':[{**e,'directory':manifest['models'][str(e['model_res'])]['directory'],'boxes':model_boxes(e['model_res']), 'targets':targets(e['props']['0x0'])+targets(e['props']['0x4'])} for e in es if e['class_id']==24],
                'lifts':[{**e,'directory':manifest['models'][str(e['model_res'])]['directory'],'boxes':model_boxes(e['model_res'])} for e in es if e['class_id']==36],
                'gates':[{**e,'directory':manifest['models'][str(e['model_res'])]['directory'],'boxes':model_boxes(e['model_res'])} for e in es if e['class_id']==26]}
    save(out/'data/switches.json',switches)
    seesaws = [{**e,'rot_deg':[v*360/4096 for v in e['rot']],'directory':manifest['models'][str(e['model_res'])]['directory'],'boxes':model_boxes(e['model_res']),
                'trajectories':[trajectory(e['props'][k]) for k in ['0x2c','0x30']],
                'launch_cameras':[camera(e['props'][k]) for k in ['0x0','0xc']],
                'ejection_boxes':[(boxes(e['props'][k]) or [None])[0] for k in ['0x18','0x1c']]} for e in es if e['class_id']==15]
    save(out/'data/environment.json',{'water':boxes(54),'seesaws':seesaws,'fly_boxes':boxes(manifest['spawn']['props']['0x4'])})
    # Geometry animations use the original clockwise Rz*Rx*Ry convention.
    for model in manifest['models'].values():
        path = ROOT/model['directory'].replace('res://','')/'worn_data.json'
        data = json.loads(path.read_text())
        if not data.get('static',False): data.update(rotation_order='ZXY',rotation_axis_sign=[1,1,-1]); save(path,data)
    bank = json.loads((ROOT/'assets/localization/levels'/slug/'es.json').read_text(encoding='utf8'))['lists']
    langs = json.loads((ROOT/'assets/localization/manifest.json').read_text(encoding='utf8'))
    voice = lambda identity: langs['languages']['es']['voices'].get(str(identity),'')
    daffy = next((e for e in es if e['class_id']==47),None)
    if daffy:
        props = daffy['props']; hidden = any(e['class_id']==35 for e in es)
        enum = (decomp/'src/include/sdw_enums.h').read_text()
        head_id = int(re.search(r'WAR_IDO_ATEROB01\s*=\s*(\d+)',(decomp/'src/include/scenaric_props.h').read_text())[1])
        head_model = next(i for i,r in enumerate(t) if r&0xffffff==ex[head_id][0])
        heads = {'resource':daffy['res'],'activation':boxes(props['0x0']),'start':boxes(props['0x20']),'goal':boxes(props['0x1c']),
                 'trigger':boxes(props['0xc']),'sheep':boxes(props['0x14']),'cine_ids':[props['0x4'],props['0x8']],'text_base':props['0x18'],
                 'source_level':slug,'variant':'hidden_rocks' if hidden else 'bush','post_rules_reminder':hidden,'line_resources':[e['res'] for e in es if e['class_id']==12 and manifest['models'][str(e['model_res'])]['idle'].startswith('action')],
                 'question':bank[48][10],'answers':[{'choice':bank[48][11+i*2],'text':bank[48][12+i*2],'voice_id':v,'voice_path':voice(v)} for i,v in enumerate([31,32,33] if hidden else [25,23,24])],
                 'phase_voices':{'3':28,'4':29,'5':29,'6':29,'7':30,'8':34,'9':22} if hidden else {'3':16,'4':17,'5':18,'6':19,'7':20,'8':21,'9':22},
                 'burnt':{'text':bank[48][props['0x24']],'voice_path':voice(13)},'head_directory':f'res://assets/levels/{slug}/daffy_head'}
        save(out/'data/daffy.json',heads)
    definitions = {}; cache = {}
    def rig(model,directory,selected=None):
        if str(directory) in cache: return
        res=t[model]; at=res&0xffffff
        if res>>24==68:
            q=struct.unpack_from('<I',w,at+16)[0]; n=struct.unpack_from('<I',w,q)[0]; qs=struct.unpack_from('<%dI'%n,w,q+4)
            names={w[p:p+8].split(b'\0')[0].decode().lower():p for p in qs if p}
            data=read_rig(w,res,editor,war_meshes,dt,{s:s for s in (selected or names)})
            data.update(rotation_order='ZXY',rotation_axis_sign=[1,1,-1])
            if 'start' in data['animations'] and 'head2' in data['animations']:
                data['animations']['head2']=decode(w,names['head2'],len(data['joints']),data['animations']['start']['frames'][-1]['joints'])
                if 'head1' in data['animations']: data['animations']['head1']=decode(w,names['head1'],len(data['joints']),data['animations']['start']['frames'][-1]['joints'])
        else:
            geo=editor.geometry(w,dt,at,False); surfaces={}
            for page,vs in geo['groups'].items():
                div=128 if int(page)>=0 else 255
                surfaces[page]={'verts':[[vs[i]*.01,-vs[i+1]*.01,vs[i+2]*.01] for i in range(0,len(vs),8)],'uvs':[vs[i+3:i+5] for i in range(0,len(vs),8)],'cols':[[c/div for c in vs[i+5:i+8]] for i in range(0,len(vs),8)]}
            data={'static':True,'surfaces':surfaces,'animations':{},'joints':[]}
        save(directory/'worn_data.json',data); mats={}
        for page in data['surfaces']:
            if int(page)<0:continue
            rec=dav['pages'][int(page)]; (directory/'textures').mkdir(exist_ok=True); page_image(raw,rec).save(directory/'textures'/f'page_{page}.png'); mats[page]=rec['kind']
        definitions[str(directory)]={'directory':'res://'+directory.relative_to(ROOT).as_posix(),'materials':mats}; cache[str(directory)]=True
    if daffy: rig(head_model,out/'daffy_head')
    manager = next(e for e in es if e['class_id']==32); triggers=[]
    for i in range(15):
        p=i*24; prop=manager['props']; activation=boxes(prop.get(hex(p+4),0))
        if activation: triggers.append({'cine_id':prop[hex(p)],'activation':activation,'flags':prop.get(hex(p+12),0),'text_index':prop.get(hex(p+20),0)})
    save(out/'data/cinematic_triggers.json',triggers)
    q=next(e&0xffffff for e in t if e>>24==0x85)
    pairs=[struct.unpack_from('<2I',w,q+4+i*8) for i in range(struct.unpack_from('<I',w,q)[0])]
    classless=[i for i,e in enumerate(t) if e>>24==10]; sounds=json.loads((out/'data/ai_audio.json').read_text()); sequences=[]
    for h,q in pairs:
        identity=h&65535; count=(h>>16)&0x7fff; vid=struct.unpack_from('<I',w,q)[0]; q+=4; tracks=[]; actors={}; end=0
        for _ in range(count):
            selector,records,index,_=struct.unpack_from('<BBHI',w,q);q+=8; track={'selector':selector,'index':index,'records':[]}
            for _ in range(records):
                op,n,_=struct.unpack_from('<HHI',w,q);q+=8;keys=[]
                for k in range(n):
                    word=struct.unpack_from('<H',w,q+k*STRIDES[op])[0];v=list(struct.unpack_from('<%dh'%((STRIDES[op]-2)//2),w,q+k*STRIDES[op]+2));time=(word&0x3fff)*.016
                    end=max(end,time);keys.append({'time':time,'mode':word>>14,'value':v})
                track['records'].append({'opcode':op,'keys':keys});q=(q+n*STRIDES[op]+3)&~3
            tracks.append(track)
            if not selector:continue
            resource=index if selector in [1,2] else classless[index]; model=struct.unpack_from('<H',w,t[resource]&0xffffff)[0]; ids={}
            if t[model]>>24==68:
                p=struct.unpack_from('<I',w,(t[model]&0xffffff)+16)[0];n=struct.unpack_from('<I',w,p)[0];p+=4+n*4;n=struct.unpack_from('<I',w,p)[0];mapped=struct.unpack_from('<%dI'%n,w,p+4)
                used={k['value'][0]&0x7fff for r in track['records'] if r['opcode']==3 for k in r['keys']}
                ids={str(i):w[mapped[i]:mapped[i]+8].split(b'\0')[0].decode().lower() for i in used}
            directory=out/'cinematics'/f'model_{model}'; rig(model,directory)
            actors[f'{selector}:{index}']={**definitions[str(directory)],'name':f'Actor_{resource}','resource':resource,'model':model,'animation_ids':ids}
        trigger=next((v for v in triggers if v['cine_id']==identity),None)
        seq={'cine_id':identity,'duration':end,'voice_id':vid,'tracks':tracks,'actors':actors,'sounds':sounds,
             'trigger':(trigger['activation'][0] if trigger else (heads['trigger'][0] if daffy else {'min':[0,0,0],'max':[0,0,0]}))}
        if vid and voice(vid): seq['voice_path']=voice(vid)
        if daffy and identity in heads['cine_ids']: seq['text']=bank[48][heads['text_base']+heads['cine_ids'].index(identity)]
        elif trigger and trigger['flags']&32 and trigger['text_index']<len(bank[33]): seq['text']=bank[33][trigger['text_index']]
        save(out/'cinematics'/f'sequence_{identity}.json',seq); sequences.append({'cine_id':identity,'duration':end,'voice_id':vid,'actors':len(actors)})
    save(out/'data/cinematic_models.json',list(definitions.values()))
    header=next(folder.glob('Cin_*.h'),None)
    symbols=dict((int(value),name) for name,value in re.findall(r'#define\s+CIN_(\w+)\s+(\d+)',header.read_text()) if header) if header else {}
    intro=next((identity for identity,name in symbols.items() if name=='INTRO'),None)
    save(out/'data/import_audit.json',{'level':slug,'entities':len(es),'sequences':sequences,'cinematic_symbols':symbols,'intro_cine_id':intro,
        'tutorial_cine_ids':heads['cine_ids'] if daffy else [],'pending_exclusive_classes':[]})
    from extract_elastic_assets import extract
    extract(folder)
    print(slug,'cinematics',sequences,'triggers',[v['cine_id'] for v in triggers])

if __name__=='__main__':main()
