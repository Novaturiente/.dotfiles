#!/usr/bin/env bash
# First-boot setup for novahome, the headless home server (Acer Aspire A515-57G).
# Run as nova (not root) on a fresh CachyOS install with no desktop, after cloning
# this repo to ~/.dotfiles. The laptop's setup is ../setup.sh; this one installs
# no desktop, window manager, fonts or audio stack.
cd ~/.dotfiles || exit 1
HERE=system/novahome

# novarch, pointed at novahome's own package folder (the laptop's system/packages
# would bring every desktop list along: novarch reads all top-level files there).
curl -fsSL -o /tmp/novarch-install.sh https://raw.githubusercontent.com/Novaturiente/novarch/main/install.sh &&
	sh /tmp/novarch-install.sh || exit 1
mkdir -p ~/.config/novarch
[ -e ~/.config/novarch/config.toml ] ||
	echo "packages_dir = \"$HOME/.dotfiles/$HERE/packages\"" >~/.config/novarch/config.toml
novarch sync || exit 1

# Snapshots are off on this machine: everything that matters is backed up to
# /mnt/storage. A fresh CachyOS btrfs install ships snapper + snap-pac (a snapshot
# on every pacman run) + limine-snapper-sync; delete their snapshots, then remove them.
if command -v snapper >/dev/null; then
	ids=$(sudo snapper --no-headers --csvout list --columns number | awk '$1>0' | tr '\n' ' ')
	# shellcheck disable=SC2086
	[ -n "${ids// /}" ] && sudo snapper delete --sync $ids
	sudo systemctl disable --now snapper-cleanup.timer snapper-timeline.timer limine-snapper-sync.service 2>/dev/null
	for p in limine-snapper-sync snap-pac cachyos-snapper-support btrfs-assistant snapper; do
		pacman -Q "$p" >/dev/null 2>&1 && sudo pacman -Rns --noconfirm "$p"
	done
	sudo rm -f /etc/mkinitcpio.conf.d/10-limine-snapper-sync.conf
fi

# System files: $HERE/system mirrors /. Wi-Fi power save off (iwlwifi crashes under
# load), lid ignored, NVIDIA runtime D3, BBR, THP madvise, NVMe scheduler none,
# Docker log caps, power profile by AC state, battery health mode, Jellyfin's
# stable Intel render node.
sudo cp -r "$HERE/system/." /

# Text console blanks after 5 idle minutes; any key wakes it (local rescue access).
grep -q consoleblank /etc/default/limine ||
	echo 'KERNEL_CMDLINE[default]+=" consoleblank=300"' | sudo tee -a /etc/default/limine >/dev/null

# External USB SSD: backups, Immich library, OpenCloud data. nofail so a missing
# drive never blocks boot.
sudo mkdir -p /mnt/storage
grep -q d2a5667d-1120-49a6-8ce1-4018633fe64a /etc/fstab ||
	echo 'UUID=d2a5667d-1120-49a6-8ce1-4018633fe64a  /mnt/storage  ext4  defaults,nofail,x-systemd.device-timeout=10  0  2' |
	sudo tee -a /etc/fstab >/dev/null

# Dotfiles: same shell, tmux and neovim setup as the laptop. Desktop app configs come
# along as inert links. Skipped: .novacode (novahome has its own AGENTS.md, restored
# from backup) and systemd user units (the laptop's are desktop-session units; the
# server's live in ~/Automation).
mkdir -p ~/.config/systemd/user ~/.novacode
# The installer's skeleton files would make stow refuse; keep them aside.
for f in .zshrc .profile .zprofile .tmux.conf .gitconfig; do
	[ -f ~/"$f" ] && [ ! -L ~/"$f" ] && mv ~/"$f" ~/"$f.pre-stow"
done
stow -d ~/.dotfiles -t ~ --ignore='\.novacode' --ignore='systemd' nova || exit 1

# novacode: binary only. Its config and package lock come back with the
# home-secrets_backup/agents/novacode restore (see the list at the bottom).
curl -fsSL -o /tmp/novacode-install.sh https://raw.githubusercontent.com/Novaturiente/novacode/main/scripts/install.sh &&
	sh /tmp/novacode-install.sh || exit 1

sudo usermod -aG docker "$(whoami)"
chsh "$(whoami)" -s "$(which zsh)"

# User timers and services (backups, media import, cleanup) must run without a login.
sudo loginctl enable-linger "$(whoami)"

# A server never sleeps.
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

sudo systemctl daemon-reload
sudo systemctl enable NetworkManager.service sshd.service docker.service \
	tailscaled.service avahi-daemon.service intel_lpmd.service \
	power-profile-boot.service linux-modules-cleanup.service fstrim.timer

# Firewall: drop incoming by default; open what the services need.
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22                                    # SSH (password auth stays on)
sudo ufw allow in on tailscale0                      # everything over the tailnet
sudo ufw allow 41641/udp comment 'tailscale direct'
sudo ufw allow from 172.16.0.0/12                    # Docker containers to host ports (NPM upstreams)
sudo ufw allow Samba
sudo ufw allow 8088                                  # Gotify
sudo ufw allow 8096                                  # Jellyfin
for proto in tcp udp; do                             # KDE Connect (tv-mpris phone card), LAN only
	sudo ufw allow proto "$proto" from 192.168.220.0/24 to any port 1714:1764
done
sudo ufw --force enable
sudo systemctl enable ufw.service

# nvidia-pm.conf and the cmdline change need a new initramfs and limine.conf.
sudo limine-mkinitcpio

# NOT automated: restore from /mnt/storage, Tailscale, Samba, TV services and
# more. Steps in system/SETUP.md ("novahome: after setup.sh").
sudo reboot
