#!/bin/bash
# agent-sidebar.sh toggle  -> prefix+A: open/close the sidebar in this window.
# agent-sidebar.sh         -> draw loop, runs inside the sidebar pane.
# agent-sidebar.sh resize -> window-resized hook: keep the sidebar at WIDTH.
# agent-sidebar.sh next|prev <pane> -> prefix+j/k: jump to the next/previous agent.
# Keys in the sidebar: 1-9 jump to that agent, q closes.
WIDTH=15%

# Agent panes, in sidebar order: id, name, state, session:window, folder, command, bg count.
# ponytail: pane whose foreground is a shell = agent exited without reporting off; hidden, not cleared
agents() {
	tmux list-panes -a -F '#{pane_id}	#{@agent}	#{@agent_state}	#{session_name}:#{window_index}	#{b:pane_current_path}	#{pane_current_command}	#{@agent_bg}' |
		awk -F'\t' -v OFS='\t' '
			# Known agent not yet reported via hook (e.g. agy before its first prompt): show as idle.
			$2 == "" && $6 ~ /^(agy|claude|pi|codex)$/ { $2 = $6; $3 = "idle" }
			# Empty field would collapse under IFS=tab in read and shift the columns.
			$3 == "" { $3 = "idle" }
			# swarm-* = hidden pi-swarm subagent sessions, shown in the swarm panel instead.
			$2 != "" && $6 !~ /^(zsh|bash|fish|sh)$/ && $4 !~ /^swarm-/'
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

# Antigravity quota from pi's cache, same rows. Group picked by model id like
# antigravityWindows(): Claude/GPT models -> "Claude and GPT", else Gemini.
usage_agy() {
	jq -r --arg m "$1" '
		.at as $at |
		(if ($m | test("claude|gpt|sonnet|opus"; "i")) then "claude|gpt" else "gemini" end) as $re |
		(.data.groups // []) as $g |
		(first($g[] | select(.displayName | test($re; "i"))) // $g[0] // {}) as $grp |
		["5h","5h"], ["weekly","wk"] | . as [$w,$n] |
		first($grp.buckets[]? | select(.window == $w or (.bucketId | test($w)))) // empty |
		select(.remainingFraction != null) |
		"\($n)\t\((1 - .remainingFraction) * 100 | round)\t\(.resetTime | if . == null then 0 else sub("\\.[0-9]+"; "") | fromdateiso8601 end)\t\($at / 1000 | floor)"' \
		~/.cache/antigravity-usage.json 2>/dev/null
}

# Folder -> git repo name (main checkout, so worktrees map back; empty = not a repo).
# ponytail: cached for the sidebar's life; a folder that becomes a repo later shows after a reopen
declare -A rc=()
repo() {
	[ -n "${rc[$1]+x}" ] || rc[$1]=$(r=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && basename "$(dirname "$r")")
	rp=${rc[$1]}
}

# Fills first[session] (folder of its first non-sidebar pane, shown when it has no
# agents), aproj/sproj[session] (project of its first agent / first shell pane).
# Agent project: @agent_project (set by agent-state.sh from edits and folder
# changes), else the repo of the agent's folder; agy/codex never report, so their
# pane folder. '|': empty fields.
projects() {
	declare -gA first=() aproj=() sproj=()
	local s sbp d cmd ag ap acwd full
	while IFS='|' read -r s sbp d cmd ag ap acwd full; do
		[ "$sbp" = s ] && continue
		[ -n "${first[$s]+x}" ] || first[$s]=$d
		rp=$ap
		[ -n "$rp" ] || repo "${acwd:-$full}"
		if [ -n "$ag" ] || [[ $cmd =~ ^(agy|claude|pi|codex)$ ]]; then
			[ -n "${aproj[$s]}" ] || aproj[$s]=$rp
		else
			[ -n "${sproj[$s]}" ] || sproj[$s]=$rp
		fi
	done < <(tmux list-panes -a -F '#{session_name}|#{?#{@sidebar},s,p}|#{b:pane_current_path}|#{pane_current_command}|#{@agent}|#{@agent_project}|#{@agent_cwd}|#{pane_current_path}')
}

# Sessions (name, windows, project) grouped by project: groups in order of their
# first session, sessions keep their order inside a group, no project last.
# Needs projects() first.
sessions() {
	local -A gi=()
	local n=0 i=0 g name wins pj
	while IFS=$'\t' read -r name wins; do
		[[ $name == swarm-* || $name == pi-panels ]] && continue
		pj=${aproj[$name]:-${sproj[$name]}} g=99999
		if [ -n "$pj" ]; then
			[ -n "${gi[$pj]+x}" ] || gi[$pj]=$((n++))
			g=${gi[$pj]}
		fi
		printf '%d\t%d\t%s\t%s\t%s\n' "$g" $((i++)) "$name" "$wins" "$pj"
	done < <(tmux list-sessions -F '#{session_name}	#{session_windows}') | sort -t$'\t' -n -k1,1 -k2,2 | cut -f3-
}

goto() { tmux select-window -t "$1" \; select-pane -t "$1" \; switch-client -t "$1"; }

if [ "$1" = next ] || [ "$1" = prev ]; then
	# Same order as the sidebar: agents session by session, sessions grouped.
	projects
	mapfile -t all < <(agents)
	ids=()
	while IFS=$'\t' read -r name _; do
		for a in "${all[@]}"; do
			IFS=$'\t' read -r id _ _ loc _ <<<"$a"
			[ "${loc%:*}" = "$name" ] && ids+=("$id")
		done
	done < <(sessions)
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
# reap <window>: pane-exited/after-kill-pane hook. Only sidebars/pi panel tabs left ->
# close the window, so a session dies with its last real pane.
if [ "$1" = reap ]; then
	tmux list-panes -t "$2" -F '#{@sidebar}#{?#{@slot},1,}' 2>/dev/null | grep -qvx 1 || tmux kill-window -t "$2" 2>/dev/null
	exit 0
fi
# poke: session-closed hook. SIGUSR1 to each sidebar's draw loop = redraw now,
# no 1s polling lag and no keys typed into any pane.
if [ "$1" = poke ]; then
	tmux list-panes -a -F '#{@sidebar} #{pane_pid}' | awk '$1 == 1 {print $2}' | xargs -r kill -USR1 2>/dev/null
	exit 0
fi
# open <window>: hooks. Like toggle but never closes, and skipped mid-restore.
# Only while some agent exists, and never in hidden sessions (pi swarm children, parked pi tabs).
if [ "$1" = open ]; then
	case $(tmux display -p -t "$2" '#{session_name}' 2>/dev/null) in swarm-* | pi-panels | '') exit 0 ;; esac
	[ -n "$(agents)" ] || exit 0
	[ -n "$(tmux show -wqv -t "$2" @sidebar_off)" ] && exit 0 # closed by hand in this window
fi
if [ "$1" = toggle ] || [ "$1" = resize ] || [ "$1" = open ]; then
	sb=$(tmux list-panes -t "$2" -F '#{pane_id} #{@sidebar}' | awk '$2 == 1 {print $1}')
	if [ "$1" = resize ]; then
		[ -n "$sb" ] && tmux resize-pane -t "$sb" -x "$WIDTH"
	elif [ -n "$sb" ]; then
		if [ "$1" = toggle ]; then tmux kill-pane -t "$sb" \; set -w -t "$2" @sidebar_off 1; fi
	elif [ "$1" = toggle ] || [ -z "$(tmux show -gqv @restoring)" ]; then
		# Mark at once so a second open racing this one sees it.
		new=$(tmux split-window -t "$2" -hbfdP -F '#{pane_id}' -l "$WIDTH" "$0") &&
			tmux set -p -t "$new" @sidebar 1 \; set -wu -t "$2" @sidebar_off
	fi
	exit 0
fi

tmux set -p -t "$TMUX_PANE" @sidebar 1 \; select-pane -t "$TMUX_PANE" -T agents
# Hide cursor, no line wrap (long rows clip instead of breaking the layout);
# SGR mouse reporting so clicks reach the draw loop.
printf '\e[?25l\e[?7l\e[?1000h\e[?1006h'
trap 'printf "\e[?25h\e[?7h\e[?1000l\e[?1006l"' EXIT
# poke: a trapped signal cuts the pending read short; the frame loop then refreshes.
wake=''
trap 'wake=1' USR1

# Catppuccin Mocha: yellow, red, green, overlay0
declare -A col=([working]='249;226;175' [blocked]='243;139;168' [done]='166;227;161' [idle]='108;112;134')
# Agent logo before its name (Nerd Font): Claude and OpenAI logos are real; no
# Antigravity or pi logo exists, so a Gemini-style sparkle and a pi sign.
declare -A logo=(
	[claude]=$'\e[38;2;217;119;87m\uec82' [codex]=$'\e[38;2;205;214;244m\uec81'
	[agy]=$'\e[38;2;137;180;250m\uec21' [pi]=$'\e[38;2;148;226;213m\U000f03ff'
)
dim=$'\e[38;2;108;112;134m' off=$'\e[0m'
next_usage=0 src=claude shown='' upane=''
# Animation: working = braille spinner, blocked = red icon fading in and out.
# Lines carry @W@/@B@ placeholders, swapped for the current frame at each redraw.
spin=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
pulse=('243;139;168' '206;118;143' '168;97;118' '131;76;93' '168;97;118' '206;118;143')
fr=0

mt=$(stat -Lc %Y "$0")
while :; do
	# Script edited: restart on the new code, so no sidebar keeps drawing the old way.
	[ "$(stat -Lc %Y "$0")" = "$mt" ] || exec "$0"
	# Last pane left in the window: close instead of lingering alone.
	[ "$(tmux display -p -t "$TMUX_PANE" '#{window_panes}')" -gt 1 ] || exit
	read -r h me < <(tmux display -p -t "$TMUX_PANE" '#{pane_height} #{session_name}')
	# Selected agent = active pane of this session's active window.
	sel=$(tmux display -p -t "$me:" '#{pane_id}')

	# Usage follows a claude/pi agent in this window: the focused pane if it is one,
	# else the one focused last (upane), else the first. So focusing the file tree
	# or this sidebar keeps the block. pi publishes @agent_model
	# (tmux-agent-state.ts). '|' not tab: empty fields collapse under tab IFS.
	pick='' fa=''
	while IFS='|' read -r pid a m act c; do
		[[ $a =~ ^(claude|pi)$ && ! $c =~ ^(zsh|bash|fish|sh)$ ]] || continue
		[ -n "$fa" ] || fa="$pid|$a|$m"
		[ "$act" = 1 ] && { pick="$pid|$a|$m"; break; }
		[ "$pid" = "$upane" ] && pick="$pid|$a|$m"
	done < <(tmux list-panes -t "$TMUX_PANE" -F '#{pane_id}|#{?#{@agent},#{@agent},#{pane_current_command}}|#{@agent_model}|#{pane_active}|#{pane_current_command}')
	IFS='|' read -r upane ag am <<<"${pick:-$fa}"
	case $ag in
	claude) src=claude ;;
	pi) [[ $am == antigravity/* ]] && src=$am || src=claude ;;
	*) src='' ;;
	esac
	# ponytail: re-reads the cache every 30s (or on provider change); only pi refreshes it, so the age shows staleness
	if [ "$src" != "$shown" ] || ((SECONDS >= next_usage)); then
		if [ -z "$src" ]; then
			uw=()
		elif [ "$src" = claude ]; then
			mapfile -t uw < <(usage)
			label=CLAUDE
		else
			m=${src#*/}
			mapfile -t uw < <(usage_agy "$m")
			label='AGY GEMINI'
			[[ ${m,,} =~ claude|gpt|sonnet|opus ]] && label='AGY CLAUDE'
		fi
		shown=$src next_usage=$((SECONDS + 30))
	fi
	foot=()
	if [ ${#uw[@]} -gt 0 ]; then
		at=0
		for u in "${uw[@]}"; do IFS=$'\t' read -r _ _ _ a <<<"$u"; ((a > at)) && at=$a; done
		age=$(((EPOCHSECONDS - at) / 60))m
		((${age%m} >= 60)) && age=$((${age%m} / 60))h
		foot=("$(printf ' %s%s · %s ago%s' "$dim" "$label" "$age" "$off")")
		for u in "${uw[@]}"; do
			IFS=$'\t' read -r n p r _ <<<"$u"
			# Smooth gradient: green (0%) -> yellow (50%) -> red (100%), Catppuccin Mocha.
			q=$((p < 0 ? 0 : p > 100 ? 100 : p))
			if ((q <= 50)); then
				c="$((166 + 83 * q / 50));$((227 - q / 50));$((161 + 14 * q / 50))"
			else
				c="$((249 - 6 * (q - 50) / 50));$((226 - 87 * (q - 50) / 50));$((175 - 7 * (q - 50) / 50))"
			fi
			# Window already reset since the cache was written: the percent is meaningless.
			((r > 0 && r <= EPOCHSECONDS)) && c=${col[idle]}
			f=$(((p * 5 + 50) / 100)); ((f > 5)) && f=5
			bar=$(printf '%*s' "$f" '' | sed 's/ /█/g')$(printf '%*s' $((5 - f)) '' | sed 's/ /░/g')
			t=''
			if ((r > 0 && r <= EPOCHSECONDS)); then
				t=stale
			elif ((r > 0)); then
				if [ "$n" = 5h ]; then t=$(date -d "@$r" +%H:%M); else t=$(date -d "@$r" '+%a %H:%M'); fi
			fi
			foot+=("$(printf ' %s%s%s \e[38;2;%sm%s%s%4d%% %s%s%s' "$dim" "$n" "$off" "$c" "$bar" "$off" "$p" "$dim" "$t" "$off")")
		done
	fi
	# Tree: each session, its agents under it; sessions grouped by project.
	# rows = click target per screen line (p:<pane> or s:<session>), parallel to
	# lines. Agent numbers (1-9 keys) run across sessions in the same order as prefix+j/k.
	mapfile -t all < <(agents)
	projects
	ids=() lines=("" "${dim} SESSIONS${off}" "") rows=("" "" "")
	while IFS=$'\t' read -r name wins pj; do
		# Mauve name = this session, plain otherwise.
		# Project after the name, both inside the same 20 columns: blue for this
		# session, Catppuccin text (white) for the others.
		nc='' pc='205;214;244'
		[ "$name" = "$me" ] && nc=$'\e[1;38;2;203;166;247m' pc='137;180;250'
		pw=$((19 - ${#name}))
		if [ -n "$pj" ] && ((pw > 0)); then
			lines+=("$(printf ' %s%s%s \e[38;2;%sm%-*.*s%s %s%sw%s' "$nc" "$name" "$off" "$pc" "$pw" "$pw" "$pj" "$off" "$dim" "$wins" "$off")")
		else
			lines+=("$(printf ' %s%-20.20s%s %s%sw%s' "$nc" "$name" "$off" "$dim" "$wins" "$off")")
		fi
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
			IFS=$'\t' read -r id agent state loc dir _ nbg <<<"${mine[k]}"
			ids+=("$id") rows+=("p:$id" "p:$id")
			c=${col[$state]:-${col[idle]}}
			case $state in
			working) ic=@W@ sw=working ;;
			blocked) ic=@B@ sw=waiting ;;
			# Finished, not yet looked at; pane-focus-in turns it back to idle.
			'done') ic=$'\e[38;2;'$c'm●' sw='' ;;
			*) ic=$'\e[38;2;'$c'm○' sw=$state ;;
			esac
			br='├' cont='│'
			[ "$k" -eq $((${#mine[@]} - 1)) ] && br='└' cont=' '
			# Selected: mauve bar in the gutter + bold name.
			g=' ' b=''
			[ "$id" = "$sel" ] && g=$'\e[38;2;203;166;247m▎\e[0m' b=$'\e[1m'
			# Name 2 columns narrower than before to make room for the logo.
			lines+=("$(printf '%s%s%s%s %s%s %s%s %s%-7.7s%s \e[38;2;%sm%s%s' "$g" "$dim" "$br" "$off" "$ic" "$off" "${logo[$agent]:- }" "$off" "$b" "$agent" "$off" "$c" "$sw" "$off")")
			# Background processes (@agent_bg): blue gear + count before the folder, apart from the state.
			bgm='' dw=20
			[ -n "$nbg" ] && bgm=$'\e[38;2;137;180;250m⚙'$nbg' ' dw=$((20 - ${#nbg} - 2))
			lines+=("$(printf '%s%s%s%s   %s\e[38;2;166;173;200m%.*s%s' "$g" "$dim" "$cont" "$off" "$bgm" "$dw" "$dir" "$off")")
		done
		lines+=("") rows+=("")
	done < <(sessions)

	# ponytail: clipped at pane height, no scrolling; add it if sessions+agents outgrow the pane
	# Usage pinned to the bottom: list gets the rest, padded so the footer sits on the last rows.
	# Last row stays blank so nothing touches the bottom edge.
	bh=$((h - ${#foot[@]} - 1))
	lines=("${lines[@]:0:bh}") rows=("${rows[@]:0:bh}")
	while [ ${#foot[@]} -gt 0 ] && [ ${#lines[@]} -lt "$bh" ]; do lines+=(""); done
	lines+=("${foot[@]}" "")
	# Data refreshes once a second; the frame redraws 4x a second for the animation.
	# A key, click or poke (also one that landed while gathering) breaks out at once.
	for _ in 1 2 3 4; do
		# $(...) drops the final newline, so a full-height list never scrolls.
		out=$(printf '%s\e[K\n' "${lines[@]}")
		out=${out//@W@/$'\e[38;2;'${col[working]}'m'${spin[fr % 10]}}
		out=${out//@B@/$'\e[38;2;'${pulse[fr % 6]}'m✱'}
		((fr++))
		printf '\e[H%s\e[J' "$out"
		# Posix mode only for this read: plain bash restarts a read after a trap, posix
		# mode returns from it, so a poke lands at once instead of at the 0.25s timeout.
		if [ -z "$wake" ]; then
			set -o posix
			read -rsn1 -t0.25 k
			rc=$?
			set +o posix
			((rc == 0)) && break
		fi
		[ -n "$wake" ] && { wake='' k=''; break; }
	done
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
