#!/usr/bin/env bash
# Recover a Hyprland session stuck on a lock screen that rejects every password.
# Run as your user from another TTY (not with sudo; it asks for sudo itself).
# 1. Installs the repo's /etc/pam.d/swaylock if the live one is missing or differs
#    (a dangling link there makes PAM fall back to pam_deny).
# 2. Kills any stuck swaylock, lets Hyprland accept a new lock client, relaunches it.
set -euo pipefail

repo_pam="$HOME/.dotfiles/system/system/etc/pam.d/swaylock"
live_pam=/etc/pam.d/swaylock

if ! cmp -s "$repo_pam" "$live_pam"; then
    echo "Installing $live_pam from repo"
    sudo rm -f "$live_pam"
    sudo install -m644 "$repo_pam" "$live_pam"
fi

pkill -x swaylock || true

hypr=(hyprctl --instance 0)
"${hypr[@]}" keyword misc:allow_session_lock_restore 1
"${hypr[@]}" dispatch exec "$HOME/.dotfiles/scripts/lock.sh"

echo "Lock relaunched. Switch back to the Hyprland TTY and unlock."
