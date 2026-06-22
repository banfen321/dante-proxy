# dante-proxy

[![Docker Hub](https://img.shields.io/docker/pulls/banfen321/dante-proxy)](https://hub.docker.com/r/banfen321/dante-proxy)
[![Build](https://github.com/banfen321/dante-proxy/actions/workflows/docker.yml/badge.svg)](https://github.com/banfen321/dante-proxy/actions/workflows/docker.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Production-ready SOCKS5 proxy in Docker — zero config, runs in 30 seconds.**

Drop it on any VPS and get a private SOCKS5 proxy with strong password auth,
optional TLS encryption, and an optional IP allowlist. No files to edit —
the container auto-detects your network interface and generates a 24-character
password on first start.

Built on [Dante](https://www.inet.no/dante/) — the most battle-tested open-source
SOCKS5 server, written in C, maintained since 1997. Dante 1.4.4 patches
**CVE-2024-54662** (affected 1.4.0–1.4.3).

Inspired by [adegtyarev/docker-dante](https://github.com/adegtyarev/docker-dante).

---

## How it works

### Standard mode (default)

```
┌─────────────┐   SOCKS5 + user:pass   ┌──────────────────────┐              ┌──────────────┐
│  Your app   │ ──────────────────────► │  VPS : Dante :1080   │ ──────────►  │   Internet   │
└─────────────┘      (plaintext)        │  auth: username/PAM  │              └──────────────┘
                                        └──────────────────────┘
```

Password and traffic travel in plaintext. Good for trusted networks or
when you encrypt at the application layer (HTTPS).

### TLS mode (`--profile tls`)

```
┌──────────────────────────────┐         ┌────────────────────────────────────────────────────┐
│         Your machine         │         │                      VPS                           │
│                              │         │                                                    │
│  ┌──────────┐   SOCKS5       │         │  ┌─────────────────┐  SOCKS5  ┌────────────────┐  │
│  │ Your app │ ──────────►    │         │  │ stunnel :1080   │ ───────► │  Dante :1081   │  │
│  └──────────┘               │   TLS   │  │ (TLS terminator)│ loopback │ 127.0.0.1 only │  │
│       │                     │ ───────►│  └─────────────────┘          └────────────────┘  │
│  ┌──────────────────────┐   │         │                                        │           │
│  │ stunnel (local)      │   │         └────────────────────────────────────────┼───────────┘
│  │ localhost:1080 → TLS │   │                                                  │
│  └──────────────────────┘   │                                            ┌──────────────┐
└──────────────────────────────┘                                            │   Internet   │
                                                                            └──────────────┘
```

Dante is bound to `127.0.0.1` only — not reachable from outside.
stunnel terminates TLS on the public port; credentials and traffic are encrypted end-to-end.
A self-signed certificate is auto-generated on first start.

---

## Quick start

**1. Open the port on your server**

```bash
sudo ufw allow 1080/tcp
```

> **Cloud servers** (Oracle Cloud, AWS, GCP, Hetzner) — also open the port in the cloud
> control panel. See [Cloud firewall](#cloud-firewall) below.

**2. Clone and run**

```bash
git clone https://github.com/banfen321/dante-proxy.git
cd dante-proxy
docker compose up -d
```

**3. Get your credentials**

```bash
docker compose logs dante
```

Connect with the username and password printed in the logs. Done.

---

## Connecting

```bash
# Quick test
curl --socks5-hostname user:password@<HOST>:1080 https://ifconfig.me

# System-wide (Linux / macOS)
export ALL_PROXY=socks5h://user:password@<HOST>:1080
```

**Firefox:** Settings → Network Settings → Manual proxy →
SOCKS5 Host: `<HOST>`, Port: `1080`. Enable *Proxy DNS when using SOCKS5*.

---

## Configuration

Copy `.env.example` to `.env` and edit. All variables are optional —
defaults are shown below.

```bash
cp .env.example .env
docker compose up -d
```

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `SOCKD_PORT` | `1080` | Port Dante listens on |
| `SOCKD_BIND_ADDR` | `0.0.0.0` | Address Dante binds to. Set to `127.0.0.1` in TLS mode |
| `SOCKD_USER_NAME` | `proxy` | Proxy username |
| `SOCKD_USER_PASSWORD` | *(auto-generated)* | Proxy password. Auto-generated (24 chars) if not set |
| `SOCKD_EXTERNAL_IFACE` | *(auto-detected)* | Network interface for outbound traffic |
| `SOCKD_ALLOW_IPS` | `0.0.0.0/0` | Allowed client CIDR. Set to your IP for best security |
| `STUNNEL_PORT` | `1080` | Public TLS port (TLS mode only) |

---

## TLS mode

Enable the stunnel wrapper to encrypt credentials and traffic in transit.

**Server:**

```bash
# .env
SOCKD_BIND_ADDR=127.0.0.1   # dante on localhost only — not reachable directly
SOCKD_PORT=1081              # internal port
STUNNEL_PORT=1080            # public TLS port

docker compose --profile tls up -d
```

A self-signed certificate is generated on first start and stored in a Docker volume.
To use your own certificate, mount `server.pem` (full chain) and `server.key` at
`/etc/stunnel/certs/`.

**Client (stunnel):**

```bash
# /etc/stunnel/client.conf
[socks5-tls]
client  = yes
accept  = 127.0.0.1:1080
connect = <HOST>:1080

stunnel /etc/stunnel/client.conf

# connect via local plaintext endpoint:
curl --socks5-hostname user:password@127.0.0.1:1080 https://ifconfig.me
```

---

## IP allowlist

Restrict which client IPs can reach the proxy at the protocol level:

```env
# .env — only your IP can connect
SOCKD_ALLOW_IPS=203.0.113.42/32
```

Default is `0.0.0.0/0` — any IP can attempt authentication.
For multiple allowed IPs, combine with an upstream firewall rule.

---

## Management

```bash
docker compose logs -f dante        # live connection log
docker compose restart              # restart
docker compose pull && \
  docker compose up -d              # update to latest image
docker compose down                 # stop and remove containers
```

---

## Cloud firewall

OS-level firewall alone is not enough on cloud servers.
Open the port in the cloud control panel too.

### Oracle Cloud

**OCI Console → Networking → VCN → Security Lists → Default → Add Ingress Rule**

| Source CIDR | Protocol | Port | Description |
|---|---|---|---|
| `0.0.0.0/0` | TCP | `1080` | dante-proxy |

### AWS

**EC2 → Security Groups → Inbound rules → Add rule**

| Type | Protocol | Port | Source |
|---|---|---|---|
| Custom TCP | TCP | `1080` | `0.0.0.0/0` |

### Hetzner

**Firewall → Inbound rules → Add rule** — TCP port `1080`, source `0.0.0.0/0`.

---

## Security

### What's protected

| Control | Status | Notes |
|---|---|---|
| Password auth | ✅ always on | PAM-backed, anon access disabled |
| No root at runtime | ✅ always on | All processes run as `nobody` |
| Minimal container | ✅ always on | Alpine, multi-stage build, no compiler in final image |
| CVE-2024-54662 | ✅ patched | Fixed in Dante 1.4.4 |
| Capability drop | ✅ always on | `cap_drop: ALL`, only `SETUID`/`SETGID` added |
| `no-new-privileges` | ✅ always on | `security_opt: no-new-privileges:true` |
| TLS encryption | ⚙️ opt-in | `--profile tls` — see [TLS mode](#tls-mode) |
| IP allowlist | ⚙️ opt-in | `SOCKD_ALLOW_IPS` — see [IP allowlist](#ip-allowlist) |

### Recommended production setup

For a public VPS, use all three layers together:

```env
SOCKD_BIND_ADDR=127.0.0.1
SOCKD_PORT=1081
STUNNEL_PORT=1080
SOCKD_ALLOW_IPS=<your-ip>/32
SOCKD_USER_PASSWORD=<strong-password>
```

```bash
docker compose --profile tls up -d
```

This gives you: TLS (traffic encrypted) + IP allowlist (limits who can try) + strong password (auth gate).

---

## Repository structure

```
dante-proxy/
├── Dockerfile            # Multi-stage: builds Dante from source on Alpine
├── entrypoint.sh         # Generates config + PAM user at container start
├── sockd.conf.tmpl       # Dante config template (vars substituted at runtime)
├── docker-compose.yaml   # Dante service + optional stunnel (--profile tls)
├── setup.sh              # Interactive .env generator
├── .env.example          # All available variables with defaults
└── stunnel/
    ├── Dockerfile        # Alpine + stunnel + openssl
    ├── entrypoint.sh     # Auto-generates TLS cert, starts stunnel
    └── stunnel.conf.tmpl # stunnel config template
```

---

## License

MIT — see [LICENSE](LICENSE).
