#!/usr/bin/env bash

STEP=0.05
DIRECTION="$1"

CURRENT=$(playerctl volume)

case "$DIRECTION" in
  up)
    UPDATED=$(awk -v c="$CURRENT" -v s="$STEP" 'BEGIN {
      v = c + s;
      if (v > 1) v = 1;
      printf "%.2f", v
    }')
    ;;
  down)
    UPDATED=$(awk -v c="$CURRENT" -v s="$STEP" 'BEGIN {
      v = c - s;
      if (v < 0) v = 0;
      printf "%.2f", v
    }')
    ;;
  *)
    echo "Usage: $0 [up|down]"
    exit 1
    ;;
esac

playerctl volume "$UPDATED"
