#!/usr/bin/env bash

# yazi (30%, full file tree + git status signs) on the left and
# claude --dangerously-skip-permissions (70%) on the right, inside a
# persistent tmux session named after the target dir (default: $PWD).
# Inside tmux -> switch-client; outside tmux -> start tmux and attach.
#
# Usage: yazi-claude.sh [dir]

set -u

DIR="${1:-$PWD}"
DIR="$(cd "$DIR" 2>/dev/null && pwd)" || { echo "yazi-claude: not a directory: ${1:-$PWD}" >&2; exit 1; }

# Safe tmux session name from the folder basename
SESSION_NAME="$(basename "$DIR")"
SESSION_NAME="${SESSION_NAME#.}"
SESSION_NAME="${SESSION_NAME//:/-}"
SESSION_NAME="${SESSION_NAME//./-}"
SESSION_NAME="${SESSION_NAME// /_}"

# Make sure the tmux server has ~/.local/bin etc. on PATH so claude resolves
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.npm-global/bin:$HOME/go/bin:$PATH"
tmux set-environment -g PATH "$PATH" 2>/dev/null || true

YAZI_BIN="$(command -v yazi || echo /usr/bin/yazi)"
CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"
CLAUDE_CMD="$CLAUDE_BIN --dangerously-skip-permissions"

# Dedicated yazi config home for the narrow 30% pane: single column
# (no parent, no preview) via ratio [0,1,0]. Real plugins / init.lua /
# keymap are symlinked in so git.yazi + gvfs + no-status still work;
# only yazi.toml is overridden.
REAL_YAZI_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/yazi"
YAZI_CFG_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/yazi-claude"
rm -rf "$YAZI_CFG_HOME"
mkdir -p "$YAZI_CFG_HOME"
for entry in "$REAL_YAZI_CFG"/* "$REAL_YAZI_CFG"/.*; do
	base="$(basename "$entry")"
	[[ "$base" == "." || "$base" == ".." || "$base" == "yazi.toml" ]] && continue
	[[ -e "$entry" ]] && ln -sfn "$entry" "$YAZI_CFG_HOME/$base"
done
cat > "$YAZI_CFG_HOME/yazi.toml" <<'EOF'
[mgr]
ratio = [0, 1, 0]

# git.yazi: status signs next to every file (clean + modified)
[[plugin.prepend_fetchers]]
url   = "*"
run   = "git"
group = "git"

[[plugin.prepend_fetchers]]
url   = "*/"
run   = "git"
group = "git"
EOF
YAZI_CMD="YAZI_CONFIG_HOME=$YAZI_CFG_HOME $YAZI_BIN"

needs_rebuild=1
if tmux has-session -t="$SESSION_NAME" 2>/dev/null; then
	pane_count=$(tmux list-panes -t "$SESSION_NAME" 2>/dev/null | wc -l)
	if [[ "$pane_count" -ge 2 ]]; then
		needs_rebuild=0
	else
		# Broken / single-pane leftover — wipe and rebuild
		tmux kill-session -t "$SESSION_NAME" 2>/dev/null
	fi
fi

if [[ "$needs_rebuild" -eq 1 ]]; then
	# Pane 0 (left, 30%): yazi (single-column config)
	tmux new-session -d -s "$SESSION_NAME" -x 200 -y 50 -c "$DIR" "$YAZI_CMD"
	# Pane 1 (right, 70%): claude
	tmux split-window -h -l 70% -t "$SESSION_NAME" -c "$DIR" "$CLAUDE_CMD"
	tmux select-pane -t "$SESSION_NAME" -R
fi

if [[ -n "${TMUX:-}" ]]; then
	# Already inside tmux: can't nest attach, switch the client instead
	exec tmux switch-client -t "$SESSION_NAME"
else
	exec tmux attach-session -t "$SESSION_NAME"
fi
