#!/usr/bin/env sh

sudo cp novarch /usr/bin/novarch

novarch init

sudo cp system/system/etc/tlp.conf /etc/tlp.conf

# Login manager: Ly (installed from package/windowmanager.yaml).
# Ly is a TUI greeter running on its own VT; it needs no dedicated user.
sudo mkdir -p /etc/ly

# sudo cp system/system/etc/modules-load/ntsync.conf /etc/modules-load.d/ntsync.conf

# sudo cp ./system/system/etc/systemd/sleep.conf /etc/systemd/sleep.conf

sudo cp ./scripts/battery-limit.sh /usr/local/bin/battery-limit.sh
sudo chmod +x /usr/local/bin/battery-limit.sh
sudo cp ./system/system/etc/systemd/system/battery-limit.service /etc/systemd/system/battery-limit.service
sudo cp ./system/system/etc/systemd/system/battery-limit.timer /etc/systemd/system/battery-limit.timer

mkdir -p ~/.config

stow -d ~/.dotfiles -t ~ nova

# Colours for every application, plus /etc/ly/config.ini and the Plymouth boot
# splash. Reads system/themes/current, so a fresh machine comes up on whichever
# theme is committed. Switch later with scripts/theme.sh <name> or Mod+Shift+T.
./scripts/theme.sh "$(cat system/themes/current)" --system

sudo systemctl enable ly@tty2.service

systemctl --user enable batsignal.service
systemctl --user mask pulseaudio.service pulseaudio.socket

sudo systemctl enable battery-limit.timer

# Set fish as default login shell
chsh "$(whoami)" -s "$(which zsh)"

# pkgfile: command-not-found handler + package/binary completion database
sudo pkgfile --update
sudo systemctl enable --now pkgfile-update.timer

# fish: generate completions from installed man pages (Gap 1)
fish -c 'fish_update_completions'

sudo mkinitcpio -P

sudo iptables -P INPUT DROP
sudo iptables -P OUTPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 1714:1764 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 1714:1764 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables-save | sudo tee /etc/iptables/rules.v4

sudo reboot
