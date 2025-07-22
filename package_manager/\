import os
import subprocess

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


def run_command(command):
    """
    Runs a shell command on Linux and returns the output or error.
    
    Args:
        command (str or list): The command to execute.
        
    Returns:
        dict: Contains 'stdout', 'stderr', 'exit_code'
    """
    try:
        result = subprocess.run(
            command,
            shell=isinstance(command, str),  # If it's a string, use shell=True
            check=False,  # Avoid raising exception on non-zero exit
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        return {
            'stdout': result.stdout.strip(),
            'stderr': result.stderr.strip(),
            'exit_code': result.returncode
        }

    except Exception as e:
        return {
            'stdout': '',
            'stderr': str(e),
            'exit_code': -1
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
                package = line.replace('-','').strip()
                packages.append(package)
    else:
        print("Packages file not found")
    
    if os.path.isfile(system_file):
        print("Reading system")
        with open(system_file, 'r') as f:
            content = f.read().split('\n')
    
        for line in content:
            if line.startswith('-'):
                package = line.replace('-','').strip()
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
        print("Reflector installed")
    else:
        output = run_command('sudo pacman -Sy')
        print(output)

        output = run_command('sudo pacman -S reflector')
        print(output)
            
reflector_check()
processFiles(packages_file,system_file)
