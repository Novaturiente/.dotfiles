#!/bin/bash

# --- CONFIGURATION ---
# Load env (NINEROUTER_API_KEY) since niri-spawned scripts may not inherit login env
[ -f ~/.env ] && set -a && . ~/.env && set +a

# 9router gateway (OpenAI-compatible) on novahome; override with env
NINEROUTER_URL="${NINEROUTER_URL:-http://novahome:20129/v1}"
NINEROUTER_MODEL="${NINEROUTER_MODEL:-ag/gemini-3.8-flash-low}"
invoke_url="${NINEROUTER_URL}/chat/completions"

if [ -z "$NINEROUTER_API_KEY" ]; then
	notify-send "AI Fix" "NINEROUTER_API_KEY not set in ~/.env"
	exit 1
fi
# Save raw API response (before <answer> extraction) for testing; set empty to disable
DEBUG_OUTPUT_FILE="${DEBUG_OUTPUT_FILE:-}"
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

# No manual escaping: jq --arg below JSON-escapes the prompt
notify-send -t 1000 "AI Fix" "Fixing... $INPUT_TEXT"

# 2. Run AI (9router chat completions API)
# We keep the tags <answer> in the prompt so we can find the text easily
PROMPT="You are a grammar correction tool. 
1. Output ONLY the corrected text. 
2. Maintain the original language (English).
3. Do not include any additional text.
4. Enclose the fixed text inside <answer> </answer>

Fix this text: $INPUT_TEXT
"

# Build JSON body with jq so content is safely escaped (OpenAI chat/completions)
payload=$(jq -n \
	--arg content "$PROMPT" \
	--arg model "$NINEROUTER_MODEL" \
	'{
		model: $model,
		messages: [{ role: "user", content: $content }],
		stream: false,
		temperature: 0.3,
		max_tokens: 4096
	}')

response=$(curl -s -w "\n%{http_code}" --request POST \
	--url "$invoke_url" \
	--header "Authorization: Bearer $NINEROUTER_API_KEY" \
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
