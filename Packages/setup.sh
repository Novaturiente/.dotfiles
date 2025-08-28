#!/usr/bin/bash

sudo pacman-key --init
sudo pacman-key refresh-keys

sudo pacman -Sy reflector
sudo reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

sudo pacman -Sy archlinux-keyring

./add_chotic.sh

sudo pacman -Syyu

./install_packages.sh
