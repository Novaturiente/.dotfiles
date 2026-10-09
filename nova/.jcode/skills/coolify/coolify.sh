#!/usr/bin/env bash
# Thin Coolify API v1 wrapper. Credentials come from ~/.env
# (COOLIFY_URL, COOLIFY_API_KEY), or from the environment if already exported.
#
#   coolify.sh GET  /applications
#   coolify.sh GET  '/deploy?uuid=UUID&force=false'
#   coolify.sh PATCH /applications/UUID '{"name":"new-name"}'
#   coolify.sh POST /applications/UUID/envs '{"key":"FOO","value":"bar"}'
#   coolify.sh get   /applications/UUID fqdn git_branch   # print only these keys
#   coolify.sh envs  /applications/UUID   # env var names + uuids, values not printed
#   coolify.sh find  SUBSTRING            # uuid + status by name / domain / git repo
#   coolify.sh latest APP_UUID            # newest deployment uuid + status
#   coolify.sh watch DEPLOYMENT_UUID [timeout_seconds]
#   coolify.sh watch-app APP_UUID [timeout_seconds]   # wait for a webhook deploy, then watch
#   coolify.sh logs  DEPLOYMENT_UUID [tail_lines]
set -euo pipefail

ENV_FILE="${COOLIFY_ENV_FILE:-$HOME/.env}"
POLL=10                  # seconds between deployment status checks
DEFAULT_TIMEOUT=540      # under the 600s Bash tool cap; run longer waits in background

read_env() {
  # Value may be quoted and contains "|" (Sanctum token), so no eval/source.
  [ -f "$ENV_FILE" ] || return 0
  sed -nE "s/^(export[[:space:]]+)?$1=[\"']?([^\"']*)[\"']?[[:space:]]*$/\2/p" "$ENV_FILE" | tail -1
}

BASE="${COOLIFY_URL:-$(read_env COOLIFY_URL)}"
BASE="${BASE%/}"
KEY="${COOLIFY_API_KEY:-$(read_env COOLIFY_API_KEY)}"

if [ -z "$BASE" ] || [ -z "$KEY" ]; then
  echo "coolify: COOLIFY_URL / COOLIFY_API_KEY not found in $ENV_FILE" >&2
  exit 2
fi

# Prints the response body; returns 1 on transport failure or HTTP >= 400.
api() {
  local method="$1" path="$2" body="${3:-}" out code
  local -a args=(-sS -X "$method"
    -H "Authorization: Bearer $KEY"
    -H "Accept: application/json"
    -w $'\n%{http_code}')
  [ -n "$body" ] && args+=(-H "Content-Type: application/json" -d "$body")

  out="$(curl "${args[@]}" "$BASE/api/v1/${path#/}")" \
    || { echo "coolify: request to $BASE failed" >&2; return 1; }
  code="${out##*$'\n'}"
  out="${out%$'\n'*}"

  printf '%s\n' "$out" | python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    print(json.dumps(json.loads(raw), indent=2))
except ValueError:
    print(raw, end="")
'
  case "$code" in
    [123]??) return 0 ;;
    *) echo "coolify: HTTP $code on $method $path" >&2; return 1 ;;
  esac
}

# Read one top-level key out of a JSON object on stdin.
field() {
  python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1]) or "")' "$1"
}

deployment_logs() {
  local uuid="$1" tail="${2:-40}"
  api GET "deployments/$uuid" | python3 -c '
import json, sys
d = json.load(sys.stdin)
try:
    lines = json.loads(d.get("logs") or "[]")
except ValueError:
    lines = []
if not lines:
    sys.exit("(no build log recorded for this deployment)")
for e in lines[-int(sys.argv[1]):]:
    print(e.get("output", "").rstrip())
' "$tail"
}

# Poll one deployment until it settles. 0 = finished, 1 = failed/cancelled/timeout.
watch_deployment() {
  local uuid="$1" timeout="${2:-$DEFAULT_TIMEOUT}" status="" deadline
  deadline=$((SECONDS + timeout))
  while [ "$SECONDS" -lt "$deadline" ]; do
    status="$(api GET "deployments/$uuid" | field status)" \
      || { echo "coolify: cannot read deployment $uuid" >&2; return 1; }
    case "$status" in
      finished|success)
        echo "deployment $uuid: $status"; return 0 ;;
      failed|error|cancelled|cancelled_by_user)
        echo "deployment $uuid: $status"
        deployment_logs "$uuid" 40 >&2 || true
        return 1 ;;
    esac
    sleep "$POLL"
  done
  echo "coolify: timed out after ${timeout}s, last status: ${status:-unknown}" >&2
  return 1
}

# Newest deployment for an application: uuid, status, short commit, created_at.
latest_deployment() {
  api GET "deployments/applications/$1" | python3 -c '
import json, sys
d = json.load(sys.stdin).get("deployments") or []
if not d:
    sys.exit("no deployments found")
x = d[0]
print(x["deployment_uuid"], x["status"], (x.get("commit") or "")[:8], x.get("created_at", ""))
'
}

# Post-push helper: wait for the webhook deployment to appear, then watch it.
watch_app() {
  local app="$1" timeout="${2:-$DEFAULT_TIMEOUT}" deadline line uuid status
  deadline=$((SECONDS + 60))
  while :; do
    line="$(latest_deployment "$app")" || return 1
    uuid="${line%% *}"; status="$(echo "$line" | cut -d' ' -f2)"
    case "$status" in
      queued|in_progress) break ;;
    esac
    if [ "$SECONDS" -ge "$deadline" ]; then
      echo "coolify: no new deployment started within 60s (latest: $line)" >&2
      return 1
    fi
    sleep "$POLL"
  done
  echo "watching $line"
  watch_deployment "$uuid" "$timeout"
}

# List env var names (and uuids, needed for DELETE) without printing secrets.
env_names() {
  api GET "${1%/}/envs" | python3 -c '
import json, sys
for e in json.load(sys.stdin):
    print("%-40s %s" % (e.get("key"), e.get("uuid")))
'
}

# Print selected keys of one resource instead of its ~100-key JSON.
get_fields() {
  local path="$1"; shift
  api GET "$path" | python3 -c '
import json, sys
d = json.load(sys.stdin)
for k in sys.argv[1:]:
    print("%s=%s" % (k, d.get(k)))
' "$@"
}

# One /resources call covers applications, services and databases.
find_resource() {
  api GET resources | python3 -c '
import json, sys
term = sys.argv[1].lower()
for r in json.load(sys.stdin):
    hay = " ".join(str(r.get(k) or "") for k in
                   ("name", "fqdn", "description", "git_repository", "git_branch"))
    if term in hay.lower():
        print("%-18s %-26s %-22s %s" % (r.get("type"), r.get("uuid"),
                                        r.get("status"), r.get("name")))
' "$1"
}

case "${1:-}" in
  get)       shift; get_fields "$@" ;;
  envs)      shift; env_names "$@" ;;
  find)      shift; find_resource "$@" ;;
  latest)    shift; latest_deployment "$@" ;;
  watch)     shift; watch_deployment "$@" ;;
  watch-app) shift; watch_app "$@" ;;
  logs)      shift; deployment_logs "$@" ;;
  GET|POST|PATCH|PUT|DELETE) api "$@" ;;
  *) sed -n '2,15p' "$0" >&2; exit 2 ;;
esac
