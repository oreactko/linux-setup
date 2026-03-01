#!/usr/bin/env bash
set -euo pipefail

mount_point="/mnt/hgfs"
fstab_entry="vmhgfs-fuse /mnt/hgfs fuse defaults,allow_other,nofail 0 0"

sudo mkdir -p "$mount_point"
if ! grep -qxF "$fstab_entry" /etc/fstab; then
  echo "$fstab_entry" | sudo tee -a /etc/fstab >/dev/null
fi
sudo mount -a
