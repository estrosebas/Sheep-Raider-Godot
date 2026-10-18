#!/usr/bin/env bash
# Root-only initial provisioning. Arguments are a PUBLIC SSH key and nginx snippet.
set -euo pipefail
[[ $(id -u) == 0 ]] || { echo 'Run initial provisioning as root'; exit 1; }
domain=sheepraider.nooxtools.me
site=/home/noox/web/$domain
conf=/home/noox/conf/web/$domain
web=$site/public_html
[[ -d $web && -f $conf/nginx.ssl.conf && -f $1 && -f $2 ]]
command -v setfacl >/dev/null
backup=/var/backups/ralphwolf/$(date -u +%Y%m%dT%H%M%SZ)
install -d -m 0700 "$backup"
tar -C "$web" -cf "$backup/public_html.tar" .
cp -a "$conf/nginx.conf" "$conf/nginx.ssl.conf" "$backup/"
if ! id ralphdeploy >/dev/null 2>&1; then
    useradd --create-home --home-dir /var/lib/ralphdeploy --shell /bin/sh ralphdeploy
fi
[[ $(getent passwd ralphdeploy | cut -d: -f6) == /var/lib/ralphdeploy ]]
install -d -o ralphdeploy -g ralphdeploy -m 0700 /var/lib/ralphdeploy/.ssh
authorized=/var/lib/ralphdeploy/.ssh/authorized_keys
touch "$authorized"
public=$(cat "$1")
if ! grep -Fq "$public" "$authorized"; then printf 'restrict %s\n' "$public" >> "$authorized"; fi
chown ralphdeploy:ralphdeploy "$authorized"
chmod 0600 "$authorized"
setfacl -m u:ralphdeploy:--x /home/noox /home/noox/web "$site"
setfacl -m u:ralphdeploy:rwx "$web"
for directory in "$web/downloads" "$web/updates" "$web/site-assets" "$site/deployments" "$site/source"; do
    install -d -o ralphdeploy -g www-data -m 0755 "$directory"
done
# New isolated snippets, so a Hestia rebuild keeps this domain's routes.
for name in nginx.conf_ralphwolf nginx.ssl.conf_ralphwolf; do
    if [[ -f $conf/$name ]]; then cp -a "$conf/$name" "$backup/$name"; fi
    install -o root -g noox -m 0644 "$2" "$conf/$name"
done
if ! nginx -t; then
    for name in nginx.conf_ralphwolf nginx.ssl.conf_ralphwolf; do
        if [[ -f $backup/$name ]]; then cp -a "$backup/$name" "$conf/$name"; else rm -f -- "$conf/$name"; fi
    done
    echo 'Configuration rejected; previous snippets restored'; exit 1
fi
systemctl reload nginx
printf 'Provisioned %s; previous site preserved at %s\n' "$domain" "$backup"
