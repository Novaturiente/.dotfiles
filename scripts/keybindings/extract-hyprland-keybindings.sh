#!/usr/bin/env bash
#
# Extract keybindings from Hyprland's binds.lua and write bindings/hyprland.txt.
# `hyprctl binds` is no help here: with a Lua config every action shows up as
# "__lua". So binds.lua is run under plain lua with a stub `hl` that records
# each hl.bind() call instead (loops in binds.lua expand for free). A bind
# whose derived label is unclear can set opts.description in binds.lua.
#
# Usage: extract-hyprland-keybindings.sh [binds.lua]
#   Default config: $HYPR_BINDS or $HOME/.config/hypr/binds.lua

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINDINGS_DIR="${SCRIPT_DIR}/bindings"
OUT_FILE="${BINDINGS_DIR}/hyprland.txt"
CONFIG="${1:-${HYPR_BINDS:-$HOME/.config/hypr/binds.lua}}"

if [[ ! -f "$CONFIG" ]]; then
    echo "Error: config not found: $CONFIG" >&2
    exit 1
fi

mkdir -p "$BINDINGS_DIR"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

lua - "$CONFIG" > "$tmp" <<'LUA'
local MODS = { SUPER = "Mod", SHIFT = "Shift", CTRL = "Ctrl", CONTROL = "Ctrl", ALT = "Alt" }

local function fmt_arg(a)
    if type(a) ~= "table" then return tostring(a) end
    local parts = {}
    for k, v in pairs(a) do parts[#parts + 1] = k .. "=" .. tostring(v) end
    table.sort(parts)
    return table.concat(parts, " ")
end

-- Shell command -> short label: drop the `|| fallback`, script dirs and the
-- island IPC prefix, then cap the length.
local function fmt_cmd(cmd)
    cmd = cmd:gsub("%s*||.*$", "")
    cmd = cmd:gsub("~/%.dotfiles/scripts/", ""):gsub("qs %-c island ipc call island ", "island ")
    if #cmd > 60 then cmd = cmd:sub(1, 57) .. "..." end
    return cmd
end

-- hl.dsp.<path>(arg) -> "<path> <arg>"; exec_cmd gets the command itself.
local function dsp(path)
    return setmetatable({}, {
        __index = function(_, k) return dsp(path and (path .. "." .. k) or k) end,
        __call = function(_, arg)
            if path == "exec_cmd" then return fmt_cmd(arg) end
            return arg == nil and path or (path .. " " .. fmt_arg(arg))
        end,
    })
end

local submap = nil
local function fmt_keys(keys)
    local out = {}
    for part in keys:gmatch("[^+]+") do
        local p = part:match("^%s*(.-)%s*$")
        out[#out + 1] = MODS[p] or p
    end
    local s = table.concat(out, "+")
    return submap and ("[" .. submap .. "] " .. s) or s
end

hl = {
    dsp = dsp(nil),
    bind = function(keys, action, opts)
        -- An explicit { description = "..." } in binds.lua wins over the derived label.
        local d = opts and (opts.description or opts.desc)
        if d then action = d elseif type(action) == "function" then action = "lua function" end
        io.write(fmt_keys(keys), "\t", tostring(action), "\n")
    end,
    define_submap = function(name, fn)
        submap = name; fn(); submap = nil
    end,
}

dofile(arg[1])
LUA

# Sort by key and pad the key column, same layout as niri.txt
sort -t$'\t' -k1 -o "$tmp" "$tmp"
key_width=$(awk -F'\t' 'max < length($1) { max = length($1) } END { print max + 0 }' "$tmp")
[[ -z "$key_width" || "$key_width" -lt 20 ]] && key_width=28
awk -F'\t' -v "w=$key_width" '{ printf "%-*s  %s\n", w, $1, $2 }' "$tmp" > "$OUT_FILE"

echo "Updated $OUT_FILE from $CONFIG ($(wc -l < "$OUT_FILE") keybindings)"
