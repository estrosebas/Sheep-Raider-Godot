"""Recover seesaw collision, authored launches, Rock rigs and button/gate assets."""
import copy,json,struct,sys,math
from collections import Counter
from pathlib import Path
from extract_shared_items import read_rig,page_image
ROOT=Path(__file__).resolve().parent.parent
def main():
    decomp,folder=map(Path,sys.argv[1:3]);verify='--verify' in sys.argv
    sys.path.insert(0,str(decomp/'tools'))
    import level_editor as editor,war_meshes
    def save(path,data):
        if verify: assert json.loads(path.read_text(encoding='utf-8'))==data,path
        else:path.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
    war=(folder/'Lvl-00.WAR').read_bytes();raw=(folder/'Lvl-00.DAV').read_bytes();dav=war_meshes.read_dav(folder/'Lvl-00.DAV');dt=editor.dav_tables(raw)
    table=struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
    at=next(e&0xffffff for e in table if e>>24==0x82);count,=struct.unpack_from('<I',war,at);at+=4;exports={}
    for _ in range(count):
        identity,n=struct.unpack_from('<HH',war,at);exports[identity]=struct.unpack_from('<%dI'%n,war,at+4);at+=4+n*4
    entities=json.loads((ROOT/'assets/levels/lvl_00/data/entities.json').read_text())
    entities += [{'class_name':'DeliveryBox','class_id':2,'res':-1,'model_res':3,'pos':[0,0,0],'rot_deg':[0,0,0],'props':{}}, {'class_name':'RocketRig','class_id':10,'res':-2,'model_res':5,'pos':[0,0,0],'rot_deg':[0,0,0],'props':{}}, {'class_name':'SheepRig','class_id':11,'res':-3,'model_res':2,'pos':[0,0,0],'rot_deg':[0,0,0],'props':{}}]
    # Always reconstruct from the previous source split; repeatable even after regeneration.
    static=copy.deepcopy(json.loads((ROOT/'assets/levels/lvl_00/data/level_static_data.json').read_text()))
    prior=ROOT/'assets/levels/lvl_00/data/puzzle_static_data.json'
    output=ROOT/'assets/levels/lvl_00/puzzle';output.mkdir(exist_ok=True)
    definitions=[];sound_ids={54,262,264}
    def trajectory(identity):
        if not identity:return None
        p=exports[identity][0];n,=struct.unpack_from('<H',war,p)
        return [list(struct.unpack_from('<3h',war,p+2+6*i)) for i in range(n)]
    def box_export(identity):
        if not identity:return None
        flags,*v=struct.unpack_from('<I6h',war,exports[identity][0]);return {'flags':flags,'min':v[:3],'max':v[3:]}
    def camera(identity):
        if not identity:return None
        focal,*v=struct.unpack_from('<H6h',war,exports[identity][0]);return {'focal':focal,'rotation':v[:3],'eye':v[3:]}
    def key(vs,uvs):return tuple(round(c,4) for v in vs for c in v)+tuple(round(c,5) for u in uvs for c in u)
    for entity in entities:
        if entity['class_name'] not in ['seesaw','Rock','SensibleButton','FallingGate','Mailbox','DeliveryBox','RocketRig','SheepRig']:continue
        model=table[entity['model_res']];at=model&0xffffff;geometry=editor.geometry(war,dt,at,model>>24==0x44)
        directory=(ROOT/'assets/items'/ {2:'sheep',3:'delivery_box',4:'mailbox',5:'rocket'}[entity['model_res']]) if entity['model_res'] in [2,3,4,5] else output/str(entity['model_res']);directory.mkdir(exist_ok=True)
        # Keep every animation's original name, independent of cinematic subsets.
        if model>>24==0x44:
            animation_at,=struct.unpack_from('<I',war,at+16)
            n,=struct.unpack_from('<I',war,animation_at)
            pointers=struct.unpack_from('<%dI'%n,war,animation_at+4)
            names={war[p:p+8].split(b'\0')[0].decode().lower() for p in pointers if p}
            rig=read_rig(war,model,editor,war_meshes,dt,{name:name for name in names})
        else:
            surfaces={}
            for page,values in geometry['groups'].items():
                divisor=128 if int(page)>=0 else 255
                surfaces[page]={'verts':[[v*.01,-values[i+1]*.01,values[i+2]*.01] for i,v in enumerate(values) if i%8==0],
                                'uvs':[values[i+3:i+5] for i in range(0,len(values),8)],
                                'cols':[[c/divisor for c in values[i+5:i+8]] for i in range(0,len(values),8)]}
            rig={'static':True,'surfaces':surfaces,'animations':{},'joints':[]}
        save(directory/'worn_data.json',rig)
        materials={};(directory/'textures').mkdir(exist_ok=True)
        for page in rig['surfaces']:
            if int(page)>=0:
                record=dav['pages'][int(page)];image=page_image(raw,record);path=directory/'textures'/f'page_{page}.png'
                if verify:
                    from PIL import Image
                    assert Image.open(path).convert('RGBA').tobytes()==image.tobytes()
                else:image.save(path)
                materials[page]=record['kind']
        for animation in rig['animations'].values():sound_ids.update(c['sound_id'] for c in animation['sound_cues'])
        pointer,=struct.unpack_from('<I',war,at+12);boxes=[]
        if pointer:
            for i in range(struct.unpack_from('<I',war,pointer)[0]):
                flags,*v=struct.unpack_from('<I6h',war,pointer+4+i*16);boxes.append({'flags':flags,'min':v[:3],'max':v[3:]})
        # The merged export used the unrotated original model; inspect by matching.
        removed=0
        for page,values in (geometry['groups'].items() if entity['res'] >= 0 else []):
            positions=[[round(values[i]*.01+entity['pos'][0],4),round(-values[i+1]*.01+entity['pos'][1],4),round(values[i+2]*.01+entity['pos'][2],4)] for i in range(0,len(values),8)]
            yaw=math.radians(entity['rot_deg'][1]);c,s=math.cos(yaw),math.sin(yaw)
            if yaw:
                # Exported entity headings are rounded; WAR preserves exact 4096-angle units.
                rotation=round(entity['rot_deg'][1]*4096/360)*math.tau/4096;c,s=math.cos(rotation),math.sin(rotation)
                positions=[[round(values[i]*.01*c+values[i+2]*.01*s+entity['pos'][0],4),round(-values[i+1]*.01+entity['pos'][1],4),round(-values[i]*.01*s+values[i+2]*.01*c+entity['pos'][2],4)] for i in range(0,len(values),8)]
            uvs=[values[i+3:i+5] for i in range(0,len(values),8)]
            wanted=Counter(key(positions[i:i+3],uvs[i:i+3]) for i in range(0,len(positions),3))
            group=static[page];keep={name:[] for name in ['verts','uvs','cols']}
            for i in range(0,len(group['verts']),3):
                triangle=key(group['verts'][i:i+3],group['uvs'][i:i+3])
                if wanted[triangle]:wanted[triangle]-=1;removed+=3
                else:
                    for name in keep:keep[name].extend(group[name][i:i+3])
            assert not any(wanted.values()),('Missing merged geometry',entity['res'],sum(wanted.values()))
            group.update(keep)
        record=copy.deepcopy(entity);record.update({'boxes':boxes,'directory':'res://'+directory.relative_to(ROOT).as_posix(),'materials':materials})
        if entity['class_name']=='Mailbox':
            inverse={entry&0xffffff:i for i,entry in enumerate(table)}
            record['item_resources']=[inverse[p] for slot in ['0x24','0x28','0x2c','0x30'] if entity['props'][slot] for p in exports[entity['props'][slot]]]
            record['camera']=camera(entity['props']['0x14'])
            sound_ids.add(251)
        if entity['class_name']=='seesaw':
            record['trajectories']=[trajectory(entity['props']['0x2c']),trajectory(entity['props']['0x30'])]
            record['ejection_boxes']=[box_export(entity['props']['0x18']),box_export(entity['props']['0x1c'])]
            record['cameras']=[camera(entity['props']['0x0']),camera(entity['props']['0xc'])]
        if entity['class_name']=='SensibleButton':
            inverse={entry&0xffffff:i for i,entry in enumerate(table)}
            record['target_resources']=[inverse[p] for p in exports[entity['props']['0x0']]]
        definitions.append(record)
        print(entity['class_name'],entity['res'],'separated',removed,'vertices; animations',list(rig['animations']))
    snd=(folder/'Lvl-00.SND').read_bytes();at=12;sounds={};(output/'audio').mkdir(exist_ok=True)
    for _ in range(struct.unpack_from('<I',snd,8)[0]):
        identity,size,flags=struct.unpack_from('<III',snd,at)
        if identity in sound_ids:
            path=output/'audio'/f'{identity}.wav';blob=snd[at+12:at+12+size]
            if verify:assert path.read_bytes()==blob
            else:path.write_bytes(blob)
            sounds[str(identity)]='res://'+path.relative_to(ROOT).as_posix()
            if identity==68:
                shared=ROOT/'assets/items/audio/rocket_crash.wav'
                if verify:assert shared.read_bytes()==blob
                else:shared.write_bytes(blob)
        at+=12+size
    wolf=next(e for e in entities if e['class_name']=='Wolf')
    sheep=next(e for e in entities if e['class_name']=='Sheep')
    goal=copy.deepcopy(next(e for e in entities if e['class_name']=='Goal'))
    pointer=struct.unpack_from('<I',war,(table[goal['model_res']]&0xffffff)+12)[0]
    flags,*v=struct.unpack_from('<I6h',war,pointer+4)
    goal['box']={'flags':flags,'min':v[:3],'max':v[3:]}
    save(output/'definitions.json',{'objects':definitions,'sounds':sounds,'fly_box':box_export(wolf['props']['0x4']),'sheep':sheep,'goal':goal})
    save(prior,static)
if __name__=='__main__':main()
