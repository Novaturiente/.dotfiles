#!/bin/sh
# Toggle auto-reload of the tmux config (bound to prefix+R).
# On: a background loop re-sources ~/.tmux.conf whenever it or the palette is saved.
pid=$(tmux show -gqv @autoreload)
if [ -n "$pid" ]; then
	kill "$pid" 2>/dev/null
	tmux set -gu @autoreload \; display "auto-reload off"
	exit
fi

# Watch the real repo files: editors save by replacing them, not the symlink.
conf=$(readlink -f ~/.tmux.conf)
files="$conf $(dirname "$conf")/.config/tmux/catppuccin_mocha.conf"

# ponytail: 1s mtime poll, no inotify-tools needed; switch to inotifywait if polling ever matters
(
	last=$(stat -L -c %Y $files)
	while sleep 1 && tmux has-session 2>/dev/null; do
		now=$(stat -L -c %Y $files 2>/dev/null) || continue
		[ "$now" = "$last" ] && continue
		last=$now
		tmux source-file ~/.tmux.conf \; display "config reloaded"
	done
) >/dev/null 2>&1 &
tmux set -g @autoreload $! \; display "auto-reload on"
