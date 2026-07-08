#!/usr/bin/env bash
# Rewrite WinApps-generated .desktop entries so they launch through
# winapp-boxed.sh (nested labwc) instead of raw `winapps`. This makes xdg-open
# / file-manager "open with" use the labwc container, avoiding the
# xwayland-satellite RAIL bugs (resize loop, dead focus, broken dropdowns).
#
# Idempotent. Re-run after `winapps-apps.sh add` (which regenerates entries).
# Skips the 'windows' full-desktop entry — it is not RAIL and needs no boxing.
set -euo pipefail

BOXED="$HOME/.dotfiles/scripts/winapp-boxed.sh"
WINAPPS_BIN="$HOME/.local/bin/winapps"
APPS_DIR="$HOME/.local/share/applications"

[ -x "$BOXED" ] || { echo "missing $BOXED"; exit 1; }

changed=0
for f in "$APPS_DIR"/*.desktop; do
    [ -e "$f" ] || continue
    grep -q "^Exec=${WINAPPS_BIN} " "$f" || continue
    app=$(sed -n "s|^Exec=${WINAPPS_BIN} \([^ ]*\).*|\1|p" "$f" | head -1)
    [ -n "$app" ] || continue
    [ "$app" = "windows" ] && continue                       # full desktop, no RAIL
    [ -d "$HOME/.local/share/winapps/apps/$app" ] || continue # only real apps
    sed -i "s|^Exec=${WINAPPS_BIN} ${app} .*|Exec=${BOXED} ${app} %f|" "$f"
    echo "boxified: $(basename "$f") -> $app"
    changed=1
done

[ "$changed" = 1 ] || echo "no winapps app entries needed boxifying"
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS_DIR" 2>/dev/null || true
