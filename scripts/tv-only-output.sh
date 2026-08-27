#!/usr/bin/env bash
# novahome: if an external display (the TV) is connected when niri starts,
# run on it alone and switch the laptop panel off.
#
# ponytail: startup-only, no hotplug watching. If the TV is plugged in after
# niri is already up, just run this script again. Recovery if the TV goes away
# while the panel is off: `niri msg output eDP-1 on` (the change is temporary,
# so restarting niri also undoes it).
set -euo pipefail

INTERNAL=eDP-1

# niri exports NIRI_SOCKET to what it spawns, but the socket may not be
# accepting connections yet on the first try.
for _ in $(seq 20); do
	niri msg --json outputs >/dev/null 2>&1 && break
	sleep 0.25
done

external=$(niri msg --json outputs | jq -r --arg internal "$INTERNAL" 'keys[] | select(. != $internal)')

if [ -n "$external" ]; then
	echo "external display(s) present: $(echo "$external" | tr '\n' ' ')- turning $INTERNAL off"
	niri msg output "$INTERNAL" off
else
	echo "no external display, keeping $INTERNAL on"
fi
