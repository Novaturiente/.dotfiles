#!/bin/bash
# agent-sidebar.sh toggle  -> prefix+A: open/close the sidebar in this window.
# agent-sidebar.sh         -> draw loop, runs inside the sidebar pane.
# agent-sidebar.sh resize -> window-resized hook: keep the sidebar at WIDTH.
# agent-sidebar.sh next|prev <pane> -> prefix+j/k: jump to the next/previous agent.
# Keys in the sidebar: 1-9 jump to that agent, q closes.
WIDTH=12%

# Agent panes, in sidebar order: id, name, state, session:window, folder.
# ponytail: pane whose foreground is a shell = agent exited without reporting off; hidden, not cleared
agents() {
	tmux list-panes -a -F '#{pane_id}	#{@agent}	#{@agent_state}	#{session_name}:#{window_index}	#{b:pane_current_path}	#{pane_current_command}' |
		awk -F'\t' -v OFS='\t' '
			# Known agent not yet reported via hook (e.g. agy before its first prompt): show as idle.
			$2 == "" && $6 ~ /^(agy|claude|pi|codex)$/ { $2 = $6; $3 = "idle" }
			# Empty field would collapse under IFS=tab in read and shift the columns.
			$3 == "" { $3 = "idle" }
			$2 != "" && $6 !~ /^(zsh|bash|fish|sh)$/'
}

# Claude subscription windows from pi's claude-usage.ts caches (pi and Claude Code
# share one subscription). Newer of endpoint cache / per-response live file wins,
# same as withLive(). Rows: name, percent, reset epoch (0 = unknown), data epoch.
usage() {
	cat ~/.cache/claude-usage.json ~/.cache/claude-usage-live.json 2>/dev/null | jq -rs '
		(map(select(.data))[0] // {}) as $c | (map(select(.windows))[0] // {}) as $l |
		["five_hour","5h"], ["seven_day","wk"] | . as [$k,$n] |
		if ($l.at // 0) > ($c.at // 0) and ($l.windows[$k].utilization | type) == "number" then
			[$n, $l.windows[$k].utilization * 100,
			 ($l.windows[$k].resetsAt // 0 | if . < 1e11 then . else . / 1000 end), $l.at]
		else
			[$n, $c.data[$k].utilization,
			 ($c.data[$k].resets_at | if . == null then 0 else sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601 end), $c.at]
		end | select(.[1] != null) |
		"\(.[0])\t\(.[1] | round)\t\(.[2] | floor)\t\(.[3] / 1000 | floor)"' 2>/dev/null
}

goto() { tmux select-window -t "$1" \; select-pane -t "$1" \; switch-client -t "$1"; }

if [ "$1" = next ] || [ "$1" = prev ]; then
	mapfile -t ids < <(agents | cut -f1)
	n=${#ids[@]}
	[ "$n" -eq 0 ] && { tmux display 'no agents'; exit; }
	i=-1
	for j in "${!ids[@]}"; do [ "${ids[j]}" = "$2" ] && i=$j; done
	if [ "$1" = next ]; then
		i=$(((i + 1) % n))
	else
		[ "$i" -lt 0 ] && i=0
		i=$(((i - 1 + n) % n))
	fi
	goto "${ids[i]}"
	exit
fi
# reap <window>: pane-exited/after-kill-pane hook. Only sidebars left -> close the
# window, so a session dies with its last real pane.
if [ "$1" = reap ]; then
	tmux list-panes -t "$2" -F '#{@sidebar}' 2>/dev/null | grep -qvx 1 || tmux kill-window -t "$2" 2>/dev/null
	exit 0
fi
# open <window>: hooks. Like toggle but never closes, and skipped mid-restore.
if [ "$1" = toggle ] || [ "$1" = resize ] || [ "$1" = open ]; then
	sb=$(tmux list-panes -t "$2" -F '#{pane_id} #{@sidebar}' | awk '$2 == 1 {print $1}')
	if [ "$1" = resize ]; then
		[ -n "$sb" ] && tmux resize-pane -t "$sb" -x "$WIDTH"
	elif [ -n "$sb" ]; then
		if [ "$1" = toggle ]; then tmux kill-pane -t "$sb"; fi
	elif [ "$1" = toggle ] || [ -z "$(tmux show -gqv @restoring)" ]; then
		# Mark at once so a second open racing this one sees it.
		new=$(tmux split-window -t "$2" -hbfdP -F '#{pane_id}' -l "$WIDTH" "$0") &&
			tmux set -p -t "$new" @sidebar 1
	fi
	exit 0
fi

tmux set -p -t "$TMUX_PANE" @sidebar 1 \; select-pane -t "$TMUX_PANE" -T agents
# Hide cursor, no line wrap (long rows clip instead of breaking the layout);
# SGR mouse reporting so clicks reach the draw loop.
printf '\e[?25l\e[?7l\e[?1000h\e[?1006h'
trap 'printf "\e[?25h\e[?7h\e[?1000l\e[?1006l"' EXIT

# Catppuccin Mocha: yellow, red, green, overlay0
declare -A col=([working]='249;226;175' [blocked]='243;139;168' [done]='166;227;161' [idle]='108;112;134')
dim=$'\e[38;2;108;112;134m' off=$'\e[0m'
next_usage=0

while :; do
	# ponytail: re-reads the cache every 30s; only pi refreshes it, so the age shows staleness
	if ((SECONDS >= next_usage)); then mapfile -t uw < <(usage); next_usage=$((SECONDS + 30)); fi
	foot=()
	if [ ${#uw[@]} -gt 0 ]; then
		at=0
		for u in "${uw[@]}"; do IFS=$'\t' read -r _ _ _ a <<<"$u"; ((a > at)) && at=$a; done
		foot=("$(printf ' %sUSAGE · %dm ago%s' "$dim" $(((EPOCHSECONDS - at) / 60)) "$off")")
		for u in "${uw[@]}"; do
			IFS=$'\t' read -r n p r _ <<<"$u"
			c=${col[done]}
			((p >= 70)) && c=${col[working]}
			((p >= 90)) && c=${col[blocked]}
			f=$(((p * 5 + 50) / 100)); ((f > 5)) && f=5
			bar=$(printf '%*s' "$f" '' | sed 's/ /█/g')$(printf '%*s' $((5 - f)) '' | sed 's/ /░/g')
			t=''
			if ((r > 0)); then
				if [ "$n" = 5h ]; then t=$(date -d "@$r" +%H:%M); else t=$(date -d "@$r" '+%a %H:%M'); fi
			fi
			foot+=("$(printf ' %s%s%s \e[38;2;%sm%s%s%4d%% %s%s%s' "$dim" "$n" "$off" "$c" "$bar" "$off" "$p" "$dim" "$t" "$off")")
		done
	fi
	# Last pane left in the window: close instead of lingering alone.
	[ "$(tmux display -p -t "$TMUX_PANE" '#{window_panes}')" -gt 1 ] || exit
	read -r h me < <(tmux display -p -t "$TMUX_PANE" '#{pane_height} #{session_name}')
	# Selected agent = active pane of this session's active window.
	sel=$(tmux display -p -t "$me:" '#{pane_id}')
	# Tree: each session, its agents under it. rows = click target per screen line
	# (p:<pane> or s:<session>), parallel to lines. Agent numbers (1-9 keys) run
	# across sessions in the same order as prefix+j/k.
	mapfile -t all < <(agents)
	# Folder of each session's first non-sidebar pane, shown when it has no agents.
	declare -A first=()
	while IFS=$'\t' read -r s sbp d; do
		[ "$sbp" = s ] || [ -n "${first[$s]+x}" ] || first[$s]=$d
	done < <(tmux list-panes -a -F '#{session_name}	#{?#{@sidebar},s,p}	#{b:pane_current_path}')
	ids=() lines=("" "${dim} SESSIONS${off}" "") rows=("" "" "")
	while IFS=$'\t' read -r name wins att; do
		# Green dot = attached, mauve name = this session.
		d=${col[idle]} nc=''
		[ "$att" -gt 0 ] && d=${col[done]}
		[ "$name" = "$me" ] && nc=$'\e[1;38;2;203;166;247m'
		lines+=("$(printf ' \e[38;2;%sm●%s %s%-18.18s%s %s%sw%s' "$d" "$off" "$nc" "$name" "$off" "$dim" "$wins" "$off")")
		rows+=("s:$name")
		mine=()
		for a in "${all[@]}"; do
			IFS=$'\t' read -r _ _ _ loc _ <<<"$a"
			[ "${loc%:*}" = "$name" ] && mine+=("$a")
		done
		if [ ${#mine[@]} -eq 0 ]; then
			lines+=("$(printf '   %s%.24s%s' "$dim" "${first[$name]}" "$off")") rows+=("s:$name")
		fi
		for k in "${!mine[@]}"; do
			IFS=$'\t' read -r id agent state loc dir _ <<<"${mine[k]}"
			ids+=("$id") rows+=("p:$id" "p:$id")
			c=${col[$state]:-${col[idle]}}
			br='├' cont='│'
			[ "$k" -eq $((${#mine[@]} - 1)) ] && br='└' cont=' '
			# Selected: mauve bar in the gutter + bold name.
			g=' ' b=''
			[ "$id" = "$sel" ] && g=$'\e[38;2;203;166;247m▎\e[0m' b=$'\e[1m'
			lines+=("$(printf '%s%s%s%s %d \e[38;2;%sm●%s %s%-8.8s%s \e[38;2;%sm%-7s%s' "$g" "$dim" "$br" "$off" "${#ids[@]}" "$c" "$off" "$b" "$agent" "$off" "$c" "$state" "$off")")
			lines+=("$(printf '%s%s%s    w%s %.22s%s' "$g" "$dim" "$cont" "${loc##*:}" "$dir" "$off")")
		done
		lines+=("") rows+=("")
	done < <(tmux list-sessions -F '#{session_name}	#{session_windows}	#{session_attached}')

	# ponytail: clipped at pane height, no scrolling; add it if sessions+agents outgrow the pane
	# Usage pinned to the bottom: list gets the rest, padded so the footer sits on the last rows.
	bh=$((h - ${#foot[@]}))
	lines=("${lines[@]:0:bh}") rows=("${rows[@]:0:bh}")
	while [ ${#foot[@]} -gt 0 ] && [ ${#lines[@]} -lt "$bh" ]; do lines+=(""); done
	lines+=("${foot[@]}")
	# $(...) drops the final newline, so a full-height list never scrolls.
	printf '\e[H%s\e[J' "$(printf '%s\e[K\n' "${lines[@]}")"

	read -rsn1 -t1 k
	case $k in
	q) exit ;;
	$'\e')
		# Mouse: ESC [ < button ; col ; row M  (M = press). Left click only.
		seq=''
		while read -rsn1 -t0.05 c; do
			seq+=$c
			[[ $c == [Mm] ]] && break
		done
		[[ $seq =~ ^\[\<0\;[0-9]+\;([0-9]+)M$ ]] || continue
		t=${rows[BASH_REMATCH[1] - 1]}
		[ -n "$t" ] || continue
		# The click focused the sidebar; hand focus back before jumping.
		tmux last-pane -t "$TMUX_PANE" 2>/dev/null
		case $t in
		p:*) goto "${t#p:}" ;;
		s:*) tmux switch-client -t "=${t#s:}" ;;
		esac
		;;
	[1-9])
		id=${ids[k - 1]}
		[ -n "$id" ] && goto "$id"
		;;
	esac
done
