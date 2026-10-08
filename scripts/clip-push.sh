#!/bin/sh
# Run by `wl-paste --watch` (clip-push.service) on every clipboard change.
# Image copied -> push it to novahome, where a stand-in wl-paste serves it to
# agents' Ctrl+V. Anything else -> drop the remote copy so a stale image never
# pastes. Text is never read or sent (passwords from rbw stay local).
# wl-paste --watch feeds the new clipboard on stdin; it is unused here. Left
# open, a large image fills the pipe, wl-copy's writer blocks, and our own
# wl-paste below waits on that same wl-copy forever, freezing cliphist too.
exec </dev/null
host=novahome
mark=${XDG_RUNTIME_DIR:-/tmp}/clip-push.pushed
ssh="ssh -o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 $host"

type=$(wl-paste -l 2>/dev/null | grep -m1 -E '^image/(png|jpeg|gif|webp|bmp)$')
if [ -z "$type" ]; then
	# A copied image file (file manager) counts too.
	file=$(wl-paste -l 2>/dev/null | grep -qx text/uri-list &&
		wl-paste -t text/uri-list 2>/dev/null | tr -d '\r' | sed -n 's#^file://##p' | head -1)
	case $file in *.png | *.jpg | *.jpeg | *.gif | *.webp | *.bmp)
		type=$(file -b --mime-type "$file") ;;
	*) file= ;;
	esac
fi

if [ -n "$type" ]; then
	{ if [ -n "$file" ]; then cat "$file"; else wl-paste -t "$type"; fi; } |
		$ssh "mkdir -p ~/.cache/clip && cat > ~/.cache/clip/image && echo $type > ~/.cache/clip/type" &&
		touch "$mark"
	# Clipboard history (cliphist) and file managers also offer the laptop path as text,
	# which the terminal pastes. Mirror that file to the same path on novahome so
	# the pasted path resolves there. Only read when an image is on the clipboard,
	# so copied passwords are never read.
	{ wl-paste -t text/plain; wl-paste -t text/uri-list | sed -n 's#^file://##p'; } 2>/dev/null |
		tr -d '\r' | sort -u | while read -r p; do
			case $p in "$HOME"/*.png | "$HOME"/*.jpg | "$HOME"/*.jpeg | "$HOME"/*.gif | "$HOME"/*.webp | "$HOME"/*.bmp)
				[ -f "$p" ] && $ssh "mkdir -p '$(dirname "$p")' && cat > '$p'" < "$p" ;;
			esac
		done
elif [ -e "$mark" ]; then
	$ssh 'rm -f ~/.cache/clip/image ~/.cache/clip/type' && rm -f "$mark"
fi
