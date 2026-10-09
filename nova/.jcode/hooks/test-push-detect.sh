#!/usr/bin/env bash
# Table-driven test of the pre_tool push detector.
MARKER_DIR="${XDG_RUNTIME_DIR:-/tmp}/jcode-coolify-pending"
HOOK=/home/nova/.jcode/hooks/coolify-push-detect.sh
pass=0; fail=0

run() { # name | cwd | command | expect(yes/no) | expect_dir(optional)
  local name="$1" cwd="$2" cmd="$3" expect="$4" expect_dir="${5:-}"
  rm -rf "$MARKER_DIR"; mkdir -p "$MARKER_DIR"
  printf '%s' "$(jq -nc --arg c "$cmd" '{command:$c}')" | \
    JCODE_HOOK_TOOL_NAME=bash JCODE_HOOK_CWD="$cwd" JCODE_HOOK_SESSION_ID=t \
    "$HOOK" >/dev/null 2>&1
  local got=no dir=""
  if [[ -f "$MARKER_DIR/t.json" ]]; then got=yes; dir=$(jq -r .repo_dir "$MARKER_DIR/t.json"); fi
  if [[ "$got" == "$expect" ]] && { [[ -z "$expect_dir" ]] || [[ "$dir" == "$expect_dir" ]]; }; then
    echo "PASS  $name"; pass=$((pass+1))
  else
    echo "FAIL  $name (got=$got dir=$dir want=$expect $expect_dir)"; fail=$((fail+1))
  fi
}

P=/home/nova/Projects/EEC/eecglobal-lms
run "plain push in Projects"        "$P" "git push" yes "$P"
run "push with remote+branch"       "$P" "git push origin main" yes "$P"
run "push --tags"                   "$P" "git push --tags" yes "$P"
run "force push"                    "$P" "git push --force origin main" yes "$P"
run "gh pr merge"                   "$P" "gh pr merge 12 --squash" yes "$P"
run "cd then push"                  "/home/nova" "cd $P && git push" yes "$P"
run "chained after commit"          "$P" "git add -A && git commit -m x && git push" yes "$P"
run "git -C push"                   "/home/nova" "git -C $P push" yes "$P"
run "dry-run ignored"               "$P" "git push --dry-run" no
run "outside Projects ignored"      "/home/nova/personal/lin-whatsapp" "git push" no
run "home dir ignored"              "/home/nova" "git push" no
run "mere mention ignored"          "$P" "echo 'remember to git push later'" no
run "grep for push ignored"         "$P" "grep -rn 'git push' docs/" no
run "set-url --push ignored"        "$P" "git remote set-url --push origin x" no
run "status not push"               "$P" "git status" no
run "cd outside then push"          "$P" "cd /home/nova/personal/lin-whatsapp && git push" no

echo; echo "passed=$pass failed=$fail"; exit $fail
