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
sudo dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release terra-release-mesa terra-release-extras terra-release-multimedia -y
sudo dnf copr enable agriffis/neovim-nightly -y
sudo dnf group upgrade core -y
sudo dnf upgrade --refresh -y
sudo dnf distro-sync -y
sudo dnf install @multimedia @development-tools @c-development git zsh gh neovim ripgrep fd-find btop wget curl eza fastfetch unzip zip 7zip python3 python3-pip deno yt-dlp ncdu oh-my-posh nodejs clang gcc-c++ ninja-build cmake gdb ccache llvm-tools x265 openh265 mesa-va-drivers mesa-vdpau-drivers ffmpeg ffmpeg-libs gstreamer1-plugins-{bad-free,bad-freeworld,good,good-extras,ugly,ugly-free} gstreamer1-libav gstreamer1-plugins-bad-nonfree gstreamer1-plugins-ugly lame x264 openh264 intel-media-driver libva-utils vdpauinfo libde265 zram-generator tuned tuned-utils crudini thermald -y
npm config set prefix ~/.local
npm install -g @github/copilot

# Configure some system settings
sudo crudini --set /etc/systemd/zram-generator.conf zram0 compression-algorithm zstd
sudo systemctl daemon-reload
sudo systemctl enable --now fstrim.timer systemd-oomd systemd-zram-setup@zram0 systemd-resolved tuned thermald
sudo tuned-adm profile balanced

# Setup swap file
# Calculate swap size (RAM-based formula)
SWAPSIZE=$(free | awk '/Mem/ {x=$2/1024/1024; printf "%.0fG", (x<2 ? 2*x : x<8 ? 1.5*x : x) }')
SWAPFILE=/var/swap/swapfile

# Create btrfs subvolume and swap file
sudo btrfs subvolume create /var/swap
sudo btrfs filesystem mkswapfile --size $SWAPSIZE --uuid clear $SWAPFILE

# Enable swap file
echo $SWAPFILE none swap defaults 0 0 | sudo tee --append /etc/fstab
sudo swapon --all --verbose

# Setup zsh and oh-my-posh
sudo chsh -s /usr/bin/zsh "${SUDO_USER:-$USER}"
sh -c "$(curl -fsSL get.zshell.dev)" --
wget https://raw.githubusercontent.com/oreactko/linux-setup/refs/heads/main/home/.theme.omp.json -O ~/.theme.omp.json
curl https://raw.githubusercontent.com/oreactko/linux-setup/refs/heads/main/home/add_zshrc | tee -a ~/.zshrc
exec zsh
