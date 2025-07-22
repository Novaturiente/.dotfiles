import os
import subprocess

NC = "\033[0m"
RED = "\033[31m"
GREEN = "\033[32m"
SUCESS = f"{GREEN}[✓]{NC}"
ERROR = f"{RED}[✗]{NC}" 

script_folder = os.path.dirname(os.path.abspath(__file__))

packages_file = os.path.join(script_folder, 'packages')
system_file = os.path.join(script_folder, 'system')

os.system("pacman -Q > existing")
installed_packages = []
with open('existing', 'r') as f:
    content = f.read().split('\n')

for line in content:
    package = line.split(" ")[0].strip()
    installed_packages.append(package)



def run_command_realtime(command):
    """
    Run a Linux command and stream output in real time.
    
    Args:
        command (str or list): The shell command to execute.
        
    Returns:
        dict: Contains full 'stdout', 'stderr', and 'exit_code'
    """
    process = subprocess.Popen(
        command,
        shell=isinstance(command, str),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
        universal_newlines=True
    )

    stdout_lines = []
    stderr_lines = []

    # Read stdout line by line
    for line in process.stdout:
        print(line, end='')  # Print to console in real time
        stdout_lines.append(line)

    # Read stderr after process completes
    stderr_output = process.stderr.read()
    if stderr_output:
        print("ERROR:", stderr_output.strip())
        stderr_lines.append(stderr_output)

    process.wait()

    return {
        'stdout': ''.join(stdout_lines).strip(),
        'stderr': ''.join(stderr_lines).strip(),
        'exit_code': process.returncode
    }


def processFiles (packages_file, system_file):
    packages = []
    system = []
    if os.path.isfile(packages_file):
        with open(packages_file, 'r') as f:
            content = f.read().split('\n')
    
        for line in content:
            if line.startswith('-'):
                package = line[1:].strip()
                packages.append(package)
    else:
        print(f"{ERROR} Packages file not found")
    
    if os.path.isfile(system_file):
        with open(system_file, 'r') as f:
            content = f.read().split('\n')
    
        for line in content:
            if line.startswith('-'):
                package = line[1:].strip()
                system.append(package)
    else:
        print("[*] No existing system starting fresh")

    packages_to_install = []
    for i in packages:
        if i not in system and i not in installed_packages:
            packages_to_install.append(i)

    packages_to_remove = []
    for i in system:
        if i not in packages and i in installed_packages:
            packages_to_remove.append(i)

    return packages_to_install, packages_to_remove


def reflector_check():
    if "reflector" in installed_packages:
        print(f"{SUCESS} Reflector already installed")
    else:
        run_command_realtime("sudo pacman -Sy")
        output = run_command_realtime("sudo pacman -S --noconfirm reflector")
        if output['exit_code'] != 0:
            print(f"{ERROR} Error : {output['stderr']}")
            exit(1)
        else:
            print(f"{SUCESS} Reflecort installed")
        
    os.system("sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup.$(date +%Y%m%d)")
    update_mirrors = "sudo reflector --country 'India,Germany,France,Netherlands,Sweden' --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist"
    output = run_command_realtime(update_mirrors)
    if output['exit_code'] != 0:
       print(f"{ERROR} Error : {output['stderr']}")
       exit(1)
    else:
       print(f"{SUCESS} Mirrorlist updated")

def configure_chotic_aur():
    found = False
    with open('/etc/pacman.conf', 'r', encoding='utf-8') as f:
        for line in f:
            if '[chaotic-aur]' in line:
                found = True
                break
    if found:
        print(f"{SUCESS} chaotic-aur already configured")
    else:
        output = run_command_realtime('sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com && sudo pacman-key --lsign-key 3056513887B78AEB')
        if output['exit_code'] != 0:
            print(f"{ERROR} Error : {output['stderr']}")
            exit(1)
        
        output = run_command_realtime("sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' && sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'")
        if output['exit_code'] != 0:
            print(f"{ERROR} Error : {output['stderr']}")
            exit(1)
        
        output = run_command_realtime("echo -e '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' | sudo tee -a /etc/pacman.conf")

        run_command_realtime("sudo pacman -Sy")

        print(f"{SUCESS} Configured chaotic-aur")

def install_packages():
    packages_to_install, packages_to_remove = processFiles(packages_file,system_file)
    

    if len(packages_to_install) > 0:
        print(f"Installing : {packages_to_install}")
        install_list = " ".join(packages_to_install)
        install_command = f"sudo pacman -Syu --noconfirm {install_list}"
        os.system(install_command)
        # output = run_command_realtime(install_command)
        # if output['exit_code'] != 0:
        #     print(f"{ERROR} Error : {output['stderr']}")
        #     exit(1)
        # else:
        #     print(f"{SUCESS} Packages installation completed")
    else:
        print(f"{SUCESS} No packages to install")

    if len(packages_to_remove) > 0:
        print(f"Removing : {packages_to_remove}")
        remove_list = " ".join(packages_to_remove)
        remove_command = f"sudo pacman -Rns {remove_list}"
        os.system(remove_command)
        # output = run_command_realtime(remove_command)
        # if output['exit_code'] != 0:
        #     print(f"{ERROR} Error : {output['stderr']}")
        #     exit(1)
        # else:
        #     print(f"{SUCESS} Package removeal completed")

    else:
        print(f"{SUCESS} No packages to remove")


def main():
    configure_chotic_aur()
    reflector_check()
    install_packages()
    os.system("rm existing")
    os.system("cp packages system")

if __name__ == '__main__':
    main()
