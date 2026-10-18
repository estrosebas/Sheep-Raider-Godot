"""GitHub Actions adapter: keep decrypted SSH credentials in temporary files only."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--bundle',required=True);args=parser.parse_args()
    for name in ('SSH_PRIVATE_KEY','SSH_KNOWN_HOSTS','SSH_HOST'):
        if not os.environ.get(name):raise RuntimeError('Missing deployment secret/variable: '+name)
    parent=Path(os.environ.get('RUNNER_TEMP',tempfile.gettempdir())).resolve()
    with tempfile.TemporaryDirectory(prefix='ralph-site-ssh-',dir=parent) as temp:
        folder=Path(temp).resolve();assert folder.parent==parent
        key=folder/'identity';known=folder/'known_hosts'
        key.write_text(os.environ['SSH_PRIVATE_KEY'].strip()+'\n',encoding='utf-8')
        known.write_text(os.environ['SSH_KNOWN_HOSTS'].strip()+'\n',encoding='utf-8')
        if os.name=='nt':
            user=os.environ['USERDOMAIN']+'\\'+os.environ['USERNAME']
            subprocess.run(['icacls',str(key),'/inheritance:r','/grant:r',user+':(R)'],check=True,stdout=subprocess.DEVNULL)
        else:key.chmod(0o600)
        subprocess.run([sys.executable,str(Path(__file__).with_name('publish_site.py')),'--bundle',args.bundle,
            '--host',os.environ['SSH_HOST'],'--identity',str(key),'--known-hosts',str(known)],check=True)

if __name__=='__main__':main()
