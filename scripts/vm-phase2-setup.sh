#!/bin/bash
# Phase 2 — OS: .NET 8, zram/swap
# Run on VM as root or with sudo (e.g. after: gcloud compute ssh kiosk-server-vm --zone=us-central1-a)

set -e

echo "[2.1] apt update and upgrade..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

echo "[2.2] Install .NET 8 ASP.NET Core runtime..."
# Add Microsoft package repo
wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
dpkg -i /tmp/packages-microsoft-prod.deb
rm /tmp/packages-microsoft-prod.deb
apt-get update -qq
apt-get install -y -qq aspnetcore-runtime-8.0

echo "[2.3] Verify .NET..."
dotnet --list-runtimes | grep -E "Microsoft.AspNetCore.App|Microsoft.NETCore.App"

echo "[2.4] Load zram at boot..."
echo "zram" > /etc/modules-load.d/zram.conf
modprobe zram

echo "[2.5] Create zram swap (512 MiB, zstd)..."
# 512 MiB = 524288 KB
echo "zstd" > /sys/block/zram0/comp_algorithm 2>/dev/null || true
echo 524288 > /sys/block/zram0/disksize
mkswap -U clear /dev/zram0
swapon --discard --priority 100 /dev/zram0

echo "[2.7] Set swappiness..."
echo "vm.swappiness=100" > /etc/sysctl.d/99-zram.conf
sysctl -p /etc/sysctl.d/99-zram.conf

echo "[2.8] Make zram swap persistent (systemd service)..."
cat > /etc/systemd/system/zram-setup.service << 'SVC'
[Unit]
Description=Enable zram swap
After=local-fs.target
DefaultDependencies=no

[Service]
Type=oneshot
ExecStartPre=/sbin/modprobe zram
ExecStart=/bin/bash -c 'echo zstd > /sys/block/zram0/comp_algorithm 2>/dev/null; echo 524288 > /sys/block/zram0/disksize; mkswap -U clear /dev/zram0; swapon --discard --priority 100 /dev/zram0'
RemainAfterExit=yes
ExecStop=/sbin/swapoff /dev/zram0

[Install]
WantedBy=multi-user.target
SVC
systemctl daemon-reload
systemctl enable zram-setup.service

echo "[Phase 2] Done. Reboot to verify: sudo reboot"
echo "After reboot run: swapon --show && free -h"
