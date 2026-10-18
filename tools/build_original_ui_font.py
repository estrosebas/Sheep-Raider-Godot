"""Wrap the recovered FONT_GAME atlas for Godot Labels without a fallback font."""
from pathlib import Path
import shutil
ROOT = Path(__file__).resolve().parent.parent
base = ROOT / 'assets/ui/pause'
# BMFont import marks page images as skip; keep the texture used by HUD drawing separate.
shutil.copyfile(base/'font.png',base/'original_font_atlas.png')
lines=['info face="Sheep Raider Original" size=16 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0', 'common lineHeight=17 base=14 scaleW=256 scaleH=224 pages=1 packed=0', 'page id=0 file="original_font_atlas.png"']
chars=[]
for code in range(32,256):
 glyph=code-32
 chars.append(f'char id={code} x={(glyph%16)*16} y={(glyph//16)*16} width=15 height=15 xoffset=0 yoffset=0 xadvance=15 page=0 chnl=15')
# Native text is CP1252; include its Unicode punctuation aliases for the port.
for byte in range(128,160):
 try: code=ord(bytes([byte]).decode('cp1252'))
 except UnicodeDecodeError: continue
 if code==byte: continue
 glyph=byte-32
 chars.append(f'char id={code} x={(glyph%16)*16} y={(glyph//16)*16} width=15 height=15 xoffset=0 yoffset=0 xadvance=15 page=0 chnl=15')
(base/'original_font.fnt').write_text('\n'.join(lines+[f'chars count={len(chars)}']+chars)+'\n',encoding='utf8',newline='\n')
print('Original bitmap font:',len(chars),'characters and aliases')
