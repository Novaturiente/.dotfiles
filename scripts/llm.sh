#!/usr/bin/env bash
#
# File: llm.sh
# Author: nova
# Created: 2025-10-10 16:51:10

PROCESS_NAME="ollama"

# Check if process exists and kill it
if pgrep -x "$PROCESS_NAME" >/dev/null; then
	echo "Process $PROCESS_NAME found. Killing..."
	pkill -9 "$PROCESS_NAME"
	notify-send "Ollama killed."
else
	echo "Process $PROCESS_NAME not running."
	ollama serve &
	notify-send "Ollama started"
fi
