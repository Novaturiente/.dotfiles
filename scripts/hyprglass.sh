#!/usr/bin/env bash
# hyprglass (Liquid Glass Hyprland plugin) helper.
#   hyprglass.sh load    load the plugin only if it was built for the running
#                        Hyprland; otherwise notify and skip (hyprland.lua start hook)
#   hyprglass.sh build   clone/update, build and install it for the installed
#                        Hyprland; takes effect at the next login
# A plugin built for another Hyprland version crashed Hyprland (SEGV in
# CPluginSystem::unloadPlugin) when loaded, so never load or swap one blindly.
set -euo pipefail

SO="$HOME/.local/share/hyprglass/hyprglass.so"
SRC="$HOME/.local/src/hyprglass"
REPO=https://github.com/hyprnux/hyprglass

case "${1:-}" in
load)
	# Already loaded (script run by hand): a second load would go through the crash-prone path.
	hyprctl plugin list | grep -q '^Plugin hyprglass' && exit 0
	commit=$(hyprctl version -j | jq -r .commit)
	# The plugin embeds the commit hash of the Hyprland headers it was built against.
	if [ -f "$SO" ] && grep -qaF "$commit" "$SO"; then
		# Reload so hyprland.lua's hl.plugin.hyprglass block sees the plugin.
		hyprctl plugin load "$SO" && hyprctl reload
	else
		notify-send -u critical "hyprglass not loaded" \
			"Built for another Hyprland version. Run: ~/.dotfiles/scripts/hyprglass.sh build, then log out and back in."
	fi
	;;
build)
	if [ -d "$SRC/.git" ]; then
		git -C "$SRC" pull --ff-only -q
	else
		git clone -q --depth 1 "$REPO" "$SRC"
	fi
	make -C "$SRC" clean >/dev/null 2>&1 || true
	make -C "$SRC" -j"$(nproc)"
	mkdir -p "$(dirname "$SO")"
	# mv, not cp over it: the running Hyprland keeps its mapping of the old file.
	[ -f "$SO" ] && mv "$SO" "$SO.prev.bak"
	cp "$SRC/hyprglass.so" "$SO"
	# Never hot-swap: unloading the old plugin in a live session is the crash path.
	echo "Installed $SO ($(git -C "$SRC" log -1 --format=%h)). Log out and back in to load it."
	;;
*)
	echo "usage: $0 load|build" >&2
	exit 2
	;;
esac
