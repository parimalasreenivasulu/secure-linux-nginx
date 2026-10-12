#!/usr/bin/env bash
# Create a non-root sudo user and install their SSH public key.
# Usage: sudo ./01-create-user.sh deploy "ssh-ed25519 AAAA... you@laptop"
# NOTE: ssh/00-hardening.conf has "AllowUsers deploy"; edit it if you use another name.
set -euo pipefail
USER_NAME="${1:?username required}"
PUBKEY="${2:?public key string required}"

id "$USER_NAME" &>/dev/null || adduser --disabled-password --gecos "" "$USER_NAME"
usermod -aG sudo "$USER_NAME"

install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/.ssh"
AUTH="/home/$USER_NAME/.ssh/authorized_keys"
touch "$AUTH"
grep -qxF "$PUBKEY" "$AUTH" || echo "$PUBKEY" >> "$AUTH"
chown "$USER_NAME:$USER_NAME" "$AUTH"; chmod 600 "$AUTH"

# The account has no password, so sudo must be passwordless.
# Restrict to specific commands for stricter production setups.
echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$USER_NAME"
chmod 440 "/etc/sudoers.d/90-$USER_NAME"
visudo -cf "/etc/sudoers.d/90-$USER_NAME"
echo "User $USER_NAME ready. TEST key login in a NEW terminal before continuing."
