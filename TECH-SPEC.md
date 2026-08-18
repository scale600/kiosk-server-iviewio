# TECH-SPEC — kiosk-server-iviewio

> Kiosk web server running on GCP e2-micro (free tier) with Blazor Server (.NET 8), MudBlazor UI, and Caddy for TLS termination.

**Last Updated:** 2026-05-19

---

## Architecture

```
Internet → kiosk1.iviewio.com (HTTPS)
         → Caddy (TLS, Let's Encrypt)
         → Kestrel :5000 (Blazor Server)
         → GCP e2-micro VM (Ubuntu 22.04, 1GB RAM)
```

---

## Infrastructure

| Item | Value |
|------|-------|
| Cloud | GCP Free Tier |
| VM | e2-micro (2 vCPU burst, 1GB RAM, 30GB disk) |
| OS | Ubuntu 22.04 LTS |
| Zone | us-central1-a |
| External IP | <VM_EXTERNAL_IP> |
| Domain | kiosk1.iviewio.com |

---

## App Stack

| Item | Value |
|------|-------|
| Framework | Blazor Server (.NET 8) |
| UI | MudBlazor 8.14.0 |
| Logging | Serilog (file + journald) |
| Port | 5000 (localhost only) |
| Process management | systemd (`kiosk-server.service`) |
| Reverse proxy | Caddy (HTTPS, Let's Encrypt auto-renew) |

---

## Memory Management (zram)

zram swap is used to prevent OOM in a 1 GB RAM environment.

```
zram0: 512 MiB (zstd compressed), priority 100
swappiness: 100 (use zram aggressively)
```

---

## Main Pages

| Path | Description |
|------|-------------|
| `/` | Index (redirects to kiosk) |
| `/kiosk` | Displays URL in iframe (kiosk screen) |
| `/setup` | URL management, reboot/shutdown, system info |

---

## API Endpoints

| Endpoint | Description |
|-----------|-------------|
| `GET /api/status` | CPU, memory, disk, temperature |
| `POST /api/reboot` | Reboot |
| `POST /api/shutdown` | Shutdown |
| `POST /api/navigatetourl?url=` | Change kiosk iframe URL |
| `POST /api/screenon/off` | Screen on/off (for Pi) |

---

## Deployment

```bash
# Build (local)
dotnet publish -c Release -r linux-x64 --self-contained false

# Copy to VM
rsync -av ./publish/ user@<VM_EXTERNAL_IP>:/opt/kiosk-server/

# Restart
sudo systemctl restart kiosk-server
```

---

## Security Status

| Item | Status |
|------|--------|
| HTTPS (Let's Encrypt) | ✅ |
| Kestrel localhost binding | ✅ |
| systemd non-root execution | ✅ |
| /setup auth | ❌ not implemented |
| API auth | ❌ not implemented (shutdown etc. exposed) |
| systemd MemoryMax | ❌ not set |
