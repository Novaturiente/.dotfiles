#!/bin/sh
# Re-apply local patches in ../patches after `pi update` reinstalls packages.
# Idempotent: skips patches already applied, fails loudly if one no longer fits.
set -e
P=$(dirname "$(readlink -f "$0")")/../patches
for f in "$P"/*.patch; do
  case $(basename "$f") in
    pi-plan-mode-*) d=~/.pi/agent/npm/node_modules/@narumitw/pi-plan-mode ;;
    pi-claude-code-provider-*) d=~/.pi/agent/git/github.com/chem/pi-claude-code-provider ;;
    *) echo "no target for $(basename "$f")" >&2; exit 1 ;;
  esac
  if patch -d "$d" -p1 -R --dry-run -s -f < "$f" >/dev/null 2>&1; then
    echo "already applied: $(basename "$f")"
  else
    patch -d "$d" -p1 -N -s < "$f" && echo "applied: $(basename "$f")"
  fi
done
