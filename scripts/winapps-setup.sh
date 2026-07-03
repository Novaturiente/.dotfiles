#!/usr/bin/env bash
# Set up WinApps client for the Windows 11 VM running on novahome.
# Idempotent: safe to rerun after a laptop reinstall.
# VM side lives on the server: ~/Automation/windows-vm/setup.sh
set -euo pipefail

VM_IP="${VM_IP:-192.168.220.100}"
SRC="$HOME/.local/src/winapps"
CONF="$HOME/.config/winapps/winapps.conf"

sudo pacman -S --needed --noconfirm freerdp git gnu-netcat

if [ -d "$SRC" ]; then
    git -C "$SRC" pull --ff-only
else
    git clone --depth 1 https://github.com/winapps-org/winapps.git "$SRC"
fi

mkdir -p "$(dirname "$CONF")"
if [ ! -f "$CONF" ]; then
    cat > "$CONF" <<EOF
RDP_USER="Nova"
RDP_PASS="novarch"
RDP_IP="$VM_IP"
WAFLAVOR="manual"
RDP_SCALE="100"
RDP_FLAGS="/cert:tofu /sec:tls /sound /microphone /clipboard +home-drive /dvc:urbdrc"
FREERDP_COMMAND="xfreerdp3"
MULTIMON="false"
DEBUG="true"
AUTOPAUSE="off"
PORT_TIMEOUT="20"
EOF
    echo "Wrote default config to $CONF"
else
    echo "Keeping existing config at $CONF"
fi

echo "Checking RDP at $VM_IP:3389..."
if ! nc -z -w5 "$VM_IP" 3389; then
    echo "ERROR: Windows VM not reachable at $VM_IP:3389."
    echo "Start it on the server: ssh nova@novahome '~/Automation/windows-vm/setup.sh'"
    exit 1
fi

bash "$SRC/setup.sh" --user --setupAllOfficiallySupportedApps
echo "Done. Manage launchers with: winapps-apps.sh"
echo "If clipboard passthrough stops working: pkill xwayland-satellite"
echo "(niri respawns it; closes any open X11/WinApps windows first)"
