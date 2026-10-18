"""One-time domain-scoped service setup; asks for root password interactively."""
from getpass import getpass
from pathlib import Path
import paramiko
import shlex

ROOT=Path(__file__).resolve().parents[1]
def main():
    client=paramiko.SSHClient()
    client.load_host_keys(str(Path.home()/'.ralphwolf/vps_known_hosts'))
    client.set_missing_host_key_policy(paramiko.RejectPolicy())
    client.connect('64.181.219.10',username='root',password=getpass('VPS root password: '),look_for_keys=False,allow_agent=False,timeout=15)
    sftp=client.open_sftp()
    for source,target in [('deploy/statistics_service.py','/tmp/ralphwolf-statistics-service.py'),('deploy/ralphwolf-stats.service','/tmp/ralphwolf-stats.service'),('deploy/nginx-site.conf','/tmp/ralphwolf-stats-nginx.conf')]:sftp.put(str(ROOT/source),target)
    script='''set -eu
getent passwd ralphstats >/dev/null || useradd --system --home /var/lib/ralphwolf-stats --shell /usr/sbin/nologin ralphstats
usermod -a -G ralphstats ralphdeploy
install -d -m 0755 /opt/ralphwolf-stats
install -m 0644 /tmp/ralphwolf-statistics-service.py /opt/ralphwolf-stats/statistics_service.py
install -m 0644 /tmp/ralphwolf-stats.service /etc/systemd/system/ralphwolf-stats.service
systemctl daemon-reload
systemctl enable --now ralphwolf-stats
systemctl restart ralphwolf-stats
install -d -m 0700 /var/backups/ralphwolf/statistics
for name in nginx.conf_ralphwolf nginx.ssl.conf_ralphwolf; do
 target=/home/noox/conf/web/sheepraider.nooxtools.me/$name
 if test -f "$target.before-statistics"; then mv "$target.before-statistics" /var/backups/ralphwolf/statistics/$name; fi
 if ! test -f /var/backups/ralphwolf/statistics/$name; then cp "$target" /var/backups/ralphwolf/statistics/$name; fi
 install -m 0644 /tmp/ralphwolf-stats-nginx.conf "$target"
done
nginx -t
systemctl reload nginx
systemctl is-active ralphwolf-stats
'''
    _,out,err=client.exec_command('sh -c '+shlex.quote(script))
    print(out.read().decode());errors=err.read().decode()
    if out.channel.recv_exit_status():raise RuntimeError(errors)
    print('Statistics service and domain route installed.')
    sftp.close();client.close()

if __name__=='__main__':main()
