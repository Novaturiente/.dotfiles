import os

with open('packages.nix', 'r') as f:
    contents = f.readlines()

for line in contents:
    if "#" not in line:
        if line.startswith(" "):
            if line != "":
                out = os.popen(f"pacman -Q {line}").read()
                if "error" in out:
                    print(f"{line} Not installed")
                else:
                    print(out)


                
