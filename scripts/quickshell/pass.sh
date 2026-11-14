#!/usr/bin/env bash
# Open the island's password page. Captures the focused browser domain BEFORE
# the island takes the keyboard and passes it as the search prefill.
# Bound to Mod+Shift+P.
set -euo pipefail
CTL="$HOME/.dotfiles/scripts/quickshell/passctl.sh"

domain=$(bash "$CTL" focused-domain 2>/dev/null || true)

# Unlock BEFORE opening the UI: the pass overlay + island layer render on top of the
# pinentry dialog, hiding the PIN prompt. Do it here so pinentry is visible; the
# vault is then unlocked when the window opens (list/sync no-op on the unlock).
bash "$CTL" unlock 2>/dev/null || true

exec qs -c island ipc call island pass "$domain"
