#!/usr/bin/env bash
set -euo pipefail

mount_point="/mnt/hgfs"
fstab_entry="vmhgfs-fuse /mnt/hgfs fuse defaults,allow_other,nofail 0 0"

virt_type="$(systemd-detect-virt 2>/dev/null || true)"
if [[ "$virt_type" != "vmware" ]]; then
  echo "This script is intended for VMware guests only (detected: ${virt_type:-none})." >&2
  exit 1
fi

if ! command -v vmhgfs-fuse >/dev/null 2>&1; then
  echo "vmhgfs-fuse is not installed. Please install open-vm-tools first." >&2
  exit 1
fi

sudo mkdir -p "$mount_point"
if ! grep -q '^[[:space:]]*user_allow_other' /etc/fuse.conf; then
  echo "user_allow_other" | sudo tee -a /etc/fuse.conf
fi
sudo tee /etc/systemd/system/mnt-hgfs.service <<EOF
[Unit]
Description=VMware mount for hgfs
ConditionVirtualization=vmware
After=vmtoolsd.service

[Service]
Type=oneshot
ExecStartPre=/usr/bin/mkdir -p /mnt/hgfs
ExecStartPre=/usr/bin/bash -c '! mountpoint -q /mnt/hgfs'
ExecStart=/usr/bin/vmhgfs-fuse .host:/ /mnt/hgfs -o allow_other,default_permissions
ExecStop=/usr/bin/fusermount -u /mnt/hgfs
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
if ! grep -q "^fuse" /etc/modules-load.d/open-vm-tools.conf; then
  echo "fuse" | sudo tee -a /etc/modules-load.d/open-vm-tools.conf
fi
sudo systemctl daemon-reload
sudo systemctl enable --now mnt-hgfs.mount
