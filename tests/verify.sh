#!/usr/bin/env bash
# Verification checks. Usage: ./verify.sh app.example.com [target_ip]
DOMAIN="${1:-app.example.com}"; HOST="${2:-127.0.0.1}"
R="--resolve $DOMAIN:443:$HOST --resolve $DOMAIN:80:$HOST -k -s"
echo "== 1. HTTP redirects to HTTPS";  curl $R -o /dev/null -w '%{http_code} -> %{redirect_url}\n' "http://$DOMAIN/"
echo "== 2. TLS protocol";             curl $R -v -o /dev/null "https://$DOMAIN/" 2>&1 | grep 'SSL connection'
echo "== 3. Security headers";         curl $R -I "https://$DOMAIN/" | grep -iE 'strict-transport|x-content-type|x-frame|^server'
echo "== 4. Gzip";                     curl $R -H 'Accept-Encoding: gzip' -D - -o /dev/null "https://$DOMAIN/static/app.css" | grep -i content-encoding
echo "== 5. Cache headers (/static)";  curl $R -I "https://$DOMAIN/static/app.css" | grep -iE 'cache-control|expires|x-cache'
echo "== 6. Rate limit (expect 429s)"; for i in $(seq 1 40); do curl $R -o /dev/null -w '%{http_code}\n' "https://$DOMAIN/api/data"; done | sort | uniq -c
