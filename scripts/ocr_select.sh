#!/usr/bin/env bash

# 1. Select area (slurp) and Capture Screenshot (grim)
# We pipe the image directly into memory, no temp files needed.
GEOMETRY=$(slurp)

# Check if user cancelled selection (Esc)
if [ -z "$GEOMETRY" ]; then
	exit 1
fi

notify-send -t 1000 "OCR" "Processing..."

# 2. Run OCR (Tesseract)
# 'grim -g' takes the area.
# '-' tells grim to output to stdout.
# 'tesseract stdin stdout' reads from pipe and writes to pipe.
# '-l eng' uses English (add 'eng+chi_sim' for English + Chinese, etc.)
TEXT=$(grim -g "$GEOMETRY" - | tesseract stdin stdout -l eng 2>/dev/null)

# 3. Check Result
if [ -z "$TEXT" ]; then
	notify-send "OCR" "No text detected."
	exit 1
fi

# 4. Cleanup & Copy
# Trim whitespace
FINAL_TEXT=$(echo "$TEXT" | xargs)

echo "$FINAL_TEXT" | wl-copy
notify-send "OCR" "Text copied to clipboard!"
