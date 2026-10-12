#!/usr/bin/env bash
# Production TLS via Let's Encrypt (needs public DNS pointing here + ports 80/443 open).
# Usage: sudo ./05-ssl-letsencrypt.sh app.example.com admin@example.com
set -euo pipefail
DOMAIN="${1:?domain}"; EMAIL="${2:?email}"
apt-get install -y certbot
# Bootstrap with a temporary self-signed cert so nginx can start with the 443 block.
"$(dirname "$0")/05-ssl-selfsigned.sh" "$DOMAIN"
nginx -t && systemctl reload nginx

certbot certonly --webroot -w /var/www/certbot -d "$DOMAIN" \
  --email "$EMAIL" --agree-tos --no-eff-email --non-interactive

# Switch to the real certificate
cat > /etc/nginx/snippets/ssl-certs.conf <<CONF
ssl_certificate     /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
ssl_stapling on;
ssl_stapling_verify on;
CONF
nginx -t && systemctl reload nginx

# certbot installs a systemd renewal timer; this hook reloads nginx after renewals
install -d /etc/letsencrypt/renewal-hooks/deploy
printf '#!/bin/sh\nsystemctl reload nginx\n' > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
certbot renew --dry-run
