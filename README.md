# Secure Linux + Nginx Reverse Proxy

Hardened Ubuntu server: key-only SSH, default-deny UFW firewall (22/80/443), and an
Nginx reverse proxy with TLS, gzip, cache headers, proxy caching, and rate limiting.

```
Internet ──► UFW (22, 80, 443 only)
               ├─ :22  ──► sshd  (public-key auth only, user "deploy")
               ├─ :80  ──► nginx ──► 301 redirect to HTTPS (+ ACME challenge)
               └─ :443 ──► nginx (TLS 1.2/1.3, gzip, cache, rate limit)
                              └──► app on 127.0.0.1:3000 (not exposed publicly)
```

Tested on Ubuntu 24.04 / Nginx 1.24. Replace `app.example.com` and the backend port as needed.

## Repository layout

| Path | Purpose |
|---|---|
| `nginx/nginx.conf` | Main deliverable: full reverse-proxy config |
| `nginx/snippets/` | Cert path includes (Let's Encrypt / self-signed) |
| `ssh/00-hardening.conf` | sshd drop-in: disable passwords and root login |
| `scripts/01..05-*.sh` | Ordered setup scripts |
| `tests/verify.sh` | Checks for redirect, TLS, headers, gzip, cache, rate limit |
| `docs/` | Captured proof output from the sandbox run |

## Setup, in order

> **Lockout warning:** keep your original SSH session open until you've confirmed
> key login works from a second terminal. Also keep a cloud-console / recovery path handy.

### 1. User and SSH key
On your laptop: `ssh-keygen -t ed25519 -C "you@laptop"`, then on the server:
```bash
sudo ./scripts/01-create-user.sh deploy "$(cat ~/.ssh/id_ed25519.pub)"   # paste the key text
ssh deploy@SERVER_IP        # <-- test in a NEW terminal before continuing
```

### 2. Disable password SSH
```bash
sudo ./scripts/02-harden-ssh.sh
```
Installs `ssh/00-hardening.conf` into `/etc/ssh/sshd_config.d/`, validates with `sshd -t`, reloads.
Why `00-`? sshd takes the **first** value it reads; cloud images often ship
`50-cloud-init.conf` with `PasswordAuthentication yes`, which would override a later-named file.

Key settings: `PasswordAuthentication no`, `KbdInteractiveAuthentication no`,
`PermitRootLogin no`, `AuthenticationMethods publickey`, `AllowUsers deploy`, `MaxAuthTries 3`.

Verify:
```bash
sudo sshd -T | grep -E 'passwordauthentication|permitrootlogin'
ssh -o PubkeyAuthentication=no deploy@SERVER_IP    # expect: Permission denied (publickey)
```

### 3. Firewall (UFW)
```bash
sudo ./scripts/03-ufw.sh
```
| Rule | Notes |
|---|---|
| default deny incoming / allow outgoing | everything not listed is dropped |
| `limit 22/tcp` | SSH open, with built-in brute-force throttling (6 conns / 30 s / IP) |
| `allow 80/tcp`, `allow 443/tcp` | HTTP (redirect + ACME), HTTPS |

Verify: `sudo ufw status verbose`, and from another machine `nmap -Pn -p 1-1000 SERVER_IP`
should show only 22, 80, 443. The app port 3000 is bound to localhost and also blocked by UFW.

### 4. Nginx reverse proxy
```bash
sudo ./scripts/04-install-nginx.sh app.example.com
```
Features in `nginx/nginx.conf`:

| Feature | Implementation |
|---|---|
| Reverse proxy | `upstream app_backend` to `127.0.0.1:3000` with keepalive; `X-Forwarded-*` headers |
| Gzip | `gzip on`, level 5, min 256 B, text/JSON/JS/CSS/SVG types |
| Cache headers | `/static/`: `Cache-Control: public, max-age=2592000, immutable`; `/api/`: `no-store`; `/`: `no-cache` |
| Proxy cache | 500 MB `app_cache` on `/static/`, serves stale on backend errors; `X-Cache-Status` header |
| Rate limiting | `general` 10 r/s (burst 20), `api` 5 r/s (burst 10), 20 concurrent connections/IP; returns **429** |
| Hardening | `server_tokens off`, HSTS, `nosniff`, `X-Frame-Options`, dotfiles blocked, request timeouts |

Note: nginx drops server-level `add_header` directives in any `location` that defines its own,
so security headers are repeated per location on purpose.

### 5. TLS

**Production: Let's Encrypt** (needs public DNS A record + ports 80/443 reachable):
```bash
sudo ./scripts/05-ssl-letsencrypt.sh app.example.com admin@example.com
```
Bootstraps with a temporary self-signed cert, obtains the real cert via webroot
(`/.well-known/acme-challenge/`), swaps the cert path, adds a reload-on-renew hook and runs
`certbot renew --dry-run`. Renewal is handled by certbot's systemd timer
(`systemctl list-timers | grep certbot`).

**Sandbox: self-signed** (browser warning expected):
```bash
sudo ./scripts/05-ssl-selfsigned.sh app.example.com && sudo nginx -t && sudo systemctl reload nginx
```

## Verification

```bash
./tests/verify.sh app.example.com SERVER_IP
```
Sandbox results are saved in `docs/verify-output-sandbox.txt` and `docs/nginx-t-output.txt`:

| Check | Result |
|---|---|
| `nginx -t` | syntax ok / test successful |
| HTTP to HTTPS | `301 -> https://app.example.com/` |
| TLS | TLSv1.3 negotiated |
| Headers | HSTS, nosniff, X-Frame-Options present; version hidden (`server: nginx`) |
| Gzip | `content-encoding: gzip` |
| Static caching | `cache-control: public, max-age=2592000, immutable`, `x-cache-status: HIT` |
| Rate limit | 40 rapid API requests: 12 x 200, 28 x 429 |

Not exercised in the sandbox (no systemd/ufw/sshd/public DNS): UFW rules, sshd reload, and the
Let's Encrypt issuance. Run the verification commands in steps 2, 3, and 5 on a real host.
The sandbox also lacked IPv6, so the `listen [::]` lines were removed for that test only.

## Rollback
- SSH: `sudo rm /etc/ssh/sshd_config.d/00-hardening.conf && sudo systemctl reload ssh`
- Firewall: `sudo ufw disable`
- Nginx: restore `/etc/nginx/nginx.conf.bak.*` and `sudo systemctl reload nginx`

## Possible next steps
fail2ban for sshd, `unattended-upgrades`, a Content-Security-Policy tailored to your app,
and restricting `NOPASSWD` sudo to specific commands.
