#!/usr/bin/env bash
# Default-deny firewall; only 22, 80, 443 open.
set -euo pipefail
apt-get install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw limit 22/tcp comment 'SSH (rate-limited: 6 conns/30s per IP)'
ufw allow 80/tcp  comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw logging low
ufw --force enable
ufw status verbose
