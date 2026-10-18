"""APORTE01 from the original studio Scene.WAR/DAV, shared by lab portals."""
import json,struct,sys
from pathlib import Path
from extract_shared_items import read_rig,page_image
ROOT=Path(__file__).resolve().parent.parent
def main():
    decomp,folder=map(Path,sys.argv[1:3]);sys.path.insert(0,str(decomp/'tools'))
    import level_editor as editor,war_meshes
    war=(folder/'Scene.WAR').read_bytes();raw=(folder/'Scene.DAV').read_bytes();dav=war_meshes.read_dav(folder/'Scene.DAV')
    table=struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
    record=table[25]&0xffffff;model=struct.unpack_from('<H',war,record)[0]
    at=table[model]&0xffffff;anim=struct.unpack_from('<I',war,at+16)[0];n=struct.unpack_from('<I',war,anim)[0]
    ptrs=struct.unpack_from('<%dI'%n,war,anim+4)
    names={war[p:p+8].split(b'\0')[0].decode().lower():war[p:p+8].split(b'\0')[0].decode().lower() for p in ptrs if p}
    rig=read_rig(war,table[model],editor,war_meshes,editor.dav_tables(raw),names)
    out=ROOT/'assets/hub/studio_door';(out/'textures').mkdir(parents=True,exist_ok=True)
    (out/'worn_data.json').write_text(json.dumps(rig,separators=(',',':')))
    materials={}
    for page in rig['surfaces']:
        if int(page)<0:continue
        entry=dav['pages'][int(page)];page_image(raw,entry).save(out/'textures'/f'page_{page}.png');materials[page]=entry['kind']
    (out/'definition.json').write_text(json.dumps({'model':model,'resource':25,'source':'Scene.WAR DoorLevel/APORTE01','materials':materials}))
    print('Original studio door model',model,'animations',list(names))
if __name__=='__main__':main()
