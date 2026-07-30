#!/usr/bin/env bash
# Open a site as a "web app" window in the running Zen instance, or just focus
# that window if it is already open.
#
#   zen-webapp.sh WhatsApp https://web.whatsapp.com
#
# Why this exists: `zen-browser --new-window <url>` unconditionally creates
# another window, so relaunching from the app menu piles up duplicate tabs
# instead of returning to the one already open. Zen has no --target equivalent
# to qutebrowser's IPC (see scripts/qute-webapp.sh), so match on the window
# title over niri IPC instead — every window of one Zen instance shares the
# app_id "zen", so the title is the only thing that distinguishes them.
#
# Pair it with a niri rule; match unanchored, the title gains a "(3) " unread
# prefix and a " — Zen Browser" suffix:
#
#   window-rule {
#       match app-id="zen" title="WhatsApp"
#       block-out-from "screen-capture"
#   }
set -euo pipefail

TITLE=${1:?usage: zen-webapp.sh <title-substring> <url>}
URL=${2:?usage: zen-webapp.sh <title-substring> <url>}

# Most recently focused match wins, so repeat launches return to the same window
# even if the title matches more than one.
find_window() {
    niri msg --json windows 2>/dev/null | jq -r --arg t "$TITLE" '
        map(select(.app_id == "zen" and (.title | test($t; "i"))))
        | sort_by(.focus_timestamp.secs // 0)
        | last | .id // empty' 2>/dev/null || true
}

id=$(find_window)
if [[ -n "$id" ]]; then
    exec niri msg action focus-window --id "$id"
fi

setsid zen-browser --new-window "$URL" >/dev/null 2>&1 &

# Cold start has to wait for Zen itself, not just the window: up to ~15s, but
# exits as soon as the title appears.
for _ in $(seq 1 150); do
    id=$(find_window)
    if [[ -n "$id" ]]; then
        niri msg action focus-window --id "$id" >/dev/null 2>&1 || true
        exit 0
    fi
    sleep 0.1
done
exit 0
