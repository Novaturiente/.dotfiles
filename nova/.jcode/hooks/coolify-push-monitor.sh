#!/usr/bin/env bash
# jcode post_tool hook: after a bash tool call completes, if the paired
# pre_tool hook flagged it as a `git push` from ~/Projects, start the Coolify
# deployment monitor.
#
# The monitor runs detached and writes to a per-session log, so the hook itself
# returns immediately and never stalls the agent turn.

set -uo pipefail

MARKER_DIR="${XDG_RUNTIME_DIR:-/tmp}/jcode-coolify-pending"
LOG_DIR="$HOME/.jcode/logs/coolify-deploys"
WATCHER="$HOME/.jcode/hooks/coolify-watch-deploy.sh"

[[ "${JCODE_HOOK_TOOL_NAME:-}" == "bash" ]] || exit 0

session="${JCODE_HOOK_SESSION_ID:-unknown}"
marker="$MARKER_DIR/$session.json"
[[ -f "$marker" ]] || exit 0

# Consume the marker so a single push is monitored exactly once.
payload="$(cat "$marker" 2>/dev/null)"
rm -f "$marker" 2>/dev/null

# A push that errored out never reached the remote, so nothing will deploy.
[[ "${JCODE_HOOK_STATUS:-ok}" == "ok" ]] || exit 0

repo_dir="$(printf '%s' "$payload" | jq -r '.repo_dir // empty' 2>/dev/null)"
[[ -n "$repo_dir" && -d "$repo_dir" ]] || exit 0
[[ -x "$WATCHER" ]] || exit 0

mkdir -p "$LOG_DIR" 2>/dev/null
log_file="$LOG_DIR/$(date +%Y%m%d-%H%M%S)-$(basename "$repo_dir").log"

setsid nohup "$WATCHER" "$repo_dir" >"$log_file" 2>&1 < /dev/null &
disown 2>/dev/null

# Surfaced in the tool output so the agent notices and can read the log.
echo "[coolify] monitoring deployment for $(basename "$repo_dir"); log: $log_file"
exit 0
