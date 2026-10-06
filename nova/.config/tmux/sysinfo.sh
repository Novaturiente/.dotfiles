#!/bin/sh
# Status-bar system info: CPU use, highest current core clock, RAM, battery.
# Run by tmux #() every status-interval; CPU use is the delta since the last run.
cache=${XDG_RUNTIME_DIR:-/tmp}/tmux-sysinfo-cpu

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

ram=$(awk '/^MemTotal/ {t = $2} /^MemAvailable/ {a = $2}
	END {printf "%.1f/%.0fG", (t - a) / 1048576, t / 1048576}' /proc/meminfo)

bat=''
for b in /sys/class/power_supply/BAT*; do
	[ -f "$b/capacity" ] || continue
	c=$(cat "$b/capacity")
	case $(cat "$b/status") in Charging | Full) c="$c%+" ;; *) c="$c%" ;; esac
	bat="  BAT $c"
	break
done

printf 'CPU %s%% %sGHz  RAM %s%s' "$cpu" "$ghz" "$ram" "$bat"
