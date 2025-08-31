#!/usr/bin/python

import subprocess
import os
import sys
import json
import time

# ANSI color codes
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
GREEN = "\033[92m"
RESET = "\033[0m"
red_cross = f"{RED}✗{RESET}"
yellow_warning = f"{YELLOW}⚠{RESET}"
blue_gear = f"{BLUE}⚙{RESET}"
green_check = f"{GREEN}✓{RESET}"

package_list = [
    'base_system',
    'hyprland',
    'internet',
    'terminal_tools',
    'virtual_management',
]

script_dir = os.path.abspath(os.path.dirname(__file__))

# os.system("sudo echo '\n##### STARTING SCRIPT #####\n'")

def run_command (command, check=True):
    i = 1
    while True:
        result = subprocess.run(command, shell=True)

        if result.returncode != 0:
            print(f"{red_cross} Error running '{command}'")
            if check:
                if i == 3:
                    print(f"{red_cross} '{command}' failed to complete exiting script")
                    exit(1)
                i += 1
                time.sleep(5)
            else:
                break
        else:
            break


def chaotic_aur_setup():
    chaotic_installed = False
    with open('/etc/pacman.conf', 'r') as f:
        lines = f.readlines()

    for line in lines:
        if line.startswith("["):
            if "chaotic-aur" in line:
                chaotic_installed = True
                break

    if not chaotic_installed:
        print(f"{blue_gear} Configuring Chaotic-aur")

        run_command("sudo pacman-key --init")
        run_command("sudo pacman -Sy --noconfirm archlinux-keyring")
        run_command("sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com")
        run_command("sudo pacman-key --lsign-key 3056513887B78AEB")
        run_command("sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'")
        run_command("sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'")

        pacmanconf = os.path.join(script_dir,"pacman.conf")
        run_command(f"sudo cp {pacmanconf} /etc/pacman.conf")
        run_command("sudo pacman -Syu --noconfirm")
        run_command("sudo pacman -Sy --noconfirm reflector")
        run_command("sudo pacman -Sy --noconfirm archlinux-keyring")
    else:
        print(f"{green_check} Chaotic-aur already configured")


def upadte_system():
    run_command("sudo reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist")
    run_command("sudo pacman -Syu --noconfirm")


def install_packages():

    print("📦 Checking for paru")
    paru_check = os.popen("pacman -Q paru").readlines()
    if len(paru_check) > 0:
        print(f"{green_check} paru already installed")
    else:
        print(f"{yellow_warning} paru not installed")
        run_command("sudo pacman -S --noconfirm paru")

    
    existing_packages = []
    systemfile = os.path.join(script_dir, 'system.json')
    if os.path.exists(systemfile):
        with open(systemfile, 'r') as f:
            existing_packages = json.load(f)
    else:
        print(f"{yellow_warning} Cuttent system does not exist starting fresh")

    selected_packages = []
    for package in package_list:
        path = os.path.join(script_dir, package)
        if os.path.exists(path):
            with open(path, 'r') as f:
                lines = f.readlines()
            for line in lines:
                if line.strip() and not line.strip().startswith("#"):
                    selected_packages.append(line.strip())
        else:
            print(f"{red_cross} {package} not available")
            exit(1)
        
    installed_packages = []
    result = subprocess.run(['pacman', '-Q'], stdout=subprocess.PIPE, text=True)
    pkgs = result.stdout.split("\n")
    for pkg in pkgs:
        package = pkg.split(" ")[0]
        if package != "":
            installed_packages.append(package)
    
    tobe_installed = []
    tobe_removed = []

    for selected in selected_packages:
        if selected not in installed_packages and selected not in existing_packages:
            tobe_installed.append(selected)

    for existing in existing_packages:
        if existing not in selected_packages and existing in installed_packages:
            result = subprocess.run(['pactree', '-rlo', existing], stdout=subprocess.PIPE, text=True)
            dependancy_list = result.stdout.split("\n")
            if len(dependancy_list) == 2:
                tobe_removed.append(existing)

    install_command = ['paru', '-S', '--noconfirm']
    install_confirmation = "N"
    if len(tobe_installed) > 0:
        install_command.extend(tobe_installed)
        install_confirmation = input(f"\n{tobe_installed}\n Do you want to proceed with installing above packages? [Y/n] ⬇ :")

    remove_command = ['paru', '-Rns', '--noconfirm']
    remove_confirmation = "N"
    if len(tobe_removed) > 0: 
        remove_command.extend(tobe_removed)
        remove_confirmation = input(f"\n{tobe_removed}\n Do you want to proceed with removing above packages? [Y/n] ⬆ :")

    if install_confirmation.lower == "y" or install_confirmation == "":

        for i in range(3):
            result = subprocess.run(install_command, text=True)
            if result.returncode == 0:
                break  # Success, exit loop
            else:
                print(f"{red_cross} Error installing packages, retrying {i + 1}")
                time.sleep(3)
        else:
            print(f"{red_cross} Failed after 3 tries, exiting.")
            exit(1)

    if remove_confirmation.lower == "y" or remove_confirmation == "":
        for i in range(3):
            result = subprocess.run(remove_command, text=True)
            if result.returncode != 0:
                ask = input(f"{red_cross} Error removing packages do you want to retry ? : ")
                if ask.lower == "y":
                    time.sleep(3)
                else:
                    exit(1)
            else:
                break

    if len(tobe_installed) == 0 and len(tobe_removed) == 0:
        print(f"{green_check} Package list uptodate no packages to install or remove")

    with open(systemfile, 'w') as f:
        json.dump(selected_packages, f)


def copy_configurations():

    file = os.path.join(script_dir, "system/etc/greetd/config.toml")
    run_command(f"sudo cp {file} /etc/greetd/config.toml", False)

    file = os.path.join(script_dir, "system/etc/modprobe.d/nvidia-power-management.conf")
    run_command(f"sudo cp {file} /etc/modprobe.d/nvidia-power-management.conf", False)

    file = os.path.join(script_dir, "system/etc/modules-load/ntsync.conf")
    run_command(f"sudo cp {file} /etc/modules-load.d/ntsync.conf", False)

    file = os.path.join(script_dir, "system/etc/tlp.conf")
    run_command(f"sudo cp {file} /etc/tlp.conf", False)
    
    subprocess.run("mkdir ~/.config", shell=True)

    subprocess.run("stow -t ~ nova", cwd=os.path.dirname(script_dir), shell=True)

    run_command("git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm", False)

    run_command("sudo systemctl enable greetd")

    run_command("chsh -s $(which zsh)")

def main():
    if len(sys.argv) != 2:
        print(f"""
{yellow_warning} Provide one of the argument

init      : setup entire system from scratch
update    : update packages
install   : Install/Remove packages
        """)
        exit(1)

    if sys.argv[1] == "init":
        chaotic_aur_setup()
        upadte_system()
        install_packages()
        copy_configurations()
    elif sys.argv[1] == "update":
        print(f"\n{blue_gear} Updating system")
        upadte_system()
        install_packages()
    elif sys.argv[1] == "install":
        print(f"\n{blue_gear} Installing updated package list")
        install_packages()
    else:
        print(f"""
{yellow_warning} Invalid argument provided

init      : setup entire system from scratch
update    : update packages
install   : Install/Remove packages
        """)
        exit(1)
    

if __name__ == '__main__':
    main()
