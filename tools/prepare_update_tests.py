"""Tiny signed content archives for local HTTP and cold-launch tests."""
from pathlib import Path
import json
import zipfile
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from release_updates import make_release, signed_envelope, ROOT

directory=ROOT/'validation/update-fixtures'
directory.mkdir(parents=True,exist_ok=True)
if (directory/'http/stable/windows-x86_64/manifest.json').exists():
    raise FileExistsError('Fixtures already exist; reuse them without rotating their signing key.')
key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
private=directory/'fixture-private.pem';public=directory/'fixture-public.pem'
private.write_bytes(key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()))
public.write_bytes(key.public_key().public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo))
config=json.loads((ROOT/'config/updates.json').read_text());config['engine_version']='4.7.2'
source=directory/'fixture.zip'
with zipfile.ZipFile(source,'w') as archive:
    archive.writestr('assets/update_fixture.json','{"marker":"downloaded-from-server"}')
    for name,label in [('scripts/localization/language_menu.gd','service_from_pack'),('scripts/player/ralph_controller.gd','controller_from_pack')]:
        archive.writestr(name,(ROOT/name).read_text()+f'\nvar update_fixture_marker = "{label}"\n')
manifest=directory/'http/stable/windows-x86_64/manifest.json'
if manifest.exists():
    raise FileExistsError('Fixtures already exist. Use a fresh test directory/session rather than overwrite immutable releases.')
envelope=make_release(source,directory/'http','windows-x86_64','test-1',1,private,config)
payload=json.loads(__import__('base64').b64decode(envelope['payload_base64']))
for variant in ['bad-signature','bad-hash','incompatible','wrong-platform','traversal']:
    candidate=json.loads(json.dumps(payload))
    if variant=='bad-hash':candidate['package']['sha256']='0'*64
    if variant=='incompatible':candidate['bootstrap_abi']=999
    if variant=='wrong-platform':candidate['platform']='android-arm64'
    if variant=='traversal':candidate['package']['path']='releases/../outside.zip'
    wrapped=signed_envelope(candidate,private,config['key_id'])
    if variant=='bad-signature':wrapped['signature_base64']=envelope['payload_base64']
    dest=directory/'http'/variant/'stable/windows-x86_64/manifest.json';dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(json.dumps(wrapped))
    if variant=='bad-hash':
        import shutil
        target=directory/'http'/variant/payload['package']['path'];target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(directory/'http'/payload['package']['path'],target)
for name in ['good','bad-signature','bad-hash','incompatible','wrong-platform','traversal','html-error','missing','timeout','unreachable']:
    base='http://127.0.0.1:4937/updates/'
    if name=='unreachable':base='http://127.0.0.1:4938/updates/'
    elif name!='good':base+=name+'/'
    fixture=dict(base_url=base,storage='user://validation_updates_'+name,public_key=str(public),platform_override='windows-x86_64',bundled_sequence=0,manifest_timeout=1 if name=='timeout' else 20,download_timeout=30)
    (directory/(name+'.json')).write_text(json.dumps(fixture))
print('Fixture HTTP files and configs ready:',directory)
