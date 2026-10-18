"""Original FONT_GAME atlas; pause backdrop follows PauseMenu_CreateNoiseTexture."""
import json,sys,re,struct
from pathlib import Path
from extract_inventory_ui import read_lists
from extract_shared_items import page_image
ROOT=Path(__file__).resolve().parent.parent
def main():
    decomp,folder=map(Path,sys.argv[1:3]);verify='--verify' in sys.argv
    sys.path.insert(0,str(decomp/'tools'))
    import war_meshes
    from PIL import Image
    path=folder/'Lvl-00.DAV';raw=path.read_bytes();dav=war_meshes.read_dav(path)
    groups,_=read_lists(raw);bitmap=groups[36][0] # DAV_IDI_IGLTYPO_
    x,w,y,h,page=dav['rects'][bitmap]
    atlas=page_image(raw,dav['pages'][page]).crop((x,y,x+w,y+h))
    out=ROOT/'assets/ui/pause';out.mkdir(parents=True,exist_ok=True)
    if verify: assert Image.open(out/'font.png').convert('RGBA').tobytes()==atlas.tobytes()
    else: atlas.save(out/'font.png')
    metadata={'resource':36,'bitmap':bitmap,'rect':[x,y,w,h],'page':page,
        'cell':[16,16],'first_character':32,'columns':16,'glyph':[15,15],
        'small_glyph':[9,13],'line_height':17,'source':str(path)}
    source=(decomp/'src/engine/text.cpp').read_text()
    metadata['variants']={}
    for name in ['Fwd','Rev']:
        body=re.search(r's_glyphVariant'+name+r'Table\[224\] = \{(.*?)\};',source,re.S)[1]
        metadata['variants'][name]=[int(v,16) for v in re.findall(r'0x([0-9a-f]+)',body)]
        assert len(metadata['variants'][name])==224
    bitmap=groups[21][0];x,w,y,h,page=dav['rects'][bitmap]
    frame=page_image(raw,dav['pages'][page]).crop((x,y,x+w,y+h))
    if verify:assert Image.open(out/'frame.png').convert('RGBA').tobytes()==frame.tobytes()
    else:frame.save(out/'frame.png')
    metadata['frame']={'resource':21,'bitmap':bitmap,'rect':[x,y,w,h],'page':page}
    enums=(decomp/'src/include/sdw_enums.h').read_text()
    wanted={int(re.search(r'\b'+symbol+r' = (0x[0-9a-f]+|\d+)',enums)[1],0):name for name,symbol in [('move','SND_SGLCHGLI'),('cancel','SND_SMOJPMOV'),('confirm','SND_SBONMBTN')]}
    snd=(folder/'Lvl-00.SND').read_bytes();at=12;metadata['sounds']={}
    for _ in range(struct.unpack_from('<I',snd,8)[0]):
        identity,size,flags=struct.unpack_from('<III',snd,at)
        if identity in wanted:
            target=out/(wanted[identity]+'.wav');blob=snd[at+12:at+12+size]
            if verify:assert target.read_bytes()==blob
            else:target.write_bytes(blob)
            metadata['sounds'][wanted[identity]]={'id':identity,'path':'res://'+target.relative_to(ROOT).as_posix()}
        at+=12+size
    assert len(metadata['sounds'])==3
    if verify:assert json.loads((out/'source.json').read_text())==metadata
    else:(out/'source.json').write_text(json.dumps(metadata,indent=2))
    print('Original pause font',atlas.size,'verified=',verify)
if __name__=='__main__':main()
