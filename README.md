# kiosk-server-iviewio

Touch-screen kiosk web server with multi-platform remote control, deployed on the Google Cloud Platform free tier. Built on **Blazor Server (.NET 8)** with a **MudBlazor** UI, served over HTTPS via **Caddy**, and operated as a **systemd** service with **zram** swap for stable operation within 1 GB of RAM.

- **Domain:** `https://kiosk1.iviewio.com`
- **VM:** `kiosk-server-vm` (GCP e2-micro, `us-central1-a`)

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Tech Stack](#tech-stack)
4. [Directory Structure](#directory-structure)
5. [Prerequisites](#prerequisites)
6. [Local Development](#local-development)
7. [Configuration](#configuration)
8. [Pages & Routes](#pages--routes)
9. [REST API](#rest-api)
10. [Deployment](#deployment)
11. [Infrastructure](#infrastructure)
12. [Security Notes](#security-notes)
13. [Operations & Maintenance](#operations--maintenance)
14. [Related Documents](#related-documents)

---

## Overview

This project hosts [mhwlng/kiosk-server](https://github.com/mhwlng/kiosk-server) — a Blazor Server application originally designed for Raspberry Pi touch displays — on a GCP free-tier VM. It provides:

- A **kiosk display** (`/kiosk`) that renders one or more configured URLs inside an iframe with a tab bar.
- A **setup console** (`/setup`) for managing kiosk URLs, rebooting, shutting down, and viewing system metrics.
- A **REST API** (`/api/*`) for programmatic control (status, reboot, shutdown, screen on/off, URL navigation) — used by external automation such as Home Assistant.

The application runs headless on the VM; the actual display is a browser (Chromium or any client) pointed at the kiosk page, typically in full-screen kiosk mode.

---

## Architecture

```
Internet
   │
   ▼
kiosk1.iviewio.com (HTTPS, port 443)
   │
   ▼
Caddy (TLS termination, Let's Encrypt auto-renew)
   │  reverse_proxy 127.0.0.1:5000
   ▼
Kestrel (Blazor Server) on 127.0.0.1:5000
   │
   ▼
GCP e2-micro VM (Ubuntu 22.04 LTS, 1 GB RAM + 512 MiB zram swap)
```

| Layer | Technology | Notes |
|-------|------------|-------|
| Edge / TLS | Caddy | Automatic Let's Encrypt cert issuance and renewal |
| App server | Kestrel (ASP.NET Core) | Binds `127.0.0.1:5000` only; not exposed directly |
| UI framework | Blazor Server (SignalR circuit) | Interactive components over WebSocket |
| Component library | MudBlazor 8.14.0 | Theming, dialogs, snackbars |
| Logging | Serilog | File sink (`log.txt`, rolling) + journald |
| Process manager | systemd | `kiosk-server.service`, non-root (`kiosk`) |
| Memory | zram swap | 512 MiB zstd-compressed, swappiness 100 |

Kestrel is bound to loopback plus any non-virtual IPv4 interface (see `Program.cs` → `ConfigureKestrel`). On the GCP VM this means the internal NIC; all external traffic reaches it only through Caddy.

---

## Tech Stack

| Component | Version / Value |
|-----------|-----------------|
| Framework | .NET 8 (`net8.0`) |
| UI | MudBlazor `8.14.0` |
| Logging | Serilog.AspNetCore `9.0.0`, Serilog.Enrichers.Thread `4.0.0` |
| systemd integration | Microsoft.Extensions.Hosting.Systemd `8.0.0` |
| Reverse proxy | Caddy (Let's Encrypt ACME) |
| OS | Ubuntu 22.04 LTS |
| Host | GCP e2-micro (2 vCPU burst, 1 GB RAM, 30 GB disk) |

---

## Directory Structure

```
kiosk-server-iviewio/
├── app/
│   └── kiosk-server/               # Blazor Server application (net8.0)
│       ├── Api/
│       │   └── ApiController.cs    # REST endpoints (/api/*)
│       ├── Metrics/                # System metric collectors
│       │   ├── CpuMetrics.cs
│       │   ├── DiskMetrics.cs
│       │   ├── MemoryMetrics.cs
│       │   └── TemperatureMetrics.cs
│       ├── Model/
│       │   └── SetupModel.cs       # DTO for setup page metrics
│       ├── Pages/                  # Razor components
│       │   ├── Index.razor(.cs)    # "/" — redirects to kiosk
│       │   ├── Kiosk.razor(.cs)    # "/kiosk" — iframe display + tabs
│       │   ├── Setup.razor(.cs)    # "/setup" — config + system control
│       │   ├── Blank.razor(.cs)    # "/blank"
│       │   └── Error.cshtml(.cs)   # exception page
│       ├── Services/
│       │   ├── LayoutService.cs    # dark-mode toggle, appsettings persistence
│       │   └── MyEventService.cs   # in-process URL-navigation event bus
│       ├── Shared/                 # MainLayout, EmptyLayout
│       ├── wwwroot/                # static assets (css, icons, manifest)
│       ├── Program.cs              # startup, Kestrel binding, middleware
│       ├── appsettings.json        # runtime configuration
│       └── kiosk-server.csproj
├── scripts/
│   ├── Caddyfile                   # reverse-proxy + TLS config
│   ├── kiosk-server.service        # systemd unit
│   ├── vm-phase2-setup.sh          # .NET 8 + zram provisioning
│   └── zram-setup.service          # persistent zram swap unit
├── ACTION-PLAN.md                  # phased build/deploy checklist
├── MAINTENANCE.md                  # operational runbook
├── PRD.md                          # product requirements
├── TECH-SPEC.md                    # technical specification
└── note.txt                        # iframe-embeddable site notes
```

---

## Prerequisites

### Local development
- .NET 8 SDK (or newer SDK targeting `net8.0`)

### Deployment target (GCP VM)
- .NET 8 ASP.NET Core runtime (`aspnetcore-runtime-8.0`)
- Caddy (reverse proxy + TLS)
- systemd (process supervision)
- zram support (`zram` module, `linux-modules-extra-$(uname -r)` on GCP kernels)

---

## Local Development

```bash
# restore and run
cd app/kiosk-server
dotnet run

# open http://localhost:5000/setup
```

Publish a framework-dependent Linux build:

```bash
cd app/kiosk-server
dotnet publish -c Release -r linux-x64 --self-contained false
# output: bin/Release/net8.0/linux-x64/publish/
```

> The app reads `appsettings.json` from the current directory in DEBUG builds and from the app base directory in Release builds (`LayoutService` / `Setup` code paths).

---

## Configuration

Runtime configuration lives in `app/kiosk-server/appsettings.json`.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `Logging.LogLevel.*` | string | — | Per-category log levels |
| `DarkMode` | bool | `true` | Initial dark-mode state (toggled at runtime, persisted to `appsettings.json`) |
| `AllowedHosts` | string | `kiosk1.iviewio.com;localhost` | Host-header allowlist (semicolon-separated) |
| `ApiKey` | string | `""` | API key for `/api/*` (sent via `X-Api-Key` header). Set via the `ApiKey` environment variable — do not hardcode. Empty = `/api/*` returns 401. |
| `Port` | int | `5000` | Kestrel listen port (also enforced by `ASPNETCORE_URLS`) |
| `RedirectUrl` | array | — | Kiosk URLs: `[{ "Name": "...", "Url": "..." }, ...]` |
| `Serilog.*` | object | — | Serilog file-sink configuration (`log.txt`, 1 MB rolling, 10 files retained) |

### `RedirectUrl` behavior
- **One entry** → the kiosk redirects directly to that URL at startup (no tab bar).
- **Multiple entries** → `/kiosk` shows a tab bar; selecting a tab swaps the iframe target.

---

## Pages & Routes

| Path | Description |
|------|-------------|
| `/` | Index; redirects to the kiosk (or the single configured URL) |
| `/kiosk` | Displays configured URL(s) in an iframe with a tab bar |
| `/setup` | URL management, reboot/shutdown, system info, dark-mode toggle |
| `/blank` | Blank page (useful as a no-op kiosk target) |
| `/error` | Exception handler page (production) |

---

## REST API

All endpoints are served from `ApiController` (`Api/ApiController.cs`). Every endpoint except `/api/status` requires an `X-Api-Key` header (see [Configuration](#configuration)).

### Status

```
GET /api/status
```

Returns a JSON object with CPU, memory, disk, and temperature metrics:

```json
{
  "disk":        { "totalDiskSpace": 29.0, "availableDiskSpace": 21.0 },
  "temperature": { "cpuTemperature": 43.2, "throttledState": "" },
  "memory":      { "totalMemory": 958.0, "usedMemory": 320.0, "freeMemory": 316.0 },
  "cpu":         { "osDescription": "...", "osName": "", "cpuModel": "...", "cpuModelName": "...", "cpuHardware": "...", "cpuUsage": 12.3 }
}
```

### Control endpoints

| Method | Endpoint | Action |
|--------|----------|--------|
| POST | `/api/shutdown` | `sudo shutdown now` |
| POST | `/api/reboot` | `sudo reboot now` |
| POST | `/api/screenon` | `sudo vcgencmd display_power 1` (Pi 4, X11) |
| POST | `/api/screenoff` | `sudo vcgencmd display_power 0` (Pi 4, X11) |
| POST | `/api/screenon2` | `wlr-randr --output HDMI-A-1 --on` (Pi 5, labwc) |
| POST | `/api/screenoff2` | `wlr-randr --output HDMI-A-1 --off` (Pi 5, labwc) |
| POST | `/api/screenon3` | `wlr-randr --on` + `wtype -P F11` (Pi 5, wayfire) |
| POST | `/api/screenoff3` | `wlr-randr --off` (Pi 5, wayfire) |
| POST | `/api/stopchromium` | Kills the Chromium process |
| POST | `/api/navigatetourl?url=<url>` | Navigates the kiosk iframe to `<url>` |

### Navigation

```
POST /api/navigatetourl?url=https://example.com
```

- With a `url` query parameter → the kiosk iframe loads that URL and hides the tab bar.
- Without a `url` → the kiosk reloads and the tab bar reappears.

This endpoint only takes effect while the kiosk screen is being displayed (it routes through the in-process `MyEventService` → `Kiosk` component).

---

## Deployment

Build locally, copy the publish output to the VM, and restart the service.

```bash
# 1. Build (local)
cd app/kiosk-server
dotnet publish -c Release -r linux-x64 --self-contained false

# 2. Copy to VM
rsync -av ./bin/Release/net8.0/linux-x64/publish/ \
  kiosk-server-vm:/tmp/kiosk-new/ --rsh="gcloud compute ssh --zone=us-central1-a --project=<GCP_PROJECT_ID>"

# 3. Replace and restart (on VM)
sudo cp -r /tmp/kiosk-new/* /opt/kiosk-server/
sudo systemctl restart kiosk-server
```

See [MAINTENANCE.md](MAINTENANCE.md) for the full runbook (SSH access, incident response, known issues).

---

## Infrastructure

### GCP VM

| Item | Value |
|------|-------|
| Project | `<GCP_PROJECT_ID>` |
| Account | `<GCP_ACCOUNT_EMAIL>` |
| VM | `kiosk-server-vm` / `us-central1-a` |
| External IP | `<VM_EXTERNAL_IP>` |
| OS | Ubuntu 22.04 LTS (e2-micro) |
| DNS | Cloudflare (`iviewio.com`) |
| App path | `/opt/kiosk-server/` |

### zram / swap

To prevent OOM within 1 GB RAM, a 512 MiB zram swap device (zstd-compressed, priority 100) is configured with `vm.swappiness=100`. Provisioning is scripted in `scripts/vm-phase2-setup.sh` and made persistent via `scripts/zram-setup.service`.

### systemd service

`scripts/kiosk-server.service` runs the app as the non-root `kiosk` user:

```ini
[Service]
Type=notify
User=kiosk
Group=kiosk
WorkingDirectory=/opt/kiosk-server
ExecStartPre=-/bin/bash -c 'cp /usr/share/dotnet/shared/Microsoft.NETCore.App/8.*/Microsoft.Win32.Registry.dll /opt/kiosk-server/'
ExecStart=/usr/bin/dotnet /opt/kiosk-server/kiosk-server.dll
Restart=always
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://127.0.0.1:5000
```

> **`ExecStartPre` rationale:** ASP.NET Core DataProtection (used by Blazor Server for antiforgery tokens and circuit state) requires `Microsoft.Win32.Registry` on Linux, but that assembly ships in the shared framework and is not referenced by default. Copying it on every start (version-matched to the installed runtime) prevents the 90-day DataProtection key-expiry "blank screen" failure. See [MAINTENANCE.md](MAINTENANCE.md) for the incident history.

### Caddy / TLS

`scripts/Caddyfile`:

```
kiosk1.iviewio.com {
	reverse_proxy 127.0.0.1:5000
}
```

Caddy terminates TLS and obtains/renews Let's Encrypt certificates automatically. The A record for `kiosk1` must point to the VM IP with **DNS-only** (gray cloud) proxy status in Cloudflare.

---

## Security Notes

> A security review was performed against this repository. Findings are listed below with their current remediation status.

| Severity | Issue | Status |
|----------|-------|--------|
| High | Destructive API endpoints (`/api/shutdown`, `/api/reboot`, `/api/screen*`, `/api/stopchromium`, `/api/navigatetourl`) were unauthenticated | ✅ Fixed — now require `X-Api-Key` header |
| High | `/setup` page has no authentication (allows URL config, reboot, shutdown) | ⚠️ Open — protect via network restriction (firewall/VPN) or add app-level auth |
| Medium | Overly permissive CORS (`SetIsOriginAllowed(origin => true)` + `AllowCredentials()`) | ✅ Fixed — permissive CORS removed |
| Medium | Infrastructure identifiers (GCP account, project ID, VM IP) committed to the repository | ⚠️ Partially — `info.txt` gitignored; inline values in docs remain |
| Low | `AllowedHosts: "*"` disables host-header validation | ✅ Fixed — restricted to `kiosk1.iviewio.com;localhost` |

Do not expose port 5000 directly — keep all traffic behind Caddy.

---

## Operations & Maintenance

Operational procedures — SSH access, deploy/restart, incident response, and known-issue history — are documented in [MAINTENANCE.md](MAINTENANCE.md).

---

## Related Documents

- [PRD.md](PRD.md) — goals, user stories, success criteria
- [TECH-SPEC.md](TECH-SPEC.md) — architecture, infra, app stack, security status
- [ACTION-PLAN.md](ACTION-PLAN.md) — phased build/deploy checklist
- Upstream: [mhwlng/kiosk-server](https://github.com/mhwlng/kiosk-server) (license in `app/LICENSE.txt`)
