#!/usr/bin/env sh

sudo cp novarch /usr/bin/novarch

sudo novarch init

sudo cp system/etc/tlp.conf /etc/tlp.conf

sudo cp system/etc/ly/config.ini /etc/ly/config.ini

sudo cp system/etc/modules-load/ntsync.conf /etc/modules-load.d/ntsync.conf

sudo cp system/etc/modprobe.d/nvidia-power-management.conf /etc/modprobe.d/nvidia-power-management.conf

mdkir ~/.config

git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs

~/.config/emacs/bin/doom install

rm -rf ~/.config/doom

stow -d ~/.dotfiles -t ~ nova

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

sudo systemctl enable ly

systemctl --user enable batsignal.service

chsh "$(whoami)" -s "$(which zsh)"
