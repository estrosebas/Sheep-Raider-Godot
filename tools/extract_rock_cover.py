"""Native HIDE1/HIDE2 and HiddenRocks proximity/visibility rules from Lvl-03."""
import json,struct,sys
from pathlib import Path
from extract_run_assets import decode
ROOT=Path(__file__).resolve().parents[1]
def main():
    folder=Path(sys.argv[1]);w=next(folder.glob('*.[wW][aA][rR]')).read_bytes()
    table=struct.unpack_from('<%dI'%struct.unpack_from('<I',w,12)[0],w,16)
    model=table[0]&0xffffff;p=struct.unpack_from('<I',w,model+16)[0]
    count=struct.unpack_from('<I',w,p)[0];ptrs=struct.unpack_from('<%dI'%count,w,p+4)
    names={w[q:q+8].split(b'\0')[0].decode().lower():q for q in ptrs if q}
    joints=struct.unpack_from('<H',w,model+24)[0]
    animations={alias:decode(w,names[name],joints) for name,alias in [('hide1','cover_enter'),('hide2','cover_hidden')]}
    out=ROOT/'assets/models/ralph_cover_data.json';out.write_text(json.dumps(animations,separators=(',',':')))
    metadata={'source':'HiddenRocks::MSG_QUERY_COVER / Wolf::COVER_APPROACH,COVER_ENTER,HIDDEN / MSG_WOLF_IS_VISIBLE',
              'source_level':'Lvl-03','gap_units':10,'scale':.01,'toward_side_angle_units':682,'side_headings':[1024,0,2048,3072],
              'visibility':'ScnObject::IsOnSameSideAs(observer,coverObject)',
              'port':'Free camera; HIDE1 smoothly centres Ralph on the selected face. Keep the capsule outside the solid box and align only the visual torso to the actual rock triangles. Releasing cover restores the mesh origin; blocked approaches cancel without teleporting. Release directional input to stay hidden, move away or sideways with Ctrl to resume sneak.'}
    (ROOT/'assets/models/ralph_cover_rules.json').write_text(json.dumps(metadata,indent=2))
    print('Native cover:',[(k,v['original_name'],v['duration'],v['sound_cues']) for k,v in animations.items()])
if __name__=='__main__':main()
