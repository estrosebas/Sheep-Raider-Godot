"""Recover original checkpoints/FallingRock triggers and separate their geometry."""
from collections import Counter
import copy,json,struct,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent

def main():
    decomp,folder=map(Path,sys.argv[1:3])
    verify='--verify' in sys.argv
    sys.path.insert(0,str(decomp/'tools'))
    import level_editor as editor
    files={p.suffix.lower():p for p in folder.iterdir()}
    war=files['.war'].read_bytes();dav=files['.dav'].read_bytes()
    table=struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
    at=next(e&0xffffff for e in table if e>>24==0x82)
    n,=struct.unpack_from('<I',war,at);at+=4;exports={}
    for _ in range(n):
        identity,count=struct.unpack_from('<HH',war,at)
        exports[identity]=struct.unpack_from('<%dI'%count,war,at+4);at+=4+4*count
    def box(identity):
        p=exports[identity][0];flags,*v=struct.unpack_from('<I6h',war,p)
        return {'export':identity,'flags':flags,'min':v[:3],'max':v[3:]}
    entities=json.loads((ROOT/'assets/levels/lvl_00/data/entities.json').read_text())
    manager=next(e for e in entities if e['class_name']=='CheckpointManager')
    checkpoints=[]
    for index in range(8):
        props=manager['props'];identity=props[hex(index*16)]
        if identity:
            checkpoints.append({'index':index,'trigger':box(identity),
                'destination':box(props[hex(index*16+12)]),'yaw':props[hex(index*16+4)]})
    rocks=[e for e in entities if e['class_name']=='FallingRock']
    output=ROOT/'assets/levels/lvl_00/data'
    static=copy.deepcopy(json.loads((output/'level_objects_data.json').read_text()))
    removed=0
    def key(vs,uvs):
        return tuple(round(c,4) for v in vs for c in v)+tuple(round(c,5) for uv in uvs for c in uv)
    # Separate every runtime pickup/FallingRock from the original full export.
    for entity in [e for e in entities if e['class_id']==10]+rocks:
        resource=table[entity['model_res']]
        geometry=editor.geometry(war,editor.dav_tables(dav),resource&0xffffff,resource>>24==0x44)
        local={}
        for page,values in geometry['groups'].items():
            group={'page':int(page),'verts':[],'uvs':[],'cols':[]}
            for i in range(0,len(values),8):
                x,y,z,u,v,r,g,b=values[i:i+8]
                group['verts'].append([round(x*.01,4),round(-y*.01,4),round(z*.01,4)])
                group['uvs'].append([u,v]);divisor=128 if int(page)>=0 else 255
                group['cols'].append([r/divisor,g/divisor,b/divisor])
            local[page]=group
            world=[[round(a+b,4) for a,b in zip(vertex,entity['pos'])] for vertex in group['verts']]
            wanted=Counter(key(world[i:i+3],group['uvs'][i:i+3]) for i in range(0,len(world),3))
            merged=static[page];keep={name:[] for name in ['verts','uvs','cols']}
            for i in range(0,len(merged['verts']),3):
                triangle=key(merged['verts'][i:i+3],merged['uvs'][i:i+3])
                if wanted[triangle]:
                    wanted[triangle]-=1;removed+=3
                else:
                    for name in keep: keep[name].extend(merged[name][i:i+3])
            assert not any(wanted.values()),('Missing geometry',entity['res'],sum(wanted.values()))
            merged.update(keep)
        if entity['class_name']=='FallingRock':
            path=output/'falling_rock_data.json'
            if verify: assert json.loads(path.read_text())==local
            else: path.write_text(json.dumps(local,separators=(',',':')))
    rock_data=[{'res':e['res'],'position':e['pos'],'activation':box(e['props']['0x0'])} for e in rocks]
    result={'checkpoints':checkpoints,'falling_rocks':rock_data,'drop_height':20.0,'drop_step':4.0,
            'drop_ticks':5,'impact_sound_id':68}
    snd=files['.snd'].read_bytes();at=12
    for _ in range(struct.unpack_from('<I',snd,8)[0]):
        identity,size,flags=struct.unpack_from('<III',snd,at)
        if identity==68:
            path=ROOT/'assets/audio/sfx/falling_rock_impact.wav';blob=snd[at+12:at+12+size]
            if verify: assert path.read_bytes()==blob
            else: path.write_bytes(blob)
        at+=12+size
    for path,data in [(output/'level_static_data.json',static),(output/'tutorial_progress.json',result)]:
        if verify: assert json.loads(path.read_text())==data,path
        else:path.write_text(json.dumps(data,separators=(',',':')))
    print('Recovered',len(checkpoints),'checkpoints /',len(rocks),'hidden rocks; split',removed,'vertices; verified=',verify)
    if (ROOT/'assets/levels/lvl_00/puzzle/definitions.json').exists():
        from extract_puzzle import main as separate_puzzle
        separate_puzzle()

if __name__=='__main__':main()
