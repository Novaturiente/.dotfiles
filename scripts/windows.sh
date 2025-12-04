#!/usr/bin/env bash

# WinApps Podman toggle script with Rofi menu (running only)
COMPOSE_FILE="$HOME/.config/winapps/compose.yaml"
FREERDP_CMD="sdl-freerdp3 /cert:tofu /sec:tls /u:nova /p:novarch /scale:100 +f +home-drive /v:127.0.0.1"

# Check if container is running
if podman-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
	echo "🛑 WinApps running - showing rofi options..."
	ACTION=$(echo -e "🔗 Connect RDP\n🛑 Stop Container" | rofi -dmenu \
		-p "WinApps Running" \
		-mesg "Choose action:" \
		-theme "$HOME/.config/rofi/power.rasi" \
		-width 30 \
		-lines 2 || {
		echo "User cancelled"
		exit 0
	})

	case "$ACTION" in
	"🔗 Connect RDP")
		notify-send "WinApps" "Connecting to RDP..." || true
		$FREERDP_CMD
		;;
	"🛑 Stop Container")
		notify-send "WinApps" "Stopping WinApps container..." || true
		podman-compose -f "$COMPOSE_FILE" stop
		notify-send "WinApps" "Stopped" || true
		echo "✅ WinApps stopped"
		;;
	esac

else
	echo "🚀 WinApps stopped - starting directly..."
	notify-send "WinApps" "Starting WinApps container..." || true
	podman-compose -f "$COMPOSE_FILE" start
	sleep 5 # Wait for RDP to be ready
	notify-send "WinApps" "Connecting to RDP..." || true
	$FREERDP_CMD
fi
