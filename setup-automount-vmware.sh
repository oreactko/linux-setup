#!/usr/bin/env bash
sudo mkdir -p /mnt/hgfs
echo "vmhgfs-fuse /mnt/hgfs fuse defaults,allow_other,nofail 0 0" | sudo tee -a /etc/fstab
sudo mount -a
