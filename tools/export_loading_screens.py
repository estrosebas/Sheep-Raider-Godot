"""Export PS1 EBS loading artwork losslessly to PNG using local jPSXdec."""
from pathlib import Path
import argparse, csv, hashlib, json, shutil, struct, subprocess, tempfile
from PIL import Image, ImageDraw

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('levels',type=Path); ap.add_argument('jar',type=Path); ap.add_argument('output',type=Path)
    a=ap.parse_args(); a.output.mkdir(parents=True,exist_ok=True); records=[]; tiles=[]
    for source in sorted(a.levels.rglob('*.EBS')):
        name=source.stem; blob=source.read_bytes(); split=struct.unpack_from('<I',blob)[0]+4
        assert 12<split<len(blob) and blob[6:8]==b'\0\x38' and blob[split+2:split+4]==b'\0\x38',source
        native=a.output/'originales_ebs'/source.name; native.parent.mkdir(exist_ok=True); shutil.copy2(source,native)
        folder=a.output if name.startswith('LEV') else a.output/'extras'
        folder.mkdir(exist_ok=True)
        paths=[]
        with tempfile.TemporaryDirectory(prefix='sdw_loading_') as temp:
            work=Path(temp)
            for i,data in enumerate([blob[4:split],blob[split:]]):
                bs=work/f'{name}_{i}.bs';bs.write_bytes(data)
                run=subprocess.run(['java','-jar',str(a.jar.resolve()),'-f',str(bs),'-static','bs','-dim','512x240','-q','psx','-fmt','png'],cwd=work,capture_output=True)
                png=work/f'{name}_{i}.png'
                if run.returncode or not png.exists(): raise RuntimeError(run.stdout.decode(errors='replace')+run.stderr.decode(errors='replace'))
                target=folder/f'{name}.png' if i==0 else folder/'con_texto'/f'{name}.png'
                target.parent.mkdir(exist_ok=True); shutil.copy2(png,target);paths.append(target.relative_to(a.output).as_posix())
                with Image.open(target) as image: assert image.size==(512,240); image.load()
        number=int(name[3:]) if name.startswith('LEV') else None
        label=(f'Nivel {number:02}' if number is not None and number<=4 else 'Bonus 1' if number==5 else f'Nivel {number-1:02}' if number is not None and 6<=number<=9 else 'Bonus 2' if number==10 else f'Nivel {number-2:02}' if number is not None and 11<=number<=16 else 'Planeta X' if number==17 else name)
        records.append({'nombre_original':source.name,'nivel_visible':label,'carpeta_pc':f'Lvl-{number:02}' if number is not None else name,'imagen':paths[0],'variante_con_texto':paths[1],'ancho':512,'alto':240,'sha256_ebs':hashlib.sha256(blob).hexdigest(),'origen':str(source)})
        if number is not None:
            image=Image.open(a.output/paths[0]).convert('RGB').resize((256,120))
            tile=Image.new('RGB',(256,145),(25,25,25));tile.paste(image,(0,0));ImageDraw.Draw(tile).text((8,125),f'{name} - {label}',fill='white');tiles.append(tile)
        print(name,label,'exported',flush=True)
    (a.output/'manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf8')
    with (a.output/'niveles.csv').open('w',newline='',encoding='utf-8-sig') as f:
        writer=csv.DictWriter(f,fieldnames=list(records[0]));writer.writeheader();writer.writerows(records)
    contact=Image.new('RGB',(256*3,145*((len(tiles)+2)//3)),(25,25,25))
    for i,tile in enumerate(tiles):contact.paste(tile,((i%3)*256,(i//3)*145))
    contact.save(a.output/'vista_general.png')
    (a.output/'LEEME.md').write_text('''# Pantallas originales de carga de Sheep Raider (PS1)

En esta carpeta: LEV00.png a LEV17.png, ilustraciones originales completas.
En con_texto/: segunda imagen de cada EBS, variante original con LOADING y
los avisos multilingües de pulsar X. Son dos imágenes independientes, no mitades.
En extras/: INTRO, SCENE, WHEEL, FEND, ENDING y CREDITS, con sus dos variantes.
En originales_ebs/: copia intacta de los archivos originales extraídos del disco.

Nombres LEVxx conservados del original; no hay nombres de imagen individuales
dentro del EBS. Los PNG se decodificaron con jPSXdec 2.1 beta, calidad psx,
512x240, sin ampliación, recorte ni mejora por IA. PNG no añade compresión con
pérdida; el EBS de origen sí usa compresión de imagen PS1. No se modifica el juego.
Los archivos EBS incluyen relleno de sector que se conserva en la copia original.

Consulta niveles.csv / manifest.json para las correspondencias y hashes.
La numeración de archivo difiere de la visible: LEV05 es Bonus 1, LEV10 Bonus 2,
LEV06..09 son niveles 05..08, LEV11..16 niveles 09..14, LEV17 Planeta X.
vista_general.png es sólo un índice reducido; usa los PNG individuales al editar.

Estos archivos proceden de la versión PS1 USA (En,Fr,Es,Pt) disponible localmente.
La función de carga de la versión PC examinada limpia la pantalla y no carga EBS.
''',encoding='utf8')
    print(f'Finished: {len(records)} EBS / {len(records)*2} PNG',flush=True)
if __name__=='__main__':main()
