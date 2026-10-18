"""Preserve user artwork bytes while supplying correctly named Godot sources."""
from pathlib import Path
import hashlib,json,shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'remaster/pantallas_carga/remasters'
target=ROOT/'assets/ui/loading/modern';target.mkdir(parents=True,exist_ok=True)
records=[]
for path in sorted(source.glob('LEV*.png')):
    with Image.open(path) as image:
        extension={'JPEG':'.jpg','PNG':'.png'}[image.format];size=list(image.size)
    dest=target/(path.stem+extension)
    shutil.copy2(path,dest) # No re-encoding, resizing or pixel changes.
    records.append({'original':str(path.relative_to(ROOT)).replace('\\','/'),'runtime':'res://'+dest.relative_to(ROOT).as_posix(),'size':size,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
(target/'manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf8')
print('Prepared',len(records),'images with correct extension, byte-for-byte copies')
