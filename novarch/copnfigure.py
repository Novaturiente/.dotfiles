import subprocess
import os
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

script_dir = os.path.abspath(os.path.dirname(__file__))


def run_command(command, check=True):

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


def copy_configurations():

    # Copy system configurations
    file = os.path.join(script_dir, "system/etc/greetd/config.toml")
    run_command(f"sudo cp {file} /etc/greetd/config.toml", False)

    file = os.path.join(
        script_dir, "system/etc/modprobe.d/nvidia-power-management.conf"
    )
    run_command(f"sudo cp {file} /etc/modprobe.d/nvidia-power-management.conf", False)

    file = os.path.join(script_dir, "system/etc/modules-load/ntsync.conf")
    run_command(f"sudo cp {file} /etc/modules-load.d/ntsync.conf", False)

    file = os.path.join(script_dir, "system/etc/tlp.conf")
    run_command(f"sudo cp {file} /etc/tlp.conf", False)

    # Link user configurations
    subprocess.run("mkdir ~/.config", shell=True)

    # Install Doom emacs
    run_command(
        "git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs"
    )
    run_command("~/.config/emacs/bin/doom install")

    run_command("rm -rf ~/.config/doom")

    subprocess.run("stow -t ~ nova", cwd=os.path.dirname(script_dir), shell=True)

    # Install tmux tpm
    run_command(
        "git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm", False
    )

    run_command("sudo systemctl enable greetd")

    run_command("chsh -s $(which zsh)")
