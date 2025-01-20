from ast import keyword
from screeninfo import get_monitors
import os

monitors = get_monitors()

if len(monitors) > 1:
    print(f"{len(monitors)} monitors connected")
    os.system("hyprctl keyword monitor eDP-1, disable")
else:
    print(f"{len(monitors)} monitors connected")
    os.system("hyprctl keyword monitor eDP-1, 1920x1080@60,0x0,1")
