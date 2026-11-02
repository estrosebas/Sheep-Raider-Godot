"""Native WAR0x83/DAV texture-scroll rectangles, reusable for any scene."""
import json, struct, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def extract(decomp,folder):
    decomp,folder = Path(decomp),Path(folder); sys.path.insert(0,str(decomp/'tools'))
    import war_meshes
    war = next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    path = next(folder.glob('*.[dD][aA][vV]')); raw = path.read_bytes(); dav = war_meshes.read_dav(path)
    table = struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
    header = next(value&0xffffff for value in table if value>>24==0x83)
    identities = struct.unpack_from('<4H',war,header); reverse = struct.unpack_from('<H',war,header+8)[0]
    directory = struct.unpack_from('<I',raw,0x14)[0]; records = struct.unpack_from('<I',raw,directory+10)[0]
    p = struct.unpack_from('<I',raw,directory+18)[0]; n = struct.unpack_from('<I',raw,p)[0]; p += 4; exports = {}
    for _ in range(n):
        identity,count = struct.unpack_from('<HH',raw,p); exports[identity] = struct.unpack_from('<%dI'%count,raw,p+4); p += 4+count*4
    regions = []
    for i,identity in enumerate(identities):
        for pointer in exports.get(identity,[]):
            bitmap = (pointer-records)//10; x,width,y,height,page = dav['rects'][bitmap]
            regions.append(dict(list=identity,bitmap=bitmap,page=page,rect=[x,y,width,height],step=-1 if reverse&(1<<i) else 1))
    slug = folder.name.lower().replace('-','_')
    (ROOT/'assets/levels'/slug/'data/texture_scroll.json').write_text(json.dumps(regions,indent=2)+'\n',encoding='utf8')
    print(slug,'native animated texture rectangles',len(regions),'lists',identities)
if __name__=='__main__': extract(*sys.argv[1:3])
