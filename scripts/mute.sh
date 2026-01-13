#!/usr/bin/env bash

# Get the current mute status
MUTE_STATUS=$(pamixer --get-mute)

# Check the mute status and toggle accordingly
if [ "$MUTE_STATUS" = "true" ]; then
  pamixer --unmute
else
  pamixer --mute
fi

