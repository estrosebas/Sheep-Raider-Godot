"""Export the public website, web game and signed native installers locally."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parent.parent

def digest(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest()

def bundle(output,version,directories):
    files=[]
    for directory in directories:
        for path in sorted(directory.rglob('*')):
            if path.is_file() and not path.name.endswith('.import'):
                files.append({'path':path.relative_to(output).as_posix(),'sha256':digest(path),'bytes':path.stat().st_size})
    (output/'bundle.json').write_text(json.dumps({'version':version,'files':files},indent=2))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--version',required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--android-signing',type=Path,default=Path.home()/'.ralphwolf/android-signing.json')
    parser.add_argument('--site-only',action='store_true',help='Publish the landing page without rebuilding installers or the game')
    parser.add_argument('--native-only',action='store_true',help='Update native installers only, preserving the web export and landing')
    parser.add_argument('--web-only',action='store_true',help='Publish website and web game without changing native installers')
    args=parser.parse_args()
    if sum([args.site_only,args.native_only,args.web_only])>1:raise ValueError('Choose only one partial distribution mode')
    if not re.fullmatch(r'[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*',args.version): raise ValueError('Invalid version')
    if args.output.exists(): raise FileExistsError('Choose a fresh output directory; existing builds are preserved')
    args.output.mkdir(parents=True)
    def godot(arguments,name):
        log=args.output/(name+'.log')
        with log.open('wb') as stream:
            result=subprocess.run([str(args.godot),'--headless','--path',str(ROOT),*arguments],stdout=stream,stderr=subprocess.STDOUT,env=env)
        text=log.read_text(encoding='utf-8',errors='replace')
        if result.returncode or re.search(r'(?m)^(SCRIPT ERROR:|ERROR:)',text):
            raise RuntimeError('Godot failed; inspect '+str(log))
    site=args.output/'site';site.mkdir()
    shutil.copy2(ROOT/'website/index.html',site/'index.html')
    shutil.copytree(ROOT/'website/site-assets',site/'site-assets')
    for name in ('site.css','site.js'):shutil.copy2(ROOT/'website'/name,site/'site-assets'/name)
    html=(site/'index.html').read_text(encoding='utf-8')
    for asset in sorted((site/'site-assets').iterdir()):
        if asset.is_file():html=html.replace('/site-assets/'+asset.name,'/site-assets/'+asset.name+'?v='+digest(asset)[:12])
    (site/'index.html').write_text(html,encoding='utf-8')
    if args.site_only:
        bundle(args.output,args.version,[site]);print('Website bundle ready',flush=True);return
    project_version=re.search(r'^config/version="([^"]+)"',(ROOT/'project.godot').read_text(encoding='utf-8'),re.M).group(1)
    if not args.web_only and project_version!=args.version:raise ValueError('Installer version must match project.godot; update its version before exporting a new installer')
    env=dict(os.environ)
    if not args.web_only:
        signing=json.loads(args.android_signing.read_text())
        env.update({'GODOT_ANDROID_KEYSTORE_RELEASE_PATH':signing['keystore'],
         'GODOT_ANDROID_KEYSTORE_RELEASE_USER':signing['alias'],
         'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD':signing['password']})
    web=args.output/'play'
    if not args.native_only:
        web.mkdir()
        print('Exporting Web...',flush=True)
        godot(['--export-release','Web',str((web/'index.html').resolve())],'web-export')
        for name in ('index.wasm','index.pck'):
            source=web/name
            with source.open('rb') as src, source.with_suffix(source.suffix+'.gz').open('wb') as target:
                with gzip.GzipFile(filename='',mode='wb',compresslevel=6,fileobj=target,mtime=0) as compressed:shutil.copyfileobj(src,compressed)
    if args.web_only:
        bundle(args.output,args.version,[site,web]);print('Web distribution ready',flush=True);return
    windows=args.output/'windows';windows.mkdir()
    print('Exporting Windows...',flush=True)
    godot(['--export-release','Windows Desktop',str((windows/'RalphWolf.exe').resolve())],'windows-export')
    godot(['--script','tools/export_engine_notices.gd','--',str((windows/'Licencias_Godot.txt').resolve())],'engine-notices')
    shutil.copy2(ROOT/'tools/windows_test_readme.txt',windows/'LEEME.txt')
    downloads=args.output/'downloads'
    zip_path=downloads/'windows'/args.version/'RalphWolf-Windows.zip';zip_path.parent.mkdir(parents=True)
    with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for path in sorted(windows.iterdir()):
            if path.is_file() and not path.name.endswith('.import'):archive.write(path,path.name)
    print('Exporting signed Android APK...',flush=True)
    apk=downloads/'android'/args.version/'RalphWolf.apk';apk.parent.mkdir(parents=True)
    godot(['--export-release','Android',str(apk.resolve())],'android-export')
    metadata={'version':args.version,'downloads':{}}
    for platform,path in [('windows-x86_64',zip_path),('android-arm64',apk)]:
        metadata['downloads'][platform]={'path':'/'+path.relative_to(args.output).as_posix(),'bytes':path.stat().st_size,'sha256':digest(path)}
    (downloads/'latest.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')
    # Export helpers can create import settings next to PNGs; those are editor data.
    bundle(args.output,args.version,[downloads] if args.native_only else [site,web,downloads])
    print('Distribution ready: '+str(args.output.resolve()),flush=True)

if __name__=='__main__':main()
