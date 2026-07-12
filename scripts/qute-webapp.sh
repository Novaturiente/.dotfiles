#!/usr/bin/env bash
# Open a site as a "web app" window in the RUNNING qutebrowser instance.
#
#   qute-webapp.sh https://web.whatsapp.com
#   qute-webapp.sh --desktop whatsapp https://web.whatsapp.com   # + .desktop entry
#
# This talks to the existing instance over its IPC socket, so the window shares
# the main process, GPU context, renderer pool and cookie jar: no extra ~500 MB
# per app, and no logging in again. If no instance is running, one starts.
#
# The tab bar hides itself on a single-tab window (tabs.show = "multiple"), so
# the window is already chrome-light. Give it a niri rule to finish the job -
# match on title, since every window of one instance shares an app_id:
#
#   window-rule {
#       match app-id="org.qutebrowser.qutebrowser" title="^WhatsApp"
#       open-on-workspace "chat"
#   }
set -euo pipefail

make_desktop=0
if [[ ${1:-} == "--desktop" ]]; then
	make_desktop=1
	shift
fi

if ((make_desktop)); then
	name=${1:?usage: qute-webapp.sh --desktop <name> <url>}
	url=${2:?usage: qute-webapp.sh --desktop <name> <url>}
	apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
	mkdir -p "$apps"
	cat > "$apps/qutebrowser-$name.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name^}
Exec=$(readlink -f "$0") $url
Icon=qutebrowser
StartupWMClass=org.qutebrowser.qutebrowser
Categories=Network;
EOF
	echo "wrote $apps/qutebrowser-$name.desktop"
else
	url=${1:?usage: qute-webapp.sh [--desktop <name>] <url>}
fi

# --target window: new window in the running instance (IPC), not a new process.
exec qutebrowser --target window "$url"
