#!/bin/bash

# Function to check and add Chaotic-AUR repo
setup_chaotic_aur() {
    if ! grep -q "^\[chaotic-aur\]" /etc/pacman.conf; then
        echo -e "\n[+] Adding Chaotic-AUR repository..."
        sudo pacman-key --init
        sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
        sudo pacman-key --lsign-key 3056513887B78AEB

        sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
        sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
        echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf

        sudo pacman -Sy

        echo -e "\n[✓] Chaotic-AUR enabled!"
    else
        echo -e "\n[✓] Chaotic-AUR already configured."
    fi
}

# Function to update mirrors using reflector
update_mirrors() {
    echo -e "\n[+] Updating mirrorlist for optimal speeds..."
    if ! command -v reflector &>/dev/null; then
        info "Installing reflector..."
        sudo pacman -S --noconfirm reflector
    fi
    
    # Backup current mirrorlist
    sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup.$(date +%Y%m%d)
    sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    echo -e "[✓] Mirrors updated!"
}

# Function to process a file: extract package names (lines starting with '-'), clean them up
process_file() {
    local filename=$1
    grep '^-' "$filename" | sed 's/^-//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

### Main Execution ###

# Step 1: Ensure Chaotic-AUR is available
setup_chaotic_aur

# Step 2: Update system mirrors
update_mirrors

# Step 3: Sync repositories (critical after adding new repos)
echo -e "\n[+] Syncing package databases..."
sudo pacman -Sy

# Step 4: Process package files
packages_list=$(process_file "packages")
system_list=$(process_file "system")

# Step 5: Compare packages
packages_to_install=$(comm -23 <(echo "$packages_list" | sort) <(echo "$system_list" | sort) | tr '\n' ' ')
packages_to_remove=$(comm -13 <(echo "$packages_list" | sort) <(echo "$system_list" | sort) | tr '\n' ' ')

# Trim trailing whitespace
packages_to_install=${packages_to_install% }
packages_to_remove=${packages_to_remove% }

# Step 6: Display results
if [[ -n "$packages_to_install" ]]; then
    count=$(echo "$packages_to_install" | wc -w)
    echo -e "\n[+] $count package(s) to INSTALL:"
    echo "$packages_to_install"
    read -p "Proceed with installation? (y/N) " -n 1 -r
    [[ $REPLY =~ ^[Yy]$ ]] && sudo pacman -Syu --needed $packages_to_install
else
    echo -e "\n[✓] No packages to install."
fi

if [[ -n "$packages_to_remove" ]]; then
    count=$(echo "$packages_to_remove" | wc -w)
    echo -e "\n[-] $count package(s) to REMOVE:"
    echo "$packages_to_remove"
    read -p "Proceed with removal? (y/N) " -n 1 -r
    [[ $REPLY =~ ^[Yy]$ ]] && sudo pacman -Rns $packages_to_remove
else
    echo -e "\n[✓] No packages to remove."
fi

cp packages system
