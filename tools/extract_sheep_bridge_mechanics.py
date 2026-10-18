"""Recover Level01 bridge zones, complete bridge/sheep clips and item HUD art."""
import json, struct, sys
from pathlib import Path
from extract_shared_items import read_rig, page_image
from extract_inventory_ui import read_lists
ROOT = Path(__file__).resolve().parent.parent
def main():
    decomp, game = map(Path,sys.argv[1:3])
    sys.path.insert(0,str(decomp/'tools'))
    import level_editor as editor, war_meshes
    folder = game/'Levels/Lvl-01'
    war = (folder/'Lvl-01.WAR').read_bytes()
    raw = (folder/'Lvl-01.DAV').read_bytes()
    table = struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
    pointer = next(e&0xffffff for e in table if e>>24 == 0x82)
    n = struct.unpack_from('<I',war,pointer)[0]; pointer += 4
    exports = {}
    for _ in range(n):
        identity,count = struct.unpack_from('<HH',war,pointer)
        exports[identity] = struct.unpack_from('<%dI'%count,war,pointer+4)
        pointer += 4+count*4
    def boxes(identity):
        result=[]
        for p in exports.get(identity,[]):
            flags,*v=struct.unpack_from('<I6h',war,p)
            result.append({'flags':flags,'min':v[:3],'max':v[3:]})
        return result
    level=ROOT/'assets/levels/lvl_01'
    entities=json.loads((level/'data/entities.json').read_text())
    bridges=[]
    for e in entities:
        if e['class_id']==6:
            bridges.append({**e,'fall_zone':boxes(e['props']['0x0']),'master':bool(e['props']['0x8'])})
    (level/'data/bridges.json').write_text(json.dumps(bridges,indent=2))
    dav=war_meshes.read_dav(folder/'Lvl-01.DAV')
    for model in [1,10]:
        at=table[model]&0xffffff; p=struct.unpack_from('<I',war,at+16)[0]
        ptrs=struct.unpack_from('<%dI'%struct.unpack_from('<I',war,p)[0],war,p+4)
        names={war[q:q+8].split(b'\0')[0].decode().lower() for q in ptrs if q}
        data=read_rig(war,table[model],editor,war_meshes,editor.dav_tables(raw),{s:s for s in names})
        directory=level/'models'/str(model)
        materials={}
        for page in data['surfaces']:
            if int(page)<0: continue
            record=dav['pages'][int(page)]
            (directory/'textures').mkdir(exist_ok=True)
            page_image(raw,record).save(directory/'textures'/f'page_{page}.png')
            materials[page]=record['kind']
        (directory/'worn_data.json').write_text(json.dumps(data,separators=(',',':')))
        (directory/'definition.json').write_text(json.dumps({'materials':materials}))
        print('Recovered model',model,sorted(names))
    from extract_lettuce_prompt import extract
    extract(decomp, folder)
    sounds=json.loads((level/'data/ai_audio.json').read_text())
    snd=(folder/'Lvl-01.SND').read_bytes();p=12
    for _ in range(struct.unpack_from('<I',snd,8)[0]):
        identity,size,flags=struct.unpack_from('<III',snd,p)
        if identity in [14,66,105]:
            dest=level/'audio'/f'{identity}.wav'
            dest.write_bytes(snd[p+12:p+12+size])
            sounds[str(identity)]='res://'+dest.relative_to(ROOT).as_posix()
        p+=12+size
    (level/'data/ai_audio.json').write_text(json.dumps(sounds))
if __name__=='__main__': main()
