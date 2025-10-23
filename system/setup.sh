#!/usr/bin/env sh

sudo cp novarch /usr/bin/novarch

novarch init

sudo cp system/etc/tlp.conf /etc/tlp.conf

sudo cp system/etc/ly/config.ini /etc/ly/config.ini

sudo cp system/etc/modules-load/ntsync.conf /etc/modules-load.d/ntsync.conf

sudo cp ./system/etc/systemd/sleep.conf /etc/systemd/sleep.conf

sudo cp ./system/etc/modprobe.d/nvidia-sleep.conf /etc/modprobe.d/nvidia-sleep.conf

mdkir ~/.config

# git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs
#
# ~/.config/emacs/bin/doom install

# rm -rf ~/.config/doom

stow -d ~/.dotfiles -t ~ nova

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

sudo systemctl enable ly

systemctl --user enable batsignal.service

sudo systemctl enable nvidia-resume.service

chsh "$(whoami)" -s "$(which zsh)"

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
