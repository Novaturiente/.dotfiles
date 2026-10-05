#!/bin/sh
# Run by `wl-paste --watch` (clip-push.service) on every clipboard change.
# Image copied -> push it to novahome, where a stand-in wl-paste serves it to
# agents' Ctrl+V. Anything else -> drop the remote copy so a stale image never
# pastes. Text is never read or sent (passwords from rbw stay local).
host=novahome
mark=${XDG_RUNTIME_DIR:-/tmp}/clip-push.pushed
ssh="ssh -o BatchMode=yes -o ConnectTimeout=5 $host"

type=$(wl-paste -l 2>/dev/null | grep -m1 -E '^image/(png|jpeg|gif|webp|bmp)$')
if [ -z "$type" ]; then
	# A copied image file (file manager) counts too.
	file=$(wl-paste -l 2>/dev/null | grep -qx text/uri-list &&
		wl-paste -t text/uri-list 2>/dev/null | sed -n 's#^file://##p' | head -1)
	case $file in *.png | *.jpg | *.jpeg | *.gif | *.webp | *.bmp)
		type=$(file -b --mime-type "$file") ;;
	*) file= ;;
	esac
fi

if [ -n "$type" ]; then
	{ if [ -n "$file" ]; then cat "$file"; else wl-paste -t "$type"; fi; } |
		$ssh "mkdir -p ~/.cache/clip && cat > ~/.cache/clip/image && echo $type > ~/.cache/clip/type" &&
		touch "$mark"
elif [ -e "$mark" ]; then
	$ssh 'rm -f ~/.cache/clip/image ~/.cache/clip/type' && rm -f "$mark"
fi
