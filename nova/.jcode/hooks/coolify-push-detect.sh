#!/usr/bin/env bash
# jcode pre_tool hook: detect `git push` issued from a repo under ~/Projects.
#
# post_tool does not receive the tool command, only the tool name, cwd and
# status. So this hook records a marker that the paired post_tool hook consumes
# once the push has actually finished.
#
# Must always exit 0 quickly: pre_tool gates every tool call.

set -uo pipefail

PROJECTS_ROOT="${JCODE_COOLIFY_PROJECTS_ROOT:-$HOME/Projects}"
MARKER_DIR="${XDG_RUNTIME_DIR:-/tmp}/jcode-coolify-pending"

finish() { exit 0; }
trap finish EXIT

[[ "${JCODE_HOOK_TOOL_NAME:-}" == "bash" ]] || exit 0

# The tool input arrives on stdin as JSON; JCODE_HOOK_TOOL_INPUT is a truncated
# mirror of the same thing. Prefer stdin, fall back to the env copy.
raw_input="$(cat 2>/dev/null)"
[[ -n "$raw_input" ]] || raw_input="${JCODE_HOOK_TOOL_INPUT:-}"
[[ -n "$raw_input" ]] || exit 0

command_text="$(printf '%s' "$raw_input" | jq -r '.command // empty' 2>/dev/null)"
[[ -n "$command_text" ]] || exit 0

# Quoted text is data, not a command: `echo "run git push later"` must not fire.
# Blank out single- and double-quoted spans before matching.
scan_text="$(printf '%s' "$command_text" | sed -E "s/'[^']*'/''/g; s/\"[^\"]*\"/\"\"/g")"

# Match a real push, not a mention of one. Covers `git push`, `git -C <dir> push`,
# `git push --tags`, `git push --force`, and `gh pr merge`.
if ! printf '%s' "$scan_text" | grep -qE '(^|[;&|[:space:]])git([[:space:]]+-[^;&|]*)?[[:space:]]+push([[:space:]]|$)|(^|[;&|[:space:]])gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)'; then
  exit 0
fi

# Ignore dry runs: they never trigger a deployment.
printf '%s' "$command_text" | grep -qE -- '--dry-run' && exit 0

# Work out which directory the push runs in. A command commonly starts with
# `cd <dir> && git push`, in which case the session cwd is not the repo.
repo_dir="${JCODE_HOOK_CWD:-$PWD}"
cd_target="$(printf '%s' "$command_text" \
  | grep -oE '(^|[;&|[:space:]])cd[[:space:]]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^;&|[:space:]]+)' \
  | head -1 \
  | sed -E 's/^.*cd[[:space:]]+//; s/^["'"'"']//; s/["'"'"']$//')"
if [[ -n "$cd_target" ]]; then
  case "$cd_target" in
    /*) repo_dir="$cd_target" ;;
    ~*) repo_dir="${cd_target/#\~/$HOME}" ;;
    *)  repo_dir="${JCODE_HOOK_CWD:-$PWD}/$cd_target" ;;
  esac
fi
# `git -C <dir> push` wins over any cd.
git_c_target="$(printf '%s' "$command_text" \
  | grep -oE 'git[[:space:]]+-C[[:space:]]+("[^"]+"|'"'"'[^'"'"']+'"'"'|[^;&|[:space:]]+)' \
  | head -1 \
  | sed -E 's/^git[[:space:]]+-C[[:space:]]+//; s/^["'"'"']//; s/["'"'"']$//')"
[[ -n "$git_c_target" ]] && repo_dir="$git_c_target"

repo_dir="$(cd "$repo_dir" 2>/dev/null && pwd -P)" || exit 0

# Only ~/Projects, at any depth. Resolve the root too so a symlinked ~/Projects
# still matches.
projects_real="$(cd "$PROJECTS_ROOT" 2>/dev/null && pwd -P)" || exit 0
[[ "$repo_dir" == "$projects_real" || "$repo_dir" == "$projects_real"/* ]] || exit 0

mkdir -p "$MARKER_DIR" 2>/dev/null || exit 0
session="${JCODE_HOOK_SESSION_ID:-unknown}"
jq -n \
  --arg dir "$repo_dir" \
  --arg session "$session" \
  --arg at "$(date -Is)" \
  '{repo_dir: $dir, session_id: $session, detected_at: $at}' \
  > "$MARKER_DIR/$session.json" 2>/dev/null

exit 0
