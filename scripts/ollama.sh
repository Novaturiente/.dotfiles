#!/bin/bash

# Set your container name here
CONTAINER_NAME="ollama"

if podman ps --filter "name=^/${CONTAINER_NAME}$" --filter "status=running" --format '{{.Names}}' | grep -wq "$CONTAINER_NAME"; then
  echo "Ollama already running"
else
  echo "Starting ollama"
  podman-compose -f ~/.dotfiles/podman/ollama.yml up -d
fi

echo "Launching ollama"
ghostty --title=aiassistant -e "fish -c 'ollama $1 $2'"
