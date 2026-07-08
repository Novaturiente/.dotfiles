#!/usr/bin/env bash
# Manage WinApps application launchers on this PC.
#   winapps-apps.sh          list current launchers
#   winapps-apps.sh add      scan the VM and pick new apps to add (interactive), then boxify
#   winapps-apps.sh remove   pick launchers to remove (fzf multi-select with Tab)
#   winapps-apps.sh boxify   re-route app .desktop entries through the labwc container
set -euo pipefail

APPS_DIR="$HOME/.local/share/applications"

winapps_entries() {
    grep -l "/winapps " "$APPS_DIR"/*.desktop 2>/dev/null \
        | while read -r f; do basename "$f" .desktop; done
}

case "${1:-list}" in
    add)
        bash "$HOME/.local/src/winapps/setup.sh" --user --add-apps
        # Route new app entries through the labwc container (dodges RAIL bugs).
        bash "$HOME/.dotfiles/scripts/winapps-boxify.sh"
        ;;
    boxify)
        bash "$HOME/.dotfiles/scripts/winapps-boxify.sh"
        ;;
    remove)
        sel=$(winapps_entries | fzf --multi --prompt="remove launcher> ") || exit 0
        while read -r app; do
            [ -n "$app" ] || continue
            rm -f "$APPS_DIR/$app.desktop"
            rm -rf "$HOME/.local/share/winapps/apps/$app"
            echo "removed $app"
        done <<< "$sel"
        ;;
    list)
        winapps_entries
        ;;
    *)
        echo "usage: $(basename "$0") [list|add|remove]" >&2
        exit 1
        ;;
esac
