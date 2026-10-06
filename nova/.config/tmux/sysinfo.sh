#!/bin/sh
# Status-bar system info: CPU use and fastest core clock, RAM, battery.
# Run by tmux #() every status-interval; CPU use is the delta since the last run.
# Output: CPU 12% @ 4.3 GHz │ RAM 10.2 of 15 GB │ Battery 80% (charging)
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
	END {printf "%.1f of %.0f GB", (t - a) / 1048576, t / 1048576}' /proc/meminfo)

bat=''
for b in /sys/class/power_supply/BAT*; do
	[ -f "$b/status" ] || continue
	st=$(cat "$b/status")
	case $st in
	Charging) note=' (charging)' ;;
	Full) note=' (full)' ;;
	"Not charging") note=' (plugged in)' ;;
	*) note='' ;;
	esac
	if [ -f "$b/capacity" ]; then
		bat=" │ Battery $(cat "$b/capacity")%$note"
	else
		# Some firmware (novahome) reports no charge level, only the status.
		bat=" │ Battery $(printf '%s' "$st" | tr 'A-Z' 'a-z')"
	fi
	break
done

printf 'CPU %s%% @ %s GHz │ RAM %s%s' "$cpu" "$ghz" "$ram" "$bat"
