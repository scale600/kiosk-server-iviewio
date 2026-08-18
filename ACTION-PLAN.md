# Action Plan (ACTION-PLAN)

## Kiosk Server on GCP Free Tier — Blazor Server + MudBlazor + swap/zram

**Version:** 1.0  
**Project:** kiosk-server-iviewio  
**Last Updated:** 2026-02-03

---

## Progress Summary

| Phase | Status    | Notes                                                                                                           |
| ----- | --------- | --------------------------------------------------------------------------------------------------------------- |
| **1** | Done      | Created VM `kiosk-server-vm`, firewall 80/443, SSH verified. IP: <VM_EXTERNAL_IP>                                 |
| **2** | Done      | .NET 8, zram 512 MiB, swappiness 100, zram-setup.service enabled. 2.9 reboot check optional.                    |
| **3** | App ready | `app/` cloned. MudBlazor/theme already applied upstream. For 3.7/3.8 run `dotnet run` / `dotnet publish` locally |
| **4** | Done      | kiosk-server systemd registered, http://<VM_EXTERNAL_IP>:5000/setup responds 200. net8.0, published on VM.         |
| **5** | Done      | Caddy + Let's Encrypt, https://kiosk1.iviewio.com and /setup respond 200. Kestrel localhost only.                |
| **6** | Pending   | Runbook, security/update cleanup                                                                                  |

---

## Overview

This plan breaks the work into **phases** and **tasks** so you can build and operate kiosk-server on GCP free tier with MudBlazor and zram/swap. Dependencies and order are indicated; adjust dates and owners as needed.

---

## Phase 1 — GCP & VM Setup

**Goal:** Create and access an e2-micro VM in the free tier.

| #   | Task                                                                                  | Owner | Depends  | Notes                                                      |
| --- | ------------------------------------------------------------------------------------- | ----- | -------- | ---------------------------------------------------------- |
| 1.1 | Set GCP project: `gcloud config set project <GCP_PROJECT_ID>`           | Admin | —        | Already done per info.txt                                  |
| 1.2 | Enable Compute Engine API (if not enabled)                                            | Admin | —        | Console or `gcloud services enable compute.googleapis.com` |
| 1.3 | Create e2-micro VM (Ubuntu 22.04 LTS), 1 vCPU, 1 GB RAM, 30 GB disk, free-tier region | Admin | 1.2      | e.g. `us-central1-a` or `asia-northeast3-a`                |
| 1.4 | Reserve static external IP (optional; check free-tier policy) or use ephemeral        | Admin | 1.3      | Note IP for DNS                                            |
| 1.5 | Open firewall: tcp:80, tcp:443; restrict tcp:22 to admin IP if possible               | Admin | 1.3      | Default network tags or new firewall rules                 |
| 1.6 | SSH into VM and verify: `uname -a`, `free -h`                                         | Admin | 1.3, 1.5 | Confirm 1 GB RAM                                           |

**Deliverable:** VM running, SSH access, firewall allows 80/443.

**Execution result (done):** VM `kiosk-server-vm` created. External IP `<VM_EXTERNAL_IP>`. Firewall allow-http and allow-https created. SSH and `free -h` verified (RAM 958Mi, Swap 0).

---

## Phase 2 — OS: .NET 8, zram/swap

**Goal:** Install runtime and configure memory (zram + optional disk swap).

| #   | Task                                                                                   | Owner | Depends | Notes                                      |
| --- | -------------------------------------------------------------------------------------- | ----- | ------- | ------------------------------------------ |
| 2.1 | Update OS: `sudo apt update && sudo apt upgrade -y`                                    | Admin | Phase 1 | Reboot if kernel updated                   |
| 2.2 | Install .NET 8 runtime (ASP.NET Core): Microsoft repo + `aspnetcore-runtime-8.0`       | Admin | 2.1     | Or `dotnet-install` script                 |
| 2.3 | Verify: `dotnet --list-runtimes`                                                       | Admin | 2.2     | Should show Microsoft.AspNetCore.App 8.x   |
| 2.4 | Load zram: `sudo modprobe zram`; optionally add to `/etc/modules-load.d/zram.conf`     | Admin | 2.1     | So zram loads on boot                      |
| 2.5 | Create zram swap (512 MiB logical, zstd): script or one-liner; `swapon --priority 100` | Admin | 2.4     | See TECH-SPEC §3.3                         |
| 2.6 | (Optional) Add small disk swap file, priority 10                                       | Admin | 2.5     | Fallback if zram fills                     |
| 2.7 | Set swappiness: `sysctl vm.swappiness=100` (or 120); persist in `/etc/sysctl.d/`       | Admin | 2.5     | Prefer zram over keeping everything in RAM |
| 2.8 | Make zram swap persistent: systemd service or script in `/etc/rc.local` / cloud-init   | Admin | 2.5     | Run after boot so swap is always on        |
| 2.9 | Reboot and verify: `swapon --show`, `free -h`                                          | Admin | 2.6–2.8 | zram active, no OOM under light load       |

**Deliverable:** .NET 8 installed; zram (and optional disk) swap persistent across reboots.

**Execution method:** SSH into the VM and run the contents of `scripts/vm-phase2-setup.sh`, or from local run `gcloud compute scp scripts/vm-phase2-setup.sh kiosk-server-vm:/tmp/ --zone=us-central1-a` then run `sudo bash /tmp/vm-phase2-setup.sh` on the VM. (A long apt upgrade may cause SSH command timeouts here → recommend running directly on the VM.)

---

## Phase 3 — Application: kiosk-server + MudBlazor

**Goal:** Get kiosk-server running with MudBlazor theme (locally or in repo).

| #   | Task                                                                                                                                    | Owner | Depends | Notes                                               |
| --- | --------------------------------------------------------------------------------------------------------------------------------------- | ----- | ------- | --------------------------------------------------- |
| 3.1 | Clone or fork mhwlng/kiosk-server; open in IDE                                                                                          | Dev   | —       | Branch: master or main                              |
| 3.2 | Add MudBlazor NuGet: `dotnet add package MudBlazor`                                                                                     | Dev   | 3.1     | Match .NET 8                                        |
| 3.3 | In `Program.cs`: `builder.Services.AddMudServices()`                                                                                    | Dev   | 3.2     | Before `builder.Build()`                            |
| 3.4 | In root layout (e.g. `App.razor` or `MainLayout.razor`): add `<MudThemeProvider />`, `<MudDialogProvider />`, `<MudSnackbarProvider />` | Dev   | 3.3     | Per MudBlazor docs                                  |
| 3.5 | Define `MudTheme` (default or custom palette) and pass to `MudThemeProvider`                                                            | Dev   | 3.4     | Optional dark/light later                           |
| 3.6 | Replace or wrap key UI (setup page, nav) with MudBlazor components (AppBar, Buttons, etc.)                                              | Dev   | 3.5     | Incremental; start with layout and setup            |
| 3.7 | Run locally: `dotnet run`; open `/setup` and verify theme and behavior                                                                  | Dev   | 3.6     | No regressions on kiosk URL config, reboot/shutdown |
| 3.8 | Publish: `dotnet publish -c Release -r linux-x64 --self-contained false` (or true if desired)                                           | Dev   | 3.7     | Output folder ready for VM                          |

**Deliverable:** Publishable app with MudBlazor theme; runs locally.

**Execution result:** Cloned into `app/`. MudBlazor 8.14.0, AddMudServices, and MudThemeProvider/dark-mode toggle in MainLayout already applied upstream. For 3.7/3.8, run `cd app/kiosk-server && dotnet run` / `dotnet publish -c Release -r linux-x64 --self-contained false` locally. (The project is net10.0; if only .NET 8 is installed on the VM, change to net8.0 or use self-contained publish.)

---

## Phase 4 — Deploy to VM & systemd

**Goal:** Run kiosk-server on VM under systemd.

| #   | Task                                                                                                                                                                                                    | Owner     | Depends  | Notes                               |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- | -------- | ----------------------------------- |
| 4.1 | Create app user on VM: e.g. `sudo useradd -r -s /bin/false kiosk`                                                                                                                                       | Admin     | Phase 2  | Or use `www-data`                   |
| 4.2 | Create app directory: e.g. `/opt/kiosk-server`; set owner to app user                                                                                                                                   | Admin     | 4.1      |                                     |
| 4.3 | Copy publish output to VM (rsync/scp): e.g. `rsync -av ./publish/ user@VM:/opt/kiosk-server/`                                                                                                           | Admin/Dev | 3.8, 4.2 | From build machine                  |
| 4.4 | Create systemd unit `kiosk-server.service`: ExecStart=`dotnet /opt/kiosk-server/KioskServer.dll`, User=kiosk, Restart=always, ASPNETCORE_URLS=http://0.0.0.0:5000 (or 127.0.0.1 if using reverse proxy) | Admin     | 4.3      | See TECH-SPEC §4.4; adjust DLL name |
| 4.5 | `sudo systemctl daemon-reload && sudo systemctl enable kiosk-server && sudo systemctl start kiosk-server`                                                                                               | Admin     | 4.4      |                                     |
| 4.6 | Check: `curl -s -o /dev/null -w "%{http_code}" http://localhost:5000` (or /setup)                                                                                                                       | Admin     | 4.5      | Expect 200 or 302                   |
| 4.7 | From host: open http://VM_EXTERNAL_IP:5000/setup (if firewall allows); if not, use reverse proxy next                                                                                                   | Admin     | 4.6, 1.5 |                                     |

**Deliverable:** kiosk-server running on VM; reachable on port 5000 (or via proxy).

---

## Phase 5 — HTTPS & Domain

**Goal:** Serve https://kiosk1.iviewio.com with TLS.

| #   | Task                                                                                                                          | Owner | Depends      | Notes                              |
| --- | ----------------------------------------------------------------------------------------------------------------------------- | ----- | ------------ | ---------------------------------- |
| 5.1 | Point kiosk1.iviewio.com to VM external IP (A or CNAME)                                                                       | Admin | 1.4          | DNS TTL; wait for propagation      |
| 5.2 | Install reverse proxy: Caddy (`apt install caddy`) or Nginx + Certbot                                                         | Admin | Phase 2, 5.1 | Caddy: simpler ACME                |
| 5.3 | Configure proxy: host kiosk1.iviewio.com → proxy_pass http://127.0.0.1:5000 (Nginx) or `reverse_proxy 127.0.0.1:5000` (Caddy) | Admin | 5.2          |                                    |
| 5.4 | Enable TLS: Caddy auto ACME; or Certbot for Nginx                                                                             | Admin | 5.3          | Ensure HTTPS only in production    |
| 5.5 | Restrict Kestrel to localhost if using proxy: ASPNETCORE_URLS=http://127.0.0.1:5000; restart kiosk-server                     | Admin | 5.3          |                                    |
| 5.6 | Test: https://kiosk1.iviewio.com and https://kiosk1.iviewio.com/setup                                                         | Admin | 5.4, 5.5     | No cert warnings; setup page loads |

**Deliverable:** Public HTTPS access at kiosk1.iviewio.com.

---

## Phase 6 — Operations & Hardening

**Goal:** Reliable operation and basic hardening.

| #   | Task                                                                                             | Owner     | Depends      | Notes                              |
| --- | ------------------------------------------------------------------------------------------------ | --------- | ------------ | ---------------------------------- |
| 6.1 | Document deploy/restart: “copy publish → rsync to VM → systemctl restart kiosk-server”           | Admin     | Phase 4      | Add to README or runbook           |
| 6.2 | Optional: systemd `MemoryMax=800M` for kiosk-server (test with zram)                             | Admin     | Phase 2, 4.5 | Avoid single process using all RAM |
| 6.3 | Optional: ASP.NET Core Health Checks + `/health`; proxy or monitor                               | Dev/Admin | 4.5          | TECH-SPEC §7.1                     |
| 6.4 | Log rotation: journald default or limit; optional log level reduction in Production              | Admin     | 4.5          | TECH-SPEC §7.2                     |
| 6.5 | Security: disable root SSH if needed; ensure only 80/443/22 (or 22 restricted); no dev endpoints | Admin     | Phase 5      | TECH-SPEC §8                       |
| 6.6 | Schedule: OS and .NET updates (unattended-upgrades or manual); plan reboots if needed            | Admin     | Phase 2      |                                    |

**Deliverable:** Runbook, optional health check, basic security and update process.

---

## Phase 7 — Optional Later

| #   | Task                                                | Notes                      |
| --- | --------------------------------------------------- | -------------------------- |
| 7.1 | User/password auth for /setup                       | Per upstream roadmap       |
| 7.2 | Dark/light theme toggle in MudBlazor                | UX improvement             |
| 7.3 | Simple monitoring (e.g. uptime check, alert on 5xx) | External or GCP monitoring |

---

## Progress Checklist (by phase)

Check each item with `[x]` as you proceed.

### Phase 1 — GCP & VM Setup

- [x] **1.1** Set GCP project: `gcloud config set project <GCP_PROJECT_ID>`
- [x] **1.2** Enable Compute Engine API
- [x] **1.3** Create e2-micro VM (Ubuntu 22.04 LTS, free-tier region)
- [x] **1.4** Verify external IP (ephemeral or reserved static)
- [x] **1.5** Firewall: allow tcp:80, tcp:443; restrict tcp:22 if needed
- [x] **1.6** SSH into VM and verify with `uname -a`, `free -h`

### Phase 2 — OS: .NET 8, zram/swap

Run on the VM: `scripts/vm-phase2-setup.sh` (copy via SCP then run with `sudo bash`). On GCP kernels, install `linux-modules-extra-$(uname -r)` before using zram.

- [x] **2.1** Update OS: `apt update && apt upgrade -y`
- [x] **2.2** Install .NET 8 ASP.NET Core runtime
- [x] **2.3** Verify with `dotnet --list-runtimes`
- [x] **2.4** Load zram module and configure it to load on boot
- [x] **2.5** Create zram swap (512 MiB, zstd, priority 100)
- [ ] **2.6** (optional) Add disk swap file, priority 10
- [x] **2.7** Set vm.swappiness and persist it
- [x] **2.8** Apply zram swap automatically on boot (systemd/script)
- [x] **2.9** Verify `swapon --show`, `free -h` after reboot (confirmed zram 512M, Swap 511Mi after reboot)

### Phase 3 — Application: kiosk-server + MudBlazor

- [x] **3.1** Clone or fork mhwlng/kiosk-server
- [x] **3.2** Add MudBlazor NuGet package (already included upstream)
- [x] **3.3** Add AddMudServices() in Program.cs (already included upstream)
- [x] **3.4** Add MudThemeProvider, MudDialogProvider, MudSnackbarProvider to layout (already in MainLayout)
- [x] **3.5** Define MudTheme and wire it to ThemeProvider (MudThemeProvider + LayoutService dark mode)
- [x] **3.6** Replace setup/navigation UI with MudBlazor components (already using MudLayout, MudAppBar, etc.)
- [ ] **3.7** Run `dotnet run` locally and verify /setup behavior/theme (requires dotnet locally)
- [ ] **3.8** Run `dotnet publish -c Release -r linux-x64 --self-contained false` (when .NET runtime is installed on the VM)

### Phase 4 — Deploy to VM & systemd

- [x] **4.1** Create an app-dedicated user on the VM (e.g. kiosk)
- [x] **4.2** Create app directory and set ownership (e.g. /opt/kiosk-server)
- [x] **4.3** Copy publish output to VM (net8.0; publish on VM then copy to /opt/kiosk-server)
- [x] **4.4** Create systemd unit kiosk-server.service (scripts/kiosk-server.service)
- [x] **4.5** systemctl daemon-reload, enable, start
- [x] **4.6** Verify localhost:5000 responds inside VM via curl (200)
- [x] **4.7** Verify VM external IP:5000/setup from host (added firewall allow-kiosk-app tcp:5000)

### Phase 5 — HTTPS & Domain

- [x] **5.1** Point kiosk1.iviewio.com DNS to the VM external IP (confirmed by successful ACME issuance)
- [x] **5.2** Install reverse proxy (Caddy)
- [x] **5.3** Configure proxy: Caddyfile kiosk1.iviewio.com → reverse_proxy 127.0.0.1:5000
- [x] **5.4** Apply TLS (Caddy Let's Encrypt ACME issued)
- [x] **5.5** Bind Kestrel to localhost only (ASPNETCORE_URLS=http://127.0.0.1:5000), restart
- [x] **5.6** Verify https://kiosk1.iviewio.com and /setup return 200 via curl inside the VM

### Phase 6 — Operations & Hardening

- [ ] **6.1** Document deploy/restart runbook
- [ ] **6.2** (optional) Set systemd MemoryMax=800M
- [ ] **6.3** (optional) Add /health health check
- [ ] **6.4** Review log level and journald settings
- [ ] **6.5** Security: review SSH, firewall, dev endpoints
- [ ] **6.6** Document OS/.NET update policy (manual/automatic)

### Phase 7 — Optional Later

- [ ] **7.1** /setup user/password auth
- [ ] **7.2** MudBlazor dark/light theme toggle
- [ ] **7.3** Simple monitoring (uptime, 5xx alerts)

---

## Checklist Summary

- [x] **Phase 1:** VM created, firewall, SSH OK
- [x] **Phase 2:** .NET 8, zram/swap persistent, verified (2.9 reboot check optional)
- [ ] **Phase 3:** kiosk-server + MudBlazor built and published
- [x] **Phase 4:** Deployed on VM, systemd, app responds on :5000
- [x] **Phase 5:** DNS, HTTPS at kiosk1.iviewio.com
- [ ] **Phase 6:** Runbook, optional health/limits, security and updates

---

## References

- **PRD.md** — Goals, user stories, success criteria
- **TECH-SPEC.md** — GCP, zram, app stack, HTTPS, monitoring
