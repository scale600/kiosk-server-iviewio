# MAINTENANCE — kiosk-server-iviewio

> Runbook for operating kiosk1.iviewio.com on GCP e2-micro.

---

## SSH Access

```bash
gcloud config set account <GCP_ACCOUNT_EMAIL>
gcloud compute ssh kiosk-server-vm --zone=us-central1-a --project=<GCP_PROJECT_ID>
```

---

## Routine Checks

```bash
# app status
sudo systemctl status kiosk-server

# live logs
journalctl -u kiosk-server -f

# memory / swap
free -h && swapon --show
```

---

## Deploy (App Update)

```bash
# 1. Build locally
dotnet publish -c Release -r linux-x64 --self-contained false

# 2. Copy to VM
rsync -av ./app/kiosk-server/bin/Release/net8.0/linux-x64/publish/ \
  kiosk-server-vm:/tmp/kiosk-new/ --rsh="gcloud compute ssh --zone=us-central1-a"

# 3. Replace on VM and restart
sudo cp -r /tmp/kiosk-new/* /opt/kiosk-server/
sudo systemctl restart kiosk-server
```

---

## Restart

```bash
sudo systemctl restart kiosk-server
```

> **Check before restart:** startup fails if the `/usr/share/dotnet/shared` symlink is missing.
> ```bash
> ls /usr/share/dotnet/shared  # if missing, run the following
> sudo ln -s /usr/lib/dotnet/shared /usr/share/dotnet/shared
> ```

---

## Incident Response

### Site Unreachable — DNS Issue

**Symptom:** `DNS_PROBE_FINISHED_NXDOMAIN` in the browser

**Check:**
```bash
dig @8.8.8.8 kiosk1.iviewio.com +short  # must return <VM_EXTERNAL_IP>
```

**Fix:** Cloudflare dashboard → iviewio.com → DNS
- Add A record `kiosk1` → `<VM_EXTERNAL_IP>`
- Proxy status: **DNS only (gray)** — orange (proxied) causes a TLS conflict

> Due to the SOA negative TTL of 1800s (30 min), some cache may persist for up to 30 min after recovery.

---

### Site Unreachable — Blank Screen

**Symptom:** the domain loads but the page is blank/white

**Check:**
```bash
tail -50 /opt/kiosk-server/log.txt | grep -i "error\|exception"
```

**Cause A — DataProtection key expiry (90-day cycle)**

This applies if the log shows the error below:
```
CryptographicException ... FileNotFoundException: Microsoft.Win32.Registry
```

Fix:
```bash
# Copy the Registry DLL (if missing)
sudo cp /usr/lib/dotnet/shared/Microsoft.NETCore.App/$(ls /usr/lib/dotnet/shared/Microsoft.NETCore.App/)/Microsoft.Win32.Registry.dll /opt/kiosk-server/
sudo chown kiosk:kiosk /opt/kiosk-server/Microsoft.Win32.Registry.dll
sudo systemctl restart kiosk-server
```

> **Permanent fix (applied 2026-08-18):** Added `ExecStartPre` to `kiosk-server.service`
> so the framework DLL is copied automatically on every start (version-matched to the
> installed runtime). Manual restart/copy is no longer required; DataProtection keys now
> auto-renew every 90 days.

**Cause B — App crash**

```bash
sudo systemctl restart kiosk-server
journalctl -u kiosk-server -n 50 --no-pager
```

---

### Restart Fails — dotnet runtime not found

**Symptom:** `journalctl` shows `No frameworks were found`

**Cause:** missing `/usr/share/dotnet/shared/` symlink (dual-install environment: dotnet-install.sh + apt)

**Fix:**
```bash
sudo ln -s /usr/lib/dotnet/shared /usr/share/dotnet/shared
sudo systemctl restart kiosk-server
```

---

### Out of Memory (OOM)

```bash
dmesg | grep -i oom        # check OOM killer log
free -h                    # memory status
swapon --show              # check zram (zram0 512M, priority 100)
sudo systemctl restart kiosk-server
```

If zram is missing:
```bash
sudo bash /opt/zram-setup.sh   # or re-run the script
```

---

## Infrastructure Info

| Item | Value |
|------|-------|
| GCP account | <GCP_ACCOUNT_EMAIL> |
| Project ID | <GCP_PROJECT_ID> |
| VM | kiosk-server-vm / us-central1-a |
| External IP | <VM_EXTERNAL_IP> |
| App path | /opt/kiosk-server/ |
| Service | kiosk-server.service |
| DNS | Cloudflare (iviewio.com) |
| TLS | Caddy + Let's Encrypt (auto-renew) |

---

## Known Issues

| Date | Symptom | Cause | Fix |
|------|---------|-------|-----|
| 2026-05-03 | Blank screen | DataProtection key 90-day expiry + Registry DLL missing | Copy DLL then restart |
| 2026-05-19 | DNS unavailable | Cloudflare A record deleted | Re-add record |
| 2026-05-19 | Restart failed | dotnet shared symlink missing | Link via ln -s |
| 2026-08-17 | Blank screen | DataProtection key 90-day expiry (Registry DLL version mismatch: runtime 8.0.29 vs copy 8.0.26) | Copy correct-version DLL + restart; applied `ExecStartPre` permanent fix |

---

## Recommended Periodic Tasks

| Frequency | Task |
|-----------|------|
| Every 60 days | `sudo systemctl restart kiosk-server` (prevent DataProtection key expiry) |
| Quarterly | `sudo apt update && sudo apt upgrade -y` (security patches) |
| As needed | `journalctl -u kiosk-server --since "1 week ago" | grep -i error` |
