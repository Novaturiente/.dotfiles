#!/usr/bin/env sh
# First-boot setup. Every path below is relative to the repo root.
cd ~/.dotfiles || exit 1

sudo cp system/novarch /usr/bin/novarch

# Point novarch at the package lists (no prompt), then install everything they
# declare: stow, zsh, ly, ufw, tlp, pkgfile and Hyprland are all needed below.
novarch init -f ~/.dotfiles/system/package
novarch install

# System files: system/system mirrors /, so copy the whole tree onto it
# (tlp.conf, sleep.conf, zram, docker, udev, units, /usr/local helpers, polkit, pam).
sudo cp -r system/system/. /
sudo chmod 0440 /etc/sudoers.d/vpn-run

# Login manager: Ly (installed from package/windowmanager.yaml).
# Ly is a TUI greeter running on its own VT; it needs no dedicated user.
sudo mkdir -p /etc/ly

mkdir -p ~/.config

stow -d ~/.dotfiles -t ~ nova

# Mount point for novahome's home (sshfs in hyprland.lua; reached over Tailscale).
mkdir -p ~/server

# docker: run containers without sudo. input: ydotool. video: backlight.
# tss: TPM access for the rbw face unlock (usr/local/libexec/rbw-tpm-face-unseal).
sudo usermod -aG docker,input,video,tss "$(whoami)"

# Colours for every application, plus /etc/ly/config.ini and the Plymouth boot
# splash. Reads system/themes/current, so a fresh machine comes up on whichever
# theme is committed. Switch later with scripts/theme.sh <name> or Mod+Shift+T.
./scripts/theme.sh "$(cat system/themes/current)" --system

sudo systemctl daemon-reload
sudo systemctl enable ly@tty2.service

systemctl --user mask pulseaudio.service pulseaudio.socket

sudo systemctl enable battery-limit.timer paccache.timer

# Services this laptop runs. tailscaled carries the sshfs mount to novahome,
# linux-enable-ir-emitter powers the IR camera for face unlock.
sudo systemctl enable NetworkManager.service bluetooth.service sshd.service \
	docker.service tailscaled.service tlp.service mullvad-netns.service \
	linux-enable-ir-emitter.service

# Set zsh as default login shell
chsh "$(whoami)" -s "$(which zsh)"

# pkgfile: command-not-found handler + package/binary completion database
sudo pkgfile --update
sudo systemctl enable --now pkgfile-update.timer

# NOT automated, check by hand on new hardware:
# - /etc/mkinitcpio.conf HOOKS need `plymouth` (boot splash) and `resume`
#   (hibernate, with a swap file such as /swap/swapfile and resume= on the
#   kernel command line), and the kernel command line needs `quiet splash`.
# - Face unlock for sudo/swaylock needs the hand edits to /etc/pam.d/system-auth
#   described in system/HOWDY-FACE-AUTH.md.
# - The hyprglass Hyprland plugin is built by hand into
#   ~/.local/share/hyprglass/ (hyprland.lua loads it at startup).
# - After reboot: `sudo tailscale up` once, so the ~/server mount can reach novahome.
sudo mkinitcpio -P

# Firewall: ufw, deny incoming by default
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default deny routed
sudo ufw allow 22
sudo ufw allow 1714:1764/tcp # KDE Connect
sudo ufw allow 1714:1764/udp
sudo ufw allow 3000
sudo ufw allow 3001
sudo ufw allow in on wlan0 to 224.0.0.251 port 5353 proto udp  # mDNS
sudo ufw allow in on wlan0 to 239.255.255.250 port 1900 proto udp  # SSDP
sudo ufw allow in on wlan0 from 192.168.220.0/24
sudo ufw --force enable
sudo systemctl enable ufw.service

sudo reboot
