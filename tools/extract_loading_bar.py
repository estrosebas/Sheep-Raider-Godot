"""Recover chalk loading-border pixels from the original PS1 EBS artwork."""
from pathlib import Path
import json
from PIL import Image
root=Path(__file__).resolve().parents[1]
source=root/'remaster/pantallas_carga/LEV00.png'
out=root/'assets/ui/loading';out.mkdir(parents=True,exist_ok=True)
rect=(148,208,359,229)
image=Image.open(source).convert('RGB').crop(rect)
frame=Image.new('RGBA',image.size)
for y in range(image.height):
    for x in range(image.width):
        r,g,b=image.getpixel((x,y));neutral=min(r,g,b)
        alpha=int(max(0,min(255,(neutral-105)*2))) if max(r,g,b)-neutral<85 else 0
        frame.putpixel((x,y),(r,g,b,alpha))
frame.save(out/'bar_frame.png')
# Fill carries the sampled chalk's colour/grain, not a flat yellow rectangle.
fill=Image.new('RGBA',(195,7))
for x in range(195):
    samples=[frame.getpixel((x+5,y)) for y in range(frame.height)]
    colour=max(samples,key=lambda c:c[3])
    for y in range(7):fill.putpixel((x,y),(colour[0],colour[1],colour[2],max(80,colour[3]) if y not in [0,6] else max(40,colour[3]//2)))
fill.save(out/'bar_fill.png')
(out/'bar_source.json').write_text(json.dumps({'source':'original PS1 LEV00.EBS, decoded LEV00.png','crop':list(rect),'frame_origin':[148,208],'inner_rect':[154,215,195,7],'fill':'sampled chalk border colours; dynamic fill reconstruction'},indent=2),encoding='utf8')
