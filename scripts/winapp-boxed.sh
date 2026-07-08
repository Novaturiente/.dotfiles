#!/usr/bin/env bash
# Run a WinApps app inside a nested labwc so its RAIL windows use labwc's own
# Xwayland instead of xwayland-satellite. This avoids the satellite resize-loop,
# focus dead-zone, and broken-dropdown bugs — at the cost of the app living
# inside a labwc container window rather than seamless on niri.
#
# Usage: winapp-boxed.sh <app> [file]
#   <app>  = winapps app dir name, e.g. excel-o365 (see ~/.local/share/winapps/apps/)
#   [file] = optional file under $HOME to open in the app
set -euo pipefail

command -v labwc >/dev/null || { echo "labwc not installed: sudo pacman -S labwc"; exit 1; }
command -v xfreerdp3 >/dev/null || { echo "xfreerdp3 not installed"; exit 1; }

# shellcheck source=/dev/null
source ~/.config/winapps/winapps.conf
APP="${1:?usage: winapp-boxed <app> [file]}"
FILE="${2:-}"

INFO="$HOME/.local/share/winapps/apps/$APP/info"
[ -f "$INFO" ] || { echo "unknown app '$APP' (no $INFO)"; exit 1; }
# shellcheck source=/dev/null
source "$INFO"   # provides WIN_EXECUTABLE, FULL_NAME

# Build the /app: argument exactly like WinApps: program/name unquoted (bash
# preserves the embedded spaces, FreeRDP splits sub-fields on commas), and only
# the file path wrapped in literal quotes (so Windows gets it as one argument).
# Extra quotes around program/name cause RAIL_EXEC_E_FILE_NOT_FOUND.
app_arg="/app:program:${WIN_EXECUTABLE},hidef:on,name:${FULL_NAME}"
if [ -n "$FILE" ]; then
    [ -e "$FILE" ] || { echo "file not found: $FILE"; exit 1; }
    ABS=$(realpath "$FILE")
    case "$ABS" in
        "$HOME"/*) : ;;
        *) echo "file must be under \$HOME (only that is shared to the VM)"; exit 1 ;;
    esac
    WPATH=$(printf '%s' "$ABS" | sed -e "s|^${HOME}|\\\\\\\\tsclient\\\\home|" -e 's|/|\\|g')
    app_arg="${app_arg},cmd:\"${WPATH}\""
fi

CFG=$(mktemp -d)
LABWC_PID=""

cleanup() {
    # Tear down the nested labwc (and its Xwayland) on any exit path.
    if [ -n "$LABWC_PID" ] && kill -0 "$LABWC_PID" 2>/dev/null; then
        kill "$LABWC_PID" 2>/dev/null || true
        for _ in $(seq 1 20); do
            kill -0 "$LABWC_PID" 2>/dev/null || break
            sleep 0.1
        done
        kill -9 "$LABWC_PID" 2>/dev/null || true
    fi
    rm -rf "$CFG"
}
trap cleanup EXIT INT TERM

# labwc's autostart runs with DISPLAY set to labwc's own Xwayland; capture it.
cat > "$CFG/autostart" <<EOF
echo "\$DISPLAY" > "$CFG/display"
EOF

# Maximize the app window on map so it fills labwc's output — and keeps filling
# it when the niri container window is resized (labwc re-maximizes to the new
# output size, which pushes a resize down to the RAIL window).
cat > "$CFG/rc.xml" <<'EOF'
<?xml version="1.0"?>
<labwc_config>
  <windowRules>
    <windowRule identifier="*" matchOnce="no">
      <action name="Maximize" direction="both"/>
    </windowRule>
  </windowRules>
</labwc_config>
EOF

labwc -C "$CFG" &
LABWC_PID=$!

# Wait for labwc's Xwayland to come up and report its DISPLAY (or labwc to die).
DISP=""
for _ in $(seq 1 100); do
    if [ -s "$CFG/display" ]; then DISP=$(cat "$CFG/display"); break; fi
    kill -0 "$LABWC_PID" 2>/dev/null || { echo "labwc exited before Xwayland started"; exit 1; }
    sleep 0.1
done
[ -n "$DISP" ] || { echo "labwc Xwayland did not start in time"; exit 1; }

# Run the app on labwc's Xwayland (not niri's satellite). Blocks until it closes.
# No +auto-reconnect: we want xfreerdp to exit when the app window closes so the
# container tears down. cleanup() runs on exit regardless.
DISPLAY="$DISP" xfreerdp3 /v:"$RDP_IP" /u:"$RDP_USER" /p:"$RDP_PASS" /cert:tofu \
    +home-drive +clipboard /sound \
    /wm-class:"$FULL_NAME" \
    "$app_arg" || true
