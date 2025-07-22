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
        print("Reading packages list")
        with open(packages_file, 'r') as f:
            content = f.read().split('\n')
    
        for line in content:
            if line.startswith('-'):
                package = line[1:].strip()
                packages.append(package)
    else:
        print("Packages file not found")
    
    if os.path.isfile(system_file):
        print("Reading system")
        with open(system_file, 'r') as f:
            content = f.read().split('\n')
    
        for line in content:
            if line.startswith('-'):
                package = line[1:].strip()
                system.append(package)
    else:
        print("No existing system starting fresh")

    packages_to_install = []
    for i in packages:
        if i not in system and i not in installed_packages:
            packages_to_install.append(i)

    packages_to_remove = []
    for i in system:
        if i not in packages and i in installed_packages:
            packages_to_remove.append(i)

    print(f"Install : {packages_to_install}")
    print(f"Remove : {packages_to_remove}")

    return packages_to_install, packages_to_remove


def reflector_check():
    if "reflectord" in installed_packages:
        print(f"{SUCESS} Reflector already installed")
    else:
        run_command_realtime("sudo pacman -Sy")
        output = run_command_realtime("sudo pacman -S --noconfirm reflector")
        if output['exit_code'] != 0:
            print(f"{ERROR} Error : {output}")
            exit(1)
        else:
            print(f"{SUCESS} Reflecort installed")
            
reflector_check()
processFiles(packages_file,system_file)
