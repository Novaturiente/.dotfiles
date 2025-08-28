#!/bin/bash

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

# File names
UPDATE_FILE="update"
SYSTEM_FILE=".system"

# Function to extract package names (ignore lines starting with #)
extract_packages() {
    local file="$1"
    grep -v '^#' "$file" | grep -v '^[[:space:]]*$' | sort
}

echo -e "${CYAN}${GEAR} Package Manager Script Started${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if files exist
update_exists=false
system_exists=false

[[ -f "$UPDATE_FILE" ]] && update_exists=true
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

echo -e "${GREEN}${CHECK} Both files found. Comparing package lists...${NC}"

# Extract package names from both files
update_packages=$(extract_packages "$UPDATE_FILE")
system_packages=$(extract_packages "$SYSTEM_FILE")

# Create temporary files for comparison
temp_update=$(mktemp)
temp_system=$(mktemp)
temp_installed=$(mktemp)

echo "$update_packages" > "$temp_update"
echo "$system_packages" > "$temp_system"

# Get installed packages using pacman -Q and extract package names only
echo -e "\n${BLUE}${INFO} Getting list of installed packages...${NC}"
pacman -Q | awk '{print $1}' | sort > "$temp_installed"
installed_count=$(wc -l < "$temp_installed")
echo -e "${GREEN}${CHECK} Found $installed_count installed packages${NC}"

# Find packages to be added (in update but not in system)
packages_to_add_raw=$(comm -23 "$temp_update" "$temp_system")

# Find packages to be removed (in system but not in update)
packages_to_remove_raw=$(comm -13 "$temp_update" "$temp_system")

# Filter packages to add - remove those already installed
if [[ -n "$packages_to_add_raw" ]]; then
    temp_add_raw=$(mktemp)
    echo "$packages_to_add_raw" > "$temp_add_raw"
    packages_to_add=$(comm -23 "$temp_add_raw" "$temp_installed")
    packages_already_installed=$(comm -12 "$temp_add_raw" "$temp_installed")
    rm -f "$temp_add_raw"
else
    packages_to_add=""
    packages_already_installed=""
fi

# Filter packages to remove - keep only those currently installed
if [[ -n "$packages_to_remove_raw" ]]; then
    temp_remove_raw=$(mktemp)
    echo "$packages_to_remove_raw" > "$temp_remove_raw"
    packages_to_remove=$(comm -12 "$temp_remove_raw" "$temp_installed")
    packages_not_installed=$(comm -23 "$temp_remove_raw" "$temp_installed")
    rm -f "$temp_remove_raw"
else
    packages_to_remove=""
    packages_not_installed=""
fi

# Display results
echo
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${INSTALL} PACKAGES TO BE ADDED${NC} ${MAGENTA}(not currently installed)${NC}"
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ -n "$packages_to_add" ]]; then
    echo -e "${CYAN}$packages_to_add${NC}"
    echo
    echo -e "${GREEN}${PACKAGE} Total packages to add: $(echo "$packages_to_add" | wc -l)${NC}"
else
    echo -e "${YELLOW}${INFO} No packages to add${NC}"
fi

if [[ -n "$packages_already_installed" ]]; then
    echo
    echo -e "${YELLOW}${WARNING} Packages marked to add but already installed:${NC}"
    echo -e "${MAGENTA}Count: $(echo "$packages_already_installed" | wc -l)${NC}"
    echo -e "${YELLOW}$packages_already_installed${NC}"
fi

echo
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}${REMOVE} PACKAGES TO BE REMOVED${NC} ${MAGENTA}(currently installed)${NC}"
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ -n "$packages_to_remove" ]]; then
    echo -e "${CYAN}$packages_to_remove${NC}"
    echo
    echo -e "${RED}${PACKAGE} Total packages to remove: $(echo "$packages_to_remove" | wc -l)${NC}"
else
    echo -e "${YELLOW}${INFO} No packages to remove${NC}"
fi

if [[ -n "$packages_not_installed" ]]; then
    echo
    echo -e "${YELLOW}${WARNING} Packages marked to remove but not installed:${NC}"
    echo -e "${MAGENTA}Count: $(echo "$packages_not_installed" | wc -l)${NC}"
    echo -e "${YELLOW}$packages_not_installed${NC}"
fi

# Generate pacman commands for easy execution
echo
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}${GEAR} GENERATED PACMAN COMMANDS${NC}"
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ -n "$packages_to_add" ]]; then
    add_command="sudo pacman -S $(echo "$packages_to_add" | tr '\n' ' ')"
    echo -e "${GREEN}${INSTALL} To install packages:${NC}"
    echo -e "${WHITE}$add_command${NC}"
fi

if [[ -n "$packages_to_remove" ]]; then
    remove_command="sudo pacman -Rns $(echo "$packages_to_remove" | tr '\n' ' ')"
    echo
    echo -e "${RED}${REMOVE} To remove packages:${NC}"
    echo -e "${WHITE}$remove_command${NC}"
fi

# Ask for confirmation and execute commands if confirmed
if [[ -n "$packages_to_add" || -n "$packages_to_remove" ]]; then
    echo
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}${WARNING} CONFIRMATION REQUIRED${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e -n "${CYAN}${ARROW} Do you want to execute the above pacman commands? ${WHITE}(y/Y to confirm):${NC} "
    read confirmation
    
    if [[ "$confirmation" == "y" || "$confirmation" == "Y" ]]; then
        echo -e "\n${GREEN}${GEAR} Executing commands...${NC}"
        
        status=0
        
        # Execute install command if there are packages to add
        if [[ -n "$packages_to_add" ]]; then
            echo -e "${GREEN}${INSTALL} Installing packages...${NC}"
            sudo pacman -S $(echo "$packages_to_add" | tr '\n' ' ')
            if [[ $? -ne 0 ]]; then
                status=1
            fi
        fi
        
        # Execute remove command if there are packages to remove
        if [[ -n "$packages_to_remove" ]]; then
            echo -e "${RED}${REMOVE} Removing packages...${NC}"
            sudo pacman -Rs $(echo "$packages_to_remove" | tr '\n' ' ')
            if [[ $? -ne 0 ]]; then
                status=1
            fi
        fi
        
        if [[ $status -eq 0 ]]; then
            echo -e "\n${GREEN}${CHECK} Package operations completed!${NC}"
            cp $UPDATE_FILE $SYSTEM_FILE
            echo "Copying configurations"
            ./configure.sh
        else
            echo -e "\n${RED}${CROSS} Package operations failed. Not copying the file.${NC}"
        fi
    else
        echo -e "${YELLOW}${CROSS} Operation cancelled by user${NC}"
    fi
else
    echo -e "\n${BLUE}${INFO} No packages to install or remove. Nothing to do${NC}"
fi

# Cleanup temporary files
rm -f "$temp_update" "$temp_system" "$temp_installed"


echo -e "\n${CYAN}${CHECK} Script completed successfully${NC}"

