#!/bin/bash
# Fuzzy pickers, run in tmux popups (nova/.tmux.conf). prefix+s is agent-sidebar.sh popup.
#   pick.sh project -> prefix+N: pick a folder, open a new session there.
#                      List: current project first (the default), then ~/Projects/*, ~/.dotfiles, zoxide.
#   pick.sh resume  -> prefix+S: past sessions of the agent in the pane under the popup, for its
#                      folder. novacode: own list (newest first, date + session name, preview = the
#                      session's prompts); Enter jumps to the pane if it is open, else resumes it in a
#                      new window. Claude Code and codex: their own resume pickers in a new window.

# in_window <dir> <command>: new window in this session, command typed into its shell
# (exiting the agent leaves the shell, like state.sh restores).
in_window() {
	local p
	p=$(tmux new-window -P -F '#{pane_id}' -c "$1") && tmux send-keys -t "$p" -l "$2" \; send-keys -t "$p" Enter
}

case $1 in
project)
	cur=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
	d=$({
		echo "$cur"
		for p in ~/Projects/*/ ~/.dotfiles; do echo "${p%/}"; done
		zoxide query -l 2>/dev/null
	} | awk '!s[$0]++' |
		fzf --tiebreak=index --prompt 'project > ' --preview 'eza -1 --icons=always --color=always {}')
	[ -n "$d" ] || exit 0
	id=$(tmux new-session -dP -F '#{session_id}' -c "$d") && tmux switch-client -t "$id"
	;;
resume)
	# Inside a popup, display names the pane under it. Agent folder, else the pane's (-d of the popup).
	IFS=$'\t' read -r ag acwd < <(tmux display -p '#{@agent}	#{@agent_cwd}')
	d=${acwd:-$PWD}
	case $ag in
	claude) in_window "$d" 'claude --resume'; exit ;;
	codex) in_window "$d" 'codex resume'; exit ;;
	esac
	# novacode keeps one folder per project: the path with / turned into -.
	dir=~/.novacode/sessions/${d//\//-}
	mapfile -t fs < <(ls -t "$dir"/*.jsonl 2>/dev/null)
	if [ ${#fs[@]} -eq 0 ]; then
		printf 'No novacode sessions for %s\n' "$d"
		read -rsn1
		exit 0
	fi
	# Rows: file (hidden), date, name (last session_info, else the first prompt).
	sel=$(for f in "${fs[@]}"; do
		n=$(grep -h '"type":"session_info"' "$f" | tail -1 | jq -r .name)
		[ -n "$n" ] || n=$(grep -m1 '"role":"user"' "$f" | jq -r '[.message.content[]? | select(.type == "text") | .text][0] // ""' | head -1 | cut -c1-80)
		printf '%s\t\e[38;2;108;112;134m%s\e[0m  %s\n' "$f" "$(date -d "@$(stat -c %Y "$f")" '+%b %d %H:%M')" "${n:-(empty)}"
	done | fzf --ansi --delimiter '\t' --with-nth 2 --tiebreak=index \
		--layout reverse --border rounded --border-label " 󰚩 resume · ${d/#$HOME/\~} " --color 'border:#6c7086' \
		--prompt '  ' --pointer '▎' --padding 1,2 \
		--preview 'jq -r "select(.message.role == \"user\") | .message.content[]? | select(.type == \"text\") | \"› \" + .text + \"\n\"" {1} | tail -80' \
		--preview-window 'right,55%,border-left,wrap')
	f=${sel%%$'\t'*}
	[ -n "$f" ] || exit 0
	# Already open (novacode stores its session file as @agent_session): go there instead.
	p=$(tmux list-panes -a -F '#{pane_id}	#{@agent_session}' | awk -F'\t' -v f="$f" '$2 == f {print $1; exit}')
	if [ -n "$p" ]; then
		tmux select-window -t "$p" \; select-pane -t "$p" \; switch-client -t "$p"
	else
		in_window "$d" "novacode -r $(basename "$f" .jsonl)"
	fi
	;;
esac
