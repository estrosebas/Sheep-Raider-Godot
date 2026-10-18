"""Separate WAR sky type 0x26 and recover the Spanish signpost bank/properties."""
import json,struct,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent

def main():
    decomp,folder=map(Path,sys.argv[1:3])
    verify='--verify' in sys.argv
    def save(path,data):
        if verify: assert json.loads(path.read_text(encoding='utf-8'))==data,path
        else: path.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
    sys.path.insert(0,str(decomp/'tools'))
    import level_editor as editor
    war=(folder/'Lvl-00.WAR').read_bytes()
    dav=editor.dav_tables((folder/'Lvl-00.DAV').read_bytes())
    table=struct.unpack_from('<%dI'%struct.unpack_from('<I',war,12)[0],war,16)
    banks={'scenery_world':{},'sky':{}}
    sky_resources=[]
    for identity,entry in enumerate(table):
        kind=entry>>24
        if kind not in (3,11,38):continue
        target=banks['sky' if kind==38 else 'scenery_world']
        if kind==38:sky_resources.append(identity)
        for page,values in editor.geometry(war,dav,entry&0xffffff,False)['groups'].items():
            group=target.setdefault(page,{'page':int(page),'verts':[],'uvs':[],'cols':[]})
            for i in range(0,len(values),8):
                x,y,z,u,v,r,g,b=values[i:i+8]
                group['verts'].append([x*.01,-y*.01,z*.01])
                group['uvs'].append([u,v])
                divisor=128 if int(page)>=0 else 255
                group['cols'].append([r/divisor,g/divisor,b/divisor])
    raw=(folder/'Lvl-00.MLT').read_bytes();blocks,lists=struct.unpack_from('<HH',raw,8);at=16;languages=[]
    for _ in range(blocks):
        bank=[]
        for _ in range(lists):
            count=raw[at];at+=1;strings=[]
            for _ in range(count):
                end=raw.index(0,at);strings.append(raw[at:end].decode('cp1252'));at=end+1
            bank.append(strings)
        languages.append(bank)
    entities=json.loads((ROOT/'assets/levels/lvl_00/data/entities.json').read_text())
    at=next(e&0xffffff for e in table if e>>24==0x82)
    count,=struct.unpack_from('<I',war,at);at+=4;exports={}
    for _ in range(count):
        identity,n=struct.unpack_from('<HH',war,at)
        exports[identity]=struct.unpack_from('<%dI'%n,war,at+4);at+=4+n*4
    signs=[]
    for e in entities:
        if e['class_name']!='SignPost':continue
        props=e['props'];p=exports[props['0x8']][0]
        focal,*v=struct.unpack_from('<H6h',war,p)
        signs.append({'res':e['res'],'position':e['pos'],'distance':props['0x0']*.01,
                      'text_index':props['0xc'],'texts':languages[2][e['class_id']+1],
                      'anvil_export':props['0x4'],'camera':{'focal':focal,'rotation':v[:3],'eye':v[3:]}})
    output=ROOT/'assets/levels/lvl_00/data'
    for name,data in banks.items():
        save(output/(name+'_data.json'),data)
    result={'sky_resources':sky_resources,'sky_draw':'WorldObj_DrawSky: view translation = 0; identity world',
            'signs':signs}
    save(output/'sky_signs.json',result)
    print('Sky:',len(sky_resources),'pieces;',sum(len(g['verts']) for g in banks['sky'].values()),'vertices. Signs:',len(signs))
    print(signs[0]['texts'])

if __name__=='__main__':main()
