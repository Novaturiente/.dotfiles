#!/bin/bash

# --- CONFIGURATION ---
MODEL_PATH="$HOME/ai-models/gemma-3n-E2B-it-Q4_K_M.gguf"
# Ensure ydotool knows where to look
export YDOTOOL_SOCKET="/run/user/$(id -u)/.ydotool_socket"

# 1. Grab Text
INPUT_TEXT=$(wl-paste --primary 2>/dev/null)

if [ -z "$INPUT_TEXT" ]; then
	sleep 0.5
	wl-copy -c
	ydotool key 29:1 46:1 46:0 29:0
	sleep 0.2
	INPUT_TEXT=$(wl-paste)
fi

if [ -z "$INPUT_TEXT" ]; then
	notify-send "AI Fix" "No text found."
	exit 1
fi

# Clean input
CLEAN_INPUT=$(echo "$INPUT_TEXT" | sed 's/\\/\\\\/g')
notify-send -t 1000 "AI Fix" "Fixing... $CLEAN_INPUT"

# 2. Run AI
# We keep the tags <answer> in the prompt so we can find the text easily
PROMPT="<|im_start|>system
You are a grammar correction tool. 
1. Output ONLY the corrected text. 
2. Maintain the original language (English).
3. Do not include any additional text.
4. Enclose the fixed text inside <answer> </answer>

Fix this text: $CLEAN_INPUT
"

# Note: We use -n 1024 to ensure it doesn't cut off long sentences
FIXED_TEXT=$(llama-completion -m "$MODEL_PATH" \
	-st \
	-p "$PROMPT" \
	2>/dev/null)

notify-send "$FIXED_TEXT"

# 3. Handle Result & Extract
if [ -n "$FIXED_TEXT" ]; then
	# --- EXTRACTION LOGIC ---
	# 1. Remove everything before (and including) <answer>
	# 2. Remove everything after (and including) </answer>
	# 3. Trim whitespace
	FINAL_TEXT=$(grep -ozP '(?s)<answer>\K.*?(?=</answer>)' <<<"$FIXED_TEXT" | tr -d '\0' | xargs)

	if [ -z "$FINAL_TEXT" ]; then
		notify-send "AI Error" "Could not find <answer> tags in output."
		exit 1
	fi

	# --- SUCCESS ---
	# Copy to clipboard
	echo -n "$FINAL_TEXT" | wl-copy

	# Notify (Optional, comment out if annoying)
	notify-send "AI Fix" "Pasting corrected text..."

	# 4. PASTE (Simulate Ctrl+V)
	sleep 0.2
	ydotool key 29:1 47:1 47:0 29:0
else
	notify-send "AI Fix" "AI returned EMPTY result."
fi
