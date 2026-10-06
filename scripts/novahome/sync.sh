#!/bin/sh
# Copy the tmux setup from this laptop to novahome (no git there).
# Rerun after changing any of these files. Safe to run repeatedly.
set -e
h=novahome
cd "$(dirname "$0")/../.."

rsync -a nova/.tmux.conf "$h:"
rsync -a --delete nova/.config/tmux/ "$h:.config/tmux/"
rsync -a nova/.config/fish/functions/tmux.fish "$h:.config/fish/functions/"
rsync -a nova/.pi/agent/extensions/tmux-agent-state.ts "$h:.pi/agent/extensions/"
rsync -a scripts/novahome/wl-paste "$h:.local/bin/"
rsync -a ~/.gemini/config/hooks.json "$h:.gemini/config/"

# Claude hooks: swap novahome's agent-state entries for this laptop's, keep the rest.
jq '[.hooks | to_entries[] | {key, value: [.value[] | select(tostring | test("tmux/agent-state"))]}
	| select(.value | length > 0)] | from_entries' ~/.claude/settings.json |
	ssh "$h" 'cat > /tmp/claude-agent-hooks.json'
ssh "$h" bash -s <<'EOF'
cd ~/.claude && cp settings.json settings.json.bak
jq --slurpfile n /tmp/claude-agent-hooks.json '
	.hooks = (reduce ($n[0] | to_entries[]) as $e
		((.hooks // {}) | with_entries(.value |= map(select(tostring | test("tmux/agent-state") | not)));
		.[$e.key] += $e.value) | with_entries(select(.value | length > 0)))
' settings.json.bak > settings.json
rm /tmp/claude-agent-hooks.json
EOF
echo "synced to $h"
