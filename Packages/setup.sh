#!/usr/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Symbols
CHECK="✓"
CROSS="✗"
WARNING="⚠"
INFO="ℹ"
ARROW="➤"
PACKAGE="📦"
INSTALL="⬇"
REMOVE="⬆"
GEAR="⚙"

SYSTEM_FILE=".system"
system_exists=false
[[ -f "$SYSTEM_FILE" ]] && system_exists=true

# Handle missing files
if [[ "$update_exists" == false && "$system_exists" == false ]]; then
    echo -e "${RED}${CROSS} Error: Both files '$UPDATE_FILE' and '$SYSTEM_FILE' are missing!${NC}"
    exit 1
elif [[ "$update_exists" == false ]]; then
    echo -e "${YELLOW}${WARNING} File '$UPDATE_FILE' not found. Copying '$SYSTEM_FILE' to '$UPDATE_FILE'${NC}"
    cp "$SYSTEM_FILE" "$UPDATE_FILE"
    echo -e "${GREEN}${CHECK} File copied successfully${NC}"
    exit 0
elif [[ "$system_exists" == false ]]; then
    echo -e "${YELLOW}${WARNING} File '$SYSTEM_FILE' not found. Creating '$SYSTEM_FILE'${NC}"
    touch $SYSTEM_FILE
    echo -e "${GREEN}${CHECK} File created successfully${NC}"
    exit 0
fi

echo -e "${YELLOW}${INFO} Updating keyring ${NC}"
sudo pacman-key --init
sudo pacman-key --refresh-keys
sudo pacman -Sy --noconfirm reflector
sudo reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
sudo pacman -Sy --noconfirm archlinux-keyring

echo -e "${BLUE}${GEAR} Adding chaotic-aur ${NC}"
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB
sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

sudo cp ./pacman.conf /etc/pacman.conf

sudo pacman -Syyu

./install_packages.sh

echo -e "${GREEN}${CHECK} ALL DOME REBOOT NOW ${NC}"
