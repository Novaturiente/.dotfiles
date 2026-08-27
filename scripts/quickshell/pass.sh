#!/usr/bin/env bash
# Toggle the Quickshell password manager. Captures the focused browser domain
# BEFORE our window steals focus, passes it as the search prefill, and starts
# the daemon if it isn't running yet. Bound to Mod+Shift+P.
set -euo pipefail
CFG="pass"
CTL="$HOME/.dotfiles/scripts/quickshell/passctl.sh"

domain=$(bash "$CTL" focused-domain 2>/dev/null || true)

# Ask the pinentry shim to try face unlock first. Same reason as the unlock below:
# this must happen before the UI opens, or the polkit dialog renders underneath it.
# The shim consumes the flag, so this only ever affects the next unlock.
: > "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/rbw-face-request" 2>/dev/null || true

# Unlock BEFORE opening the UI: the pass overlay + DMS layer render on top of the
# pinentry dialog, hiding the PIN prompt. Do it here so pinentry is visible; the
# vault is then unlocked when the window opens (list/sync no-op on the unlock).
bash "$CTL" unlock 2>/dev/null || true

# daemon up -> open with prefill
if qs -c "$CFG" ipc call pass open "$domain" 2>/dev/null; then
    exit 0
fi

# not running -> start detached daemon, wait for IPC, then open
qs -c "$CFG" -d >/dev/null 2>&1
for _ in $(seq 1 50); do
    if qs -c "$CFG" ipc call pass open "$domain" 2>/dev/null; then
        exit 0
    fi
    sleep 0.1
done
exit 1
