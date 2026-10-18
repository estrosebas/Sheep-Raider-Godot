"""Deploy a verified distribution over SSH; activate links only after upload checks."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shlex
import shutil
import subprocess
import uuid
import paramiko

ROOT='/home/noox/web/sheepraider.nooxtools.me/public_html'
SITE='/home/noox/web/sheepraider.nooxtools.me'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle',type=Path,required=True)
    parser.add_argument('--host',required=True,help='deployment-user@server')
    parser.add_argument('--identity',type=Path,required=True)
    parser.add_argument('--known-hosts',type=Path,required=True)
    args=parser.parse_args()
    user,host=args.host.split('@',1)
    manifest=json.loads((args.bundle/'bundle.json').read_text())
    for entry in manifest['files']:
        relative=entry['path']
        if not re.fullmatch('[A-Za-z0-9_./-]+',relative) or '..' in relative or PurePosixPath(relative).is_absolute():raise ValueError('Unsafe path')
        if relative.split('/')[0] not in ('site','play','downloads'):raise ValueError('Unknown bundle directory')
        with (args.bundle/relative).open('rb') as stream:
            if hashlib.file_digest(stream,'sha256').hexdigest()!=entry['sha256']:raise ValueError('Local file changed: '+relative)
    client=paramiko.SSHClient();client.load_host_keys(str(args.known_hosts));client.set_missing_host_key_policy(paramiko.RejectPolicy())
    client.connect(host,username=user,key_filename=str(args.identity),allow_agent=False,look_for_keys=False,timeout=30)
    def command(script):
        _,out,err=client.exec_command('set -eu; '+script,timeout=120)
        result=out.read().decode();errors=err.read().decode()
        if out.channel.recv_exit_status():raise RuntimeError(errors or result or 'Remote command failed')
        return result
    q=shlex.quote
    stage=SITE+'/deployments/'+manifest['version']+'-'+uuid.uuid4().hex[:12]
    if not re.fullmatch('[A-Za-z0-9_.-]+',manifest['version']) or '..' in manifest['version']:raise ValueError('Invalid version')
    directories={str(PurePosixPath(stage)/PurePosixPath(x['path']).parent) for x in manifest['files']}
    command('mkdir -p '+' '.join(q(x) for x in sorted(directories)))
    print('Uploading independent staging release...',flush=True)
    def upload(entry):
        # Native OpenSSH avoids Paramiko's high-latency throughput bottleneck
        # for the large PCK/APK/ZIP files; small website files use SFTP directly.
        if entry['bytes']>1048576 and shutil.which('scp'):
            result=subprocess.run(['scp','-B','-q','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes',
                '-o','UserKnownHostsFile='+str(args.known_hosts.resolve()),'-i',str(args.identity.resolve()),
                str((args.bundle/entry['path']).resolve()),args.host+':'+stage+'/'+entry['path']],
                capture_output=True,text=True,timeout=1800)
            if result.returncode:raise RuntimeError('Upload failed for '+entry['path']+': '+result.stderr)
            return
        sftp=paramiko.SFTPClient.from_transport(client.get_transport(),window_size=16*1048576,max_packet_size=1048576)
        try:sftp.put(str(args.bundle/entry['path']),stage+'/'+entry['path'])
        finally:sftp.close()
    with ThreadPoolExecutor(max_workers=3) as pool:list(pool.map(upload,manifest['files']))
    result=command('sha256sum '+' '.join(q(stage+'/'+x['path']) for x in manifest['files']))
    hashes={row.split(None,1)[1].strip():row.split(None,1)[0] for row in result.splitlines()}
    if any(hashes.get(stage+'/'+x['path'])!=x['sha256'] for x in manifest['files']):raise ValueError('Remote checksum mismatch; current site unchanged')
    print('All uploaded hashes verified.',flush=True)
    # Versioned installers are immutable. Validate all conflicts before activation.
    installers=[x for x in manifest['files'] if x['path'].startswith('downloads/') and x['path']!='downloads/latest.json']
    for entry in installers:
        path=ROOT+'/'+entry['path']
        existing=command('if test -f '+q(path)+'; then sha256sum '+q(path)+'; fi').strip()
        if existing and existing.split()[0]!=entry['sha256']:raise ValueError('Installer version already published with different bytes: '+entry['path'])
    for entry in installers:
        path=ROOT+'/'+entry['path']
        command('mkdir -p '+q(str(PurePosixPath(path).parent))+'; if ! test -f '+q(path)+'; then mv '+q(stage+'/'+entry['path'])+' '+q(path)+'; fi')
    # Existing releases stay on disk, so links can be restored if needed.
    sftp=client.open_sftp();previous={}
    categories={entry['path'].split('/')[0] for entry in manifest['files']}
    links=[]
    if 'play' in categories:links.append(('play',stage+'/play'))
    if 'site' in categories:links.append(('site-assets',stage+'/site/site-assets'))
    for name,target in links:
        link=ROOT+'/'+name
        try:previous[name]=sftp.readlink(link)
        except IOError:previous[name]=None
        command('if test -d '+q(link)+' && ! test -L '+q(link)+'; then rmdir '+q(link)+'; fi')
        temporary=link+'.next-'+uuid.uuid4().hex[:8]
        sftp.symlink(target,temporary)
        command('mv -Tf '+q(temporary)+' '+q(link))
    with sftp.file(stage+'/previous-links.json','w') as stream:stream.write(json.dumps(previous))
    pointers=[]
    if 'downloads' in categories:pointers.append((stage+'/downloads/latest.json',ROOT+'/downloads/latest.json'))
    if 'site' in categories:pointers.append((stage+'/site/index.html',ROOT+'/index.html'))
    for source,target in pointers:
        command('cp '+q(source)+' '+q(target+'.next')+'; chmod 0644 '+q(target+'.next')+'; mv -f '+q(target+'.next')+' '+q(target))
    sftp.close()
    print('Published: https://sheepraider.nooxtools.me/ and /play/',flush=True)
    print('Remote release retained for rollback: '+stage,flush=True)
    client.close()

if __name__=='__main__':main()
