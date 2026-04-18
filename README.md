# dante-proxy

[![Docker Hub](https://img.shields.io/docker/pulls/banfen321/dante-proxy)](https://hub.docker.com/r/banfen321/dante-proxy)
[![Build](https://github.com/banfen321/dante-proxy/actions/workflows/docker.yml/badge.svg)](https://github.com/banfen321/dante-proxy/actions/workflows/docker.yml)

**Production-ready SOCKS5 proxy in Docker — just clone and run.**

Zero config required: the container auto-detects your network interface and generates
a strong password on first start. No files to edit, no manual setup.

Built on [Dante](https://www.inet.no/dante/) — the most battle-tested open-source SOCKS5 server,
written in C, maintained since 1997. Updated to the latest version with all known CVEs patched.
All processes run as `nobody` — no root inside the container at runtime.

Inspired by [adegtyarev/docker-dante](https://github.com/adegtyarev/docker-dante).

---

## Get started

**1. Open the port on your server**

```bash
sudo ufw allow 1080/tcp
```

> **Cloud servers** (Oracle Cloud, AWS, GCP, Hetzner) — you also need to open the port
> in the cloud control panel. See the [Cloud firewall](#cloud-firewall) section below.

**2. Clone and run**

```bash
git clone https://github.com/banfen321/dante-proxy.git && \
cd dante-proxy && \
docker compose up -d
```

**3. Get your credentials**

```bash
docker compose logs dante
```

Done. Connect with the username and password printed in the logs.

---

## Configuration

Create a `.env` file to set your own values (optional — everything works without it):

```bash
cp .env.example .env
```

```env
SOCKD_PORT=1080
SOCKD_USER_NAME=proxy
SOCKD_USER_PASSWORD=your-password
SOCKD_EXTERNAL_IFACE=        # leave empty — auto-detected
```

Then restart:

```bash
docker compose up -d
```

---

## Connecting

```bash
# Test
curl --socks5-hostname user:password@<HOST>:1080 https://ifconfig.me

# System-wide
export ALL_PROXY=socks5h://user:password@<HOST>:1080
```

**Firefox:** Settings → Network → Manual proxy → SOCKS5, host `<HOST>`, port `1080`.  
Enable *Proxy DNS when using SOCKS5*.

---

## Cloud firewall

Opening the port in your OS firewall is not enough on cloud servers — you also need
to allow the port in the cloud provider's firewall / security group.

### Oracle Cloud — Security List

Go to: **OCI Console → Networking → Virtual Cloud Networks → your VCN → Security Lists → Default Security List → Add Ingress Rules**

| Field | Value |
|---|---|
| Source Type | CIDR |
| Source CIDR | `0.0.0.0/0` |
| IP Protocol | **TCP** |
| Destination Port Range | `1080` |
| Description | dante-proxy |

> SOCKS5 uses **TCP only**. No UDP rule needed.

### AWS — Security Group

Go to: **EC2 → Security Groups → your group → Inbound rules → Add rule**

| Type | Protocol | Port | Source |
|---|---|---|---|
| Custom TCP | TCP | 1080 | 0.0.0.0/0 |

### Hetzner — Firewall

Go to: **Firewall → Inbound rules → Add rule**

| Protocol | Port | Source |
|---|---|---|
| TCP | 1080 | 0.0.0.0/0 |

---

## Management

```bash
docker compose logs -f          # live logs with connection activity
docker compose restart          # restart
docker compose pull && \
docker compose up -d            # update to latest image
docker compose down             # stop
```

---

## Security

- Alpine 3.21 minimal base
- Dante 1.4.4 — patches **CVE-2024-54662** (affected 1.4.0–1.4.3)
- Multi-stage build — compiler and build tools not in final image
- All processes run as **`nobody`** — no root at runtime
- All capabilities dropped except `SETUID`/`SETGID`
- `no-new-privileges:true`
- Authentication required — anonymous access disabled
- `network_mode: host` — required for correct routing on cloud servers (Oracle, Hetzner)

