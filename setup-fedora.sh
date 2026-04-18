#!/usr/bin/env bash
set -euo pipefail
# Check OS
if [[ ! -r /etc/os-release ]]; then
  echo "Cannot detect operating system. /etc/os-release is missing." >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "fedora" ]]; then
  echo "This script only supports Fedora. Detected ID=${ID:-unknown}." >&2
  exit 1
fi

# Configure repositories and install packages
sudo dnf install "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" dnf5-plugins -y
sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1
sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo -y
sudo dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release terra-release-extras terra-release-multimedia -y
sudo dnf copr enable agriffis/neovim-nightly -y
sudo dnf upgrade --refresh -y
sudo dnf distro-sync -y
sudo dnf install -y @development-tools @c-development python3.11 python3-devel python3.11-devel fzf lazygit moreutils git zsh gh neovim ripgrep fd-find btop wget curl eza fastfetch unzip zip 7zip python3 python3-pip deno yt-dlp ncdu oh-my-posh nodejs clang gcc-c++ ninja-build cmake gdb ccache x265 ffmpeg ffmpeg-libs gstreamer1-plugins-{bad-free,bad-freeworld,bad-nonfree,good,good-extras,ugly,ugly-free} gstreamer1-libav lame x264 openh264 libde265 crudini
python3 -m pip install --user pipx
npm config set prefix ~/.local
npm install -g @github/copilot
sudo systemctl enable --now systemd-resolved
IS_WSL=false
grep -qiE "(microsoft|wsl)" /proc/sys/kernel/osrelease && IS_WSL=true
if ! [[ "$IS_WSL" == true ]]; then
  sudo dnf install zram-generator tuned tuned-utils -y
  sudo crudini --set /etc/systemd/zram-generator.conf zram0 compression-algorithm zstd
  sudo systemctl daemon-reload
  sudo systemctl enable --now fstrim.timer systemd-oomd systemd-zram-setup@zram0 tuned
  sudo tuned-adm profile balanced
fi
if ! systemd-detect-virt -q; then
  sudo dnf install thermald -y
  sudo systemctl enable --now thermald
fi
# Setup swap file
FS_TYPE=$(findmnt -n -o FSTYPE /)
if [ "$FS_TYPE" = "btrfs" ] && ! [[ "$IS_WSL" == true ]]; then
  # Calculate swap size (RAM-based formula)
  SWAPSIZE=$(free | awk '/Mem/ {x=$2/1024/1024; printf "%.0fG", (x<2 ? 2*x : x<8 ? 1.5*x : x) }')
  SWAPFILE="/var/swap/swapfile"
  SWAPFILE_ENTRY="$SWAPFILE none swap defaults 0 0"

  # Create swapfile
  sudo mkdir -p /var/swap

  if ! sudo btrfs subvolume show /var/swap >/dev/null 2>&1; then
    sudo btrfs subvolume create /var/swap
  fi

  if [[ ! -f "$SWAPFILE" ]]; then
    sudo btrfs filesystem mkswapfile --size "$SWAPSIZE" --uuid clear $SWAPFILE
  fi

  if ! grep -qxF "$SWAPFILE_ENTRY" /etc/fstab; then
    echo "$SWAPFILE_ENTRY" | sudo tee -a /etc/fstab
  fi
  sudo swapon --all --verbose
fi
# Setup zsh and oh-my-posh
sudo chsh -s /usr/bin/zsh "${SUDO_USER:-$USER}"
sh -c "$(curl -fsSL get.zshell.dev)" --
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git
wget https://raw.githubusercontent.com/oreactko/linux-setup/refs/heads/main/nvim/lazyvim.json -O ~/.config/nvim/lazyvim.json
wget https://raw.githubusercontent.com/oreactko/linux-setup/refs/heads/main/nvim/lua/config/options.lua -O ~/.config/nvim/lua/config/options.lua
wget https://raw.githubusercontent.com/oreactko/linux-setup/refs/heads/main/home/.theme.omp.json -O ~/.theme.omp.json
curl https://raw.githubusercontent.com/oreactko/linux-setup/refs/heads/main/home/add_zshrc | tee -a ~/.zshrc
python3 -m pipx ensurepath
if [[ "$IS_WSL" == true ]]; then
  cat <<EOF >>~/.zshrc
export MESA_LOADER_DRIVER_OVERRIDE=d3d12
export GALLIUM_DRIVER=d3d12 
EOF
fi
exec zsh
