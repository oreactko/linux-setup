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
if ! grep -qxF "$fstab_entry" /etc/fstab; then
  echo "$fstab_entry" | sudo tee -a /etc/fstab >/dev/null
fi
sudo mount -a
