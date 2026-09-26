#!/usr/bin/env sh

sudo cp novarch /usr/bin/novarch

novarch init

# System files: system/system mirrors /, so copy the whole tree onto it
# (tlp.conf, sleep.conf, zram, docker, udev, units, /usr/local helpers, polkit, pam).
sudo cp -r system/system/. /
sudo chmod 0440 /etc/sudoers.d/vpn-run

# Login manager: Ly (installed from package/windowmanager.yaml).
# Ly is a TUI greeter running on its own VT; it needs no dedicated user.
sudo mkdir -p /etc/ly

mkdir -p ~/.config

stow -d ~/.dotfiles -t ~ nova

# Colours for every application, plus /etc/ly/config.ini and the Plymouth boot
# splash. Reads system/themes/current, so a fresh machine comes up on whichever
# theme is committed. Switch later with scripts/theme.sh <name> or Mod+Shift+T.
./scripts/theme.sh "$(cat system/themes/current)" --system

sudo systemctl daemon-reload
sudo systemctl enable ly@tty2.service

systemctl --user mask pulseaudio.service pulseaudio.socket

sudo systemctl enable battery-limit.timer paccache.timer

# Set zsh as default login shell
chsh "$(whoami)" -s "$(which zsh)"

# pkgfile: command-not-found handler + package/binary completion database
sudo pkgfile --update
sudo systemctl enable --now pkgfile-update.timer

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
