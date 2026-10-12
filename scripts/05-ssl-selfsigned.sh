#!/usr/bin/env bash
# Sandbox TLS: self-signed cert. Usage: sudo ./05-ssl-selfsigned.sh [domain]
set -euo pipefail
DOMAIN="${1:-app.example.com}"
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout /etc/nginx/ssl/selfsigned.key -out /etc/nginx/ssl/selfsigned.crt \
  -subj "/CN=$DOMAIN" -addext "subjectAltName=DNS:$DOMAIN"
chmod 600 /etc/nginx/ssl/selfsigned.key
if [ -f /etc/nginx/snippets/ssl-selfsigned.conf ]; then
  cp /etc/nginx/snippets/ssl-selfsigned.conf /etc/nginx/snippets/ssl-certs.conf
fi
echo "Self-signed cert created. Run: nginx -t && systemctl reload nginx"
