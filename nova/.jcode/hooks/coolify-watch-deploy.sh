#!/usr/bin/env bash
# Identify and monitor the Coolify deployment triggered by a push.
#
# Usage: coolify-watch-deploy.sh <repo_dir>
#
# Matching strategy, most specific first:
#   1. The pushed commit SHA appears in a recent deployment.
#   2. A Coolify application matches the pushed remote repo AND branch, and has
#      a deployment created after the push.
# Ambiguity is reported rather than guessed at.

set -uo pipefail

REPO_DIR="${1:?usage: coolify-watch-deploy.sh <repo_dir>}"
POLL_INTERVAL="${COOLIFY_POLL_INTERVAL:-15}"
MAX_WAIT="${COOLIFY_MAX_WAIT:-600}"     # 10 min cap on the deploy itself
DETECT_WINDOW="${COOLIFY_DETECT_WINDOW:-45}"  # seconds to wait for webhook
API="$HOME/.jcode/skills/coolify/bin/coolify-api"

log() { printf '%s\n' "$*"; }

[[ -x "$API" ]] || { log "coolify-api wrapper not found at $API"; exit 1; }
command -v jq >/dev/null 2>&1 || { log "jq is required"; exit 1; }

cd "$REPO_DIR" 2>/dev/null || { log "not a directory: $REPO_DIR"; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { log "not a git repo: $REPO_DIR"; exit 1; }

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
SHA="$(git rev-parse HEAD 2>/dev/null)"
REMOTE_URL="$(git config --get remote.origin.url 2>/dev/null)"

# Normalise a git remote to the `owner/repo` form Coolify stores.
normalize_repo() {
  printf '%s' "$1" \
    | sed -E 's#^git@[^:]+:##; s#^ssh://git@[^/]+/##; s#^https?://[^/]+/##; s#\.git$##' \
    | tr '[:upper:]' '[:lower:]'
}
REPO_SLUG="$(normalize_repo "$REMOTE_URL")"

log "Repo:   $REPO_SLUG"
log "Branch: $BRANCH"
log "Commit: ${SHA:0:8}"

if [[ -z "$REPO_SLUG" ]]; then
  log "No origin remote; cannot match a Coolify application."
  exit 0
fi

# Applications whose repo and branch both match this push.
apps_json="$($API GET /applications 2>/dev/null)" || { log "Coolify API unreachable."; exit 1; }
matching_apps="$(printf '%s' "$apps_json" | jq -c --arg slug "$REPO_SLUG" --arg branch "$BRANCH" '
  [ .[]
    | select((.git_repository // "" | ascii_downcase
              | sub("^git@[^:]+:";"") | sub("^https?://[^/]+/";"") | sub("\\.git$";"")) == $slug)
    | select((.git_branch // "") == $branch)
    | {uuid, name, fqdn, git_branch} ]')"

app_count="$(printf '%s' "$matching_apps" | jq 'length')"
if [[ "$app_count" -eq 0 ]]; then
  log ""
  log "No Coolify application is configured for $REPO_SLUG on branch $BRANCH."
  log "The push will not trigger a deployment here. Nothing to monitor."
  exit 0
fi

log "Matched $app_count Coolify application(s):"
printf '%s' "$matching_apps" | jq -r '.[] | "  - \(.name)  [\(.uuid)]"'

# Wait for the webhook to queue a deployment for one of those apps.
log ""
log "Waiting up to ${DETECT_WINDOW}s for Coolify to queue a deployment..."
deployment_uuid=""
app_name=""
elapsed=0
while [[ "$elapsed" -lt "$DETECT_WINDOW" ]]; do
  sleep 5
  elapsed=$((elapsed + 5))
  deployments="$($API GET /deployments 2>/dev/null)" || continue

  # Prefer an exact commit SHA match: unambiguous even with several apps.
  hit="$(printf '%s' "$deployments" | jq -c --arg sha "$SHA" \
    'map(select((.commit // "") == $sha)) | .[0] // empty')"

  # Otherwise fall back to a deployment for one of the matched app names.
  if [[ -z "$hit" ]]; then
    hit="$(printf '%s' "$deployments" | jq -c --argjson apps "$matching_apps" '
      ($apps | map(.name)) as $names
      | map(select(.application_name as $n | $names | index($n)))
      | .[0] // empty')"
  fi

  if [[ -n "$hit" ]]; then
    deployment_uuid="$(printf '%s' "$hit" | jq -r '.deployment_uuid')"
    app_name="$(printf '%s' "$hit" | jq -r '.application_name')"
    break
  fi
done

if [[ -z "$deployment_uuid" ]]; then
  log ""
  log "No deployment appeared within ${DETECT_WINDOW}s."
  log "Likely causes: the Coolify webhook is not configured on this repo, the"
  log "push went to a branch Coolify does not deploy, or auto-deploy is off."
  exit 0
fi

log ""
log "Deployment $deployment_uuid for app '$app_name'. Polling until terminal..."

waited=0
status="unknown"
while [[ "$waited" -lt "$MAX_WAIT" ]]; do
  detail="$($API GET "/deployments/$deployment_uuid" 2>/dev/null)" || break
  status="$(printf '%s' "$detail" | jq -r '.status // "unknown"')"
  case "$status" in
    finished|failed|cancelled|error)
      break
      ;;
  esac
  log "  status=$status (${waited}s)"
  sleep "$POLL_INTERVAL"
  waited=$((waited + POLL_INTERVAL))
done

log ""
case "$status" in
  finished)
    log "Deployment finished. Checking application health..."
    app_uuid="$(printf '%s' "$matching_apps" | jq -r --arg n "$app_name" '.[] | select(.name == $n) | .uuid' | head -1)"
    if [[ -n "$app_uuid" ]]; then
      health="$($API GET "/applications/$app_uuid" 2>/dev/null | jq -r '"\(.status)  \(.fqdn // "no domain")"')"
      log "  $app_name: $health"
    fi
    ;;
  failed|error|cancelled)
    log "Deployment $status. Last log lines:"
    $API GET "/deployments/$deployment_uuid" 2>/dev/null \
      | jq -r '.logs // ""' \
      | tail -c 4000
    ;;
  *)
    log "Still $status after ${MAX_WAIT}s; stopped polling."
    log "Check manually: coolify-api GET /deployments/$deployment_uuid"
    ;;
esac
