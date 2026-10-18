"""Preserve original DAV pixels for the new AI/cinematic atlas banks."""
from pathlib import Path
root=Path(__file__).resolve().parent.parent
for base in ['assets/levels/lvl_01/cinematics','assets/levels/lvl_01/sam_head','assets/levels/lvl_01/sheep_sleep','assets/levels/lvl_01/models/2/textures','assets/levels/lvl_01/models/16/textures']:
 for p in (root/base).rglob('*.png.import'):
  s=p.read_text().replace('process/fix_alpha_border=true','process/fix_alpha_border=false').replace('detect_3d/compress_to=1','detect_3d/compress_to=0').replace('compress/mode=2','compress/mode=0').replace('mipmaps/generate=true','mipmaps/generate=false')
  p.write_text(s)
