#!/usr/bin/env bash
# Disable password SSH auth. Run ONLY after confirming key login works.
set -euo pipefail
SRC="$(dirname "$0")/../ssh/00-hardening.conf"
install -m 644 "$SRC" /etc/ssh/sshd_config.d/00-hardening.conf
sshd -t                                   # abort on syntax error
systemctl reload ssh || systemctl reload sshd
echo "Effective settings:"
sshd -T | grep -Ei '^(passwordauthentication|permitrootlogin|pubkeyauthentication|allowusers|authenticationmethods)'
echo "Keep your current session open and test a new login."
