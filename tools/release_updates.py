"""Build/sign immutable Godot resource updates. Private keys never enter Git.

keygen --private-key C:/Users/you/.ralphwolf/updates-private.pem
build --godot GODOT_EXE --platform windows-x86_64 --version 1.0.1 --sequence 1 --private-key ...
sign-pack --pack exported.zip --platform android-arm64 --version 1.0.1 --sequence 1 --private-key ...
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile
from datetime import datetime, timezone
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / 'config/updates.json'
PRESETS = {'windows-x86_64': 'Windows Desktop', 'android-arm64': 'Android'}
PROTECTED = ('scripts/updates/', 'config/', 'scenes/startup/UpdateGate.tscn')

def keygen(private: Path, public: Path):
    private = private.resolve()
    if private.is_relative_to(ROOT.resolve()):
        raise ValueError('La clave privada debe guardarse FUERA del repositorio.')
    private.parent.mkdir(parents=True, exist_ok=True)
    if private.exists():
        key = serialization.load_pem_private_key(private.read_bytes(), password=None)
    else:
        key = rsa.generate_private_key(public_exponent=65537, key_size=3072)
        with private.open('xb') as stream:
            stream.write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
        os.chmod(private, 0o600)
    public.parent.mkdir(parents=True, exist_ok=True)
    encoded = key.public_key().public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo)
    if public.exists() and public.read_bytes() != encoded:
        raise ValueError('La clave pública ya existe y es diferente. No rotarla accidentalmente.')
    public.write_bytes(encoded)
    print('Clave pública lista:', public)
    print('Conserva la clave privada fuera de Git y del servidor web.')

def signed_envelope(payload: dict, private: Path, key_id: str) -> dict:
    key = serialization.load_pem_private_key(private.read_bytes(), password=None)
    data = json.dumps(payload, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    signature = key.sign(data, padding.PKCS1v15(), hashes.SHA256())
    return dict(key_id=key_id, payload_base64=base64.b64encode(data).decode(), signature_base64=base64.b64encode(signature).decode())

def protect(name: str) -> bool:
    return name in ('project.binary', 'project.godot') or name.startswith(PROTECTED)

def make_release(source: Path, output: Path, platform: str, version: str, sequence: int, private: Path, config: dict):
    if sequence < 1 or sequence > 2147483647 or not re.fullmatch(r'[A-Za-z0-9._-]{1,64}', version):
        raise ValueError('Versión o secuencia inválidas.')
    # Immutable paths also include the logical version for easier review.
    relative = f'releases/{sequence:08d}-{version}/{platform}/content.zip'
    destination = output / relative
    if destination.exists():
        raise FileExistsError(f'La versión ya existe, no se sobrescribe: {destination}')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(source) as archive:
        blocked = {n for n in archive.namelist() if protect(n)}
        # Godot exports .gd/.tscn remaps to generated .gdc/.scn resources.
        # Excluding a bootstrap .remap must exclude its generated target too.
        for name in list(blocked):
            if name.endswith('.remap'):
                for target in re.findall(r'path="res://([^"]+)"', archive.read(name).decode('utf-8')):
                    blocked.add(target)
        with zipfile.ZipFile(destination.with_suffix('.part'), 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=1) as package:
            for info in archive.infolist():
                name = info.filename
                if name in blocked or name == 'assets/updates/content_release.json': continue
                if name.startswith('/') or '..' in name or '\\' in name:
                    raise ValueError('Ruta inválida en exportación: '+name)
                with archive.open(info) as src, package.open(info.filename, 'w', force_zip64=True) as dst:
                    while chunk := src.read(1024*1024): dst.write(chunk)
            marker = dict(product_id=config['product_id'], sequence=sequence, platform=platform, content_version=version)
            package.writestr('assets/updates/content_release.json', json.dumps(marker))
    destination.with_suffix('.part').replace(destination)
    digest = hashlib.sha256()
    with destination.open('rb') as stream:
        while chunk := stream.read(1024*1024): digest.update(chunk)
    payload = dict(schema_version=1, product_id=config['product_id'], channel=config['channel'],
                   platform=platform, content_version=version, sequence=sequence,
                   engine_version=config['engine_version'], bootstrap_abi=config['bootstrap_abi'],
                   released_at=datetime.now(timezone.utc).isoformat(),
                   package=dict(path=relative, bytes=destination.stat().st_size, sha256=digest.hexdigest()))
    envelope = signed_envelope(payload, private, config['key_id'])
    manifest = output / config['channel'] / platform / 'manifest.json'
    manifest.parent.mkdir(parents=True, exist_ok=True)
    temporary = manifest.with_suffix('.tmp')
    temporary.write_text(json.dumps(envelope, indent=2), encoding='utf-8')
    temporary.replace(manifest)
    # Human-readable audit is not trusted by clients and contains no secret.
    destination.with_name('release-info.json').write_text(json.dumps(payload, indent=2), encoding='utf-8')
    print('Paquete:', destination)
    print('Manifiesto:', manifest)
    return envelope

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    keys = sub.add_parser('keygen')
    keys.add_argument('--private-key', type=Path, required=True)
    keys.add_argument('--public-key', type=Path, default=ROOT/'config/updates_public.pem')
    for name in ('build','sign-pack'):
        cmd = sub.add_parser(name)
        cmd.add_argument('--platform', choices=PRESETS, required=True)
        cmd.add_argument('--version', required=True)
        cmd.add_argument('--sequence', type=int, required=True)
        cmd.add_argument('--private-key', type=Path, required=True)
        cmd.add_argument('--output', type=Path, default=ROOT/'builds/updates')
        cmd.add_argument('--engine-version', default='4.7.2')
        if name=='build': cmd.add_argument('--godot', type=Path, required=True)
        else: cmd.add_argument('--pack', type=Path, required=True)
    args = parser.parse_args()
    if args.command=='keygen': keygen(args.private_key,args.public_key); return
    config=json.loads(CONFIG.read_text()); config['engine_version']=args.engine_version
    # Signing must use the public key embedded in the bootstrap, not a new key.
    private=serialization.load_pem_private_key(args.private_key.read_bytes(),password=None)
    expected=private.public_key().public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo)
    if (ROOT/'config/updates_public.pem').read_bytes()!=expected:
        raise ValueError('La clave privada no corresponde a la pública del juego.')
    if args.command=='sign-pack':
        make_release(args.pack,args.output,args.platform,args.version,args.sequence,args.private_key,config); return
    if args.output.resolve().is_relative_to(ROOT):
        args.output.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='ralph-update-') as folder:
        exported=Path(folder)/'export.zip'
        subprocess.run([str(args.godot),'--headless','--path',str(ROOT),'--export-pack',PRESETS[args.platform],str(exported)],check=True)
        if not exported.exists(): raise RuntimeError('Godot no generó el paquete.')
        make_release(exported,args.output,args.platform,args.version,args.sequence,args.private_key,config)

if __name__=='__main__': main()
