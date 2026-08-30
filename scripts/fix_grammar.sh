#!/bin/bash

# --- CONFIGURATION ---
# Load env (OMNIROUTE_API_KEY) since niri-spawned scripts may not inherit login env
[ -f ~/.env ] && set -a && . ~/.env && set +a

# OmniRoute gateway (OpenAI-compatible) on novahome; override with env
OMNIROUTE_URL="${OMNIROUTE_URL:-http://novahome:20128/v1}"
OMNIROUTE_MODEL="${OMNIROUTE_MODEL:-antigravity/gemini-3.7-flash-low}"
invoke_url="${OMNIROUTE_URL}/chat/completions"

if [ -z "$OMNIROUTE_API_KEY" ]; then
	notify-send "AI Fix" "OMNIROUTE_API_KEY not set in ~/.env"
	exit 1
fi
# Save raw API response (before <answer> extraction) for testing; set empty to disable
DEBUG_OUTPUT_FILE="${DEBUG_OUTPUT_FILE:-/tmp/fix_grammar_response.txt}"
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

# Clean input: escape backslashes for sed, then escape double quotes for safe use in PROMPT
CLEAN_INPUT=$(echo "$INPUT_TEXT" | sed 's/\\/\\\\/g')
PROMPT_SAFE=$(echo "$CLEAN_INPUT" | sed 's/"/\\"/g')
notify-send -t 1000 "AI Fix" "Fixing... $CLEAN_INPUT"

# 2. Run AI (OmniRoute chat completions API)
# We keep the tags <answer> in the prompt so we can find the text easily
PROMPT="You are a grammar correction tool. 
1. Output ONLY the corrected text. 
2. Maintain the original language (English).
3. Do not include any additional text.
4. Enclose the fixed text inside <answer> </answer>

Fix this text: $PROMPT_SAFE
"

# Build JSON body with jq so content is safely escaped (OpenAI chat/completions)
payload=$(jq -n \
	--arg content "$PROMPT" \
	--arg model "$OMNIROUTE_MODEL" \
	'{
		model: $model,
		messages: [{ role: "user", content: $content }],
		temperature: 0.3,
		max_tokens: 4096
	}')

response=$(curl -s -w "\n%{http_code}" --request POST \
	--url "$invoke_url" \
	--header "Authorization: Bearer $OMNIROUTE_API_KEY" \
	--header "Content-Type: application/json" \
	--data "$payload")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" != "200" ]; then
	notify-send "AI Fix" "API error (HTTP $http_code)"
	exit 1
fi

FIXED_TEXT=$(echo "$body" | jq -r '.choices[0].message.content // empty')

# Save raw fixed text before <answer> extraction (for testing)
if [ -n "$DEBUG_OUTPUT_FILE" ]; then
	printf '%s' "$FIXED_TEXT" > "$DEBUG_OUTPUT_FILE"
fi

# 3. Handle Result & Extract
if [ -n "$FIXED_TEXT" ]; then
	# --- EXTRACTION LOGIC ---
	# 1. Remove everything before (and including) <answer>
	# 2. Remove everything after (and including) </answer>
	# 3. Trim leading/trailing whitespace (sed; do not use xargs - it breaks on apostrophes)
	FINAL_TEXT=$(grep -ozP '(?s)<answer>\K.*?(?=</answer>)' <<<"$FIXED_TEXT" | tr -d '\0' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

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
	exit 1
fi
