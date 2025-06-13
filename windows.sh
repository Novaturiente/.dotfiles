#!/bin/bash

# Set your container name here
CONTAINER_NAME="WinApps"

# Check for an argument
if [ "$1" == "start" ]; then
    # Check if the container is running
    if podman ps --filter "name=^/${CONTAINER_NAME}$" --filter "status=running" --format '{{.Names}}' | grep -wq "$CONTAINER_NAME"; then
        echo "✅ Container '$CONTAINER_NAME' is already running."
        com.freerdp.FreeRDP /v:127.0.0.1 /u:Docker /p:novarch /dynamic-resolution /sound
    else
        echo "⚠️ Container '$CONTAINER_NAME' is not running. Starting it..."
        podman-compose -f ~/.config/winapps/compose.yaml up -d
        sleep 2
        com.freerdp.FreeRDP /v:127.0.0.1 /u:Docker /p:novarch /dynamic-resolution /sound
    fi

elif [ "$1" == "stop" ]; then
    echo "🛑 Stopping container '$CONTAINER_NAME'..."
    podman-compose -f ~/.config/winapps/compose.yaml down

else
    echo "❌ Invalid argument."
    echo "Usage: $0 [start|stop]"
    exit 1
fi
