"""Bake localized original bitmap-font messages into classic loading images."""
from pathlib import Path
import json
from PIL import Image,ImageFilter
ROOT=Path(__file__).resolve().parents[1]
atlas=Image.open(ROOT/'assets/ui/pause/font.png').convert('RGBA')
strings=json.loads((ROOT/'assets/localization/ui.json').read_text(encoding='utf8'))
def text(image,value,y):
    x=(512-len(value)*9)//2
    layer=Image.new('RGBA',image.size)
    for i,char in enumerate(value):
        code=min(255,max(32,ord(char)));index=code-32
        glyph=atlas.crop(((index%16)*16,(index//16)*16,(index%16)*16+15,(index//16)*16+15)).resize((9,13),Image.Resampling.BILINEAR)
        r,g,b,a=glyph.split();glyph=Image.merge('RGBA',(r.point(lambda v:min(255,v*2)),g.point(lambda v:min(255,int(v*1.7))),b.point(lambda v:int(v*.44)),a))
        outline=Image.new('RGBA',(glyph.width+2,glyph.height+2),(8,20,69,0))
        alpha=Image.new('L',outline.size);alpha.paste(a,(1,1))
        outline.putalpha(alpha.filter(ImageFilter.MaxFilter(3)))
        layer.alpha_composite(outline,(x+i*9-1,y-1))
        layer.alpha_composite(glyph,(x+i*9,y))
    image.alpha_composite(layer)
for path in sorted((ROOT/'remaster/pantallas_carga').glob('LEV*.png')):
    for locale in ['es','en','it','pt_BR']:
        folder=ROOT/'assets/ui/loading/classic'/locale;folder.mkdir(parents=True,exist_ok=True)
        image=Image.open(path).convert('RGBA');text(image,strings[locale]['Cargando...'],14)
        image.convert('RGB').save(folder/(path.stem+'_loading.png'))
        text(image,strings[locale]['Pulsa E para continuar'],195)
        image.convert('RGB').save(folder/(path.stem+'_ready.png'))
print('Prepared 18 classic illustrations, 4 languages, loading/ready images')
