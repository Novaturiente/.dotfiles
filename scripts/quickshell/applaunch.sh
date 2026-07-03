#!/usr/bin/env bash
# applaunch — headless backend for the Quickshell app launcher (drun replacement).
#   list          -> JSON [{id,name,icon,file}] of visible apps, most-used first
#   launch <file> -> bump its use count and launch it (respects Terminal=, Exec codes)
# Icons: QML resolves the Icon name via Quickshell.iconPath(); we just pass the name.
set -euo pipefail

COUNTS="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-applaunch.json"

cmd_list() {
    python3 - "$COUNTS" <<'PY'
import os, sys, json, glob, configparser

counts_file = sys.argv[1]
try:
    with open(counts_file) as f: counts = json.load(f)
except Exception:
    counts = {}

dirs = []
data_home = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
dirs.append(os.path.join(data_home, "applications"))
for d in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":"):
    if d: dirs.append(os.path.join(d, "applications"))

seen = {}   # desktop-id -> entry (first dir wins = user overrides system)
for d in dirs:
    for path in sorted(glob.glob(os.path.join(d, "*.desktop"))):
        did = os.path.basename(path)
        if did in seen: continue
        cp = configparser.RawConfigParser(interpolation=None, strict=False)
        try: cp.read(path, encoding="utf-8")
        except Exception: continue
        if not cp.has_section("Desktop Entry"): continue
        e = cp["Desktop Entry"]
        if e.get("Type", "") != "Application": continue
        if e.get("NoDisplay", "false").lower() == "true": continue
        if e.get("Hidden", "false").lower() == "true": continue
        name = e.get("Name", did)
        if not name: continue
        seen[did] = {"id": did, "name": name, "icon": e.get("Icon", ""), "file": path}

apps = list(seen.values())
# most-used first, then alphabetical
apps.sort(key=lambda a: (-int(counts.get(a["id"], 0)), a["name"].lower()))
print(json.dumps(apps))
PY
}

cmd_launch() {
    local file="$1" id; id=$(basename "$file")
    # bump use count (best-effort)
    python3 - "$COUNTS" "$id" <<'PY' 2>/dev/null || true
import sys, json, os
cf, did = sys.argv[1], sys.argv[2]
try:
    with open(cf) as f: c = json.load(f)
except Exception: c = {}
c[did] = int(c.get(did, 0)) + 1
os.makedirs(os.path.dirname(cf), exist_ok=True)
with open(cf, "w") as f: json.dump(c, f)
PY
    setsid gio launch "$file" >/dev/null 2>&1 &
}

case "${1:-}" in
list)   cmd_list ;;
launch) shift; cmd_launch "$@" ;;
*) echo "usage: applaunch {list|launch <file>}" >&2; exit 2 ;;
esac
