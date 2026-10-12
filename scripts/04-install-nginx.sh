#!/usr/bin/env bash
# Install nginx and deploy the repo config. Usage: sudo ./04-install-nginx.sh app.example.com
set -euo pipefail
DOMAIN="${1:?domain required}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
apt-get update && apt-get install -y nginx
mkdir -p /var/www/certbot /var/cache/nginx/app /etc/nginx/snippets
cp /etc/nginx/nginx.conf "/etc/nginx/nginx.conf.bak.$(date +%s)"
sed "s/app.example.com/$DOMAIN/g" "$ROOT/nginx/nginx.conf" > /etc/nginx/nginx.conf
sed "s/app.example.com/$DOMAIN/g" "$ROOT/nginx/snippets/ssl-certs.conf" > /etc/nginx/snippets/ssl-certs.conf
cp "$ROOT/nginx/snippets/ssl-selfsigned.conf" /etc/nginx/snippets/
echo "Installed. Now run 05-ssl-letsencrypt.sh OR 05-ssl-selfsigned.sh, then nginx -t."
