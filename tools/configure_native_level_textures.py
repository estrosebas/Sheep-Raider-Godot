"""Keep new native DAV exports lossless, without synthesized alpha-border pixels."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]/'assets/levels'/sys.argv[1]
count=0
for path in root.rglob('*.png.import'):
    old=path.read_text(); new=old.replace('process/fix_alpha_border=true','process/fix_alpha_border=false').replace('detect_3d/compress_to=1','detect_3d/compress_to=0').replace('compress/mode=2','compress/mode=0').replace('mipmaps/generate=true','mipmaps/generate=false')
    if new!=old:path.write_text(new);count+=1
print('Native texture settings:',sys.argv[1],count,'files adjusted')
