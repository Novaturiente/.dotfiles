#!/bin/sh
# Status-bar system info: CPU use and fastest core clock, RAM, battery.
# Run by tmux #() every status-interval; CPU use is the delta since the last run.
# Output (Nerd Font icons): 󰻠 12% 4.3GHz  󰍛 10.2/15G  󰂁 80%
# Battery icon follows the level; 󰂄 = charging, 󰚥 = plugged in, not charging.
# Each icon is coloured by its level, muted green (fine) to yellow to muted red (busy/low),
# the Catppuccin gradient of the agents sidebar's usage bars; the text stays tmux.conf's grey.
cache=${XDG_RUNTIME_DIR:-/tmp}/tmux-sysinfo-cpu

# col <0-100>: tmux style for that level, 0 green, 50 yellow, 100 red. Ends in the text grey
# (Catppuccin subtext0, as status-right sets it), so only the icon after it is coloured.
col() {
	q=$1
	[ "$q" -lt 0 ] && q=0
	[ "$q" -gt 100 ] && q=100
	if [ "$q" -le 50 ]; then
		r=$((166 + 83 * q / 50)) g=$((227 - q / 50)) b=$((161 + 14 * q / 50))
	else
		r=$((249 - 6 * (q - 50) / 50)) g=$((226 - 87 * (q - 50) / 50)) b=$((175 - 7 * (q - 50) / 50))
	fi
	printf '#[fg=#%02x%02x%02x]' "$r" "$g" "$b"
}
grey='#[fg=#bac2de]'

# /proc/stat cpu line: user nice system idle iowait irq softirq steal ...
read -r _ u n s i w q sq st _ </proc/stat
busy=$((u + n + s + q + sq + st)) total=$((busy + i + w))
cpu=0
if [ -f "$cache" ]; then
	read -r pb pt <"$cache"
	dt=$((total - pt))
	[ "$dt" -gt 0 ] && cpu=$(((busy - pb) * 100 / dt))
fi
echo "$busy $total" >"$cache"

ghz=$(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null |
	sort -n | tail -1 | awk '{printf "%.1f", $1 / 1000000}')

# Text, then % in use for the colour.
read -r ram rp <<EOF
$(awk '/^MemTotal/ {t = $2} /^MemAvailable/ {a = $2}
	END {printf "%.1f/%.0fG %d", (t - a) / 1048576, t / 1048576, (t - a) * 100 / t}' /proc/meminfo)
EOF

bat=''
for b in /sys/class/power_supply/BAT*; do
	[ -f "$b/status" ] || continue
	st=$(cat "$b/status")
	if [ -f "$b/capacity" ]; then
		cap=$(cat "$b/capacity")
		# 0-9% outline, then one icon per 10%, full at 100%.
		set -- 󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹
		shift $((cap / 10))
		icon=$1
		case $st in
		Charging) icon=󰂄 ;;
		"Not charging") icon=󰚥 ;;
		esac
		# Full = green, empty = red.
		bat="  $(col $((100 - cap)))$icon$grey $cap%"
	else
		# Some firmware (novahome) reports no charge level, only the status.
		bat="  󰁹 $(printf '%s' "$st" | tr 'A-Z' 'a-z')"
	fi
	break
done

printf '%s󰻠%s %s%% %sGHz  %s󰍛%s %s%s' "$(col "$cpu")" "$grey" "$cpu" "$ghz" "$(col "$rp")" "$grey" "$ram" "$bat"
