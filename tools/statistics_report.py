"""Read the owner's aggregate counters over pinned SSH. No public admin API."""
import json
from pathlib import Path
import paramiko

def main():
    private=Path.home()/'.ralphwolf'
    client=paramiko.SSHClient()
    client.load_host_keys(str(private/'vps_known_hosts'))
    client.set_missing_host_key_policy(paramiko.RejectPolicy())
    client.connect('64.181.219.10',username='ralphdeploy',key_filename=str(private/'vps-deploy-ed25519'),look_for_keys=False,allow_agent=False,timeout=15)
    _,stdout,stderr=client.exec_command('python3 /opt/ralphwolf-stats/statistics_service.py --report')
    text=stdout.read().decode()
    if stdout.channel.recv_exit_status():raise RuntimeError(stderr.read().decode())
    client.close()
    rows=json.loads(text)
    print('UTC day     event      platform version            count')
    for row in rows:print(f"{row['day']}  {row['kind']:<10} {row['platform']:<8} {row['version']:<18} {row['total']}")
    if not rows:print('No consented events yet.')

if __name__=='__main__':main()
