#!/usr/bin/env bash
#
# Extract keybindings from Neovim by running it headless and dumping
# nvim_get_keymap() for all modes. Writes bindings/neovim.txt with
# padded columns (mode+key, action) so the keybindings menu aligns.
#
# Usage: extract-neovim-keybindings.sh
#   Uses $NVIM_APPNAME and standard config (e.g. ~/.config/nvim).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINDINGS_DIR="${SCRIPT_DIR}/bindings"
OUT_FILE="${BINDINGS_DIR}/neovim.txt"
DUMP_LUA=$(mktemp)
DUMP_OUT=$(mktemp)
trap 'rm -f "$DUMP_LUA" "$DUMP_OUT"' EXIT

# Lua snippet: dump all keymaps to the path in vim.g.dump_keymaps_out
# Runs after init.lua, so user keymaps (and plugins) are loaded.
cat > "$DUMP_LUA" << 'LUA'
local out_path = vim.g.dump_keymaps_out
if not out_path or out_path == "" then
  return
end
local mode_labels = { n = "n", i = "i", v = "v", t = "t", c = "c", x = "x", s = "s", o = "o" }
local lines = {}
for _, mode in ipairs({ "n", "i", "v", "t", "c", "x", "s", "o" }) do
  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
    local lhs = m.lhs:gsub("%s+", " ")
    local action = (m.desc and #m.desc > 0) and m.desc or m.rhs or ""
    if #action > 60 then
      action = action:sub(1, 57) .. "..."
    end
    action = action:gsub("[\r\n]+", " ")
    table.insert(lines, mode .. " " .. lhs .. "\t" .. action)
  end
end
local f = io.open(out_path, "w")
if f then
  f:write(table.concat(lines, "\n"))
  f:close()
end
LUA

if ! command -v nvim &>/dev/null; then
  echo "Error: nvim not found" >&2
  exit 1
fi

mkdir -p "$BINDINGS_DIR"
# Run Neovim headless; init loads config and keymaps, then we dump to file
export NVIM_DUMP_OUT="$DUMP_OUT"
nvim --headless -c "lua vim.g.dump_keymaps_out = os.getenv('NVIM_DUMP_OUT'); dofile('$DUMP_LUA')" -c "qall" 2>/dev/null || true

if [[ ! -s "$DUMP_OUT" ]]; then
  # Fallback: create minimal file so "neovim" still appears in the menu
  echo "n <leader>?   (run extract-neovim-keybindings.sh when nvim is available)" > "$OUT_FILE"
  exit 0
fi

# Sort and pad key column for rofi alignment (same as niri)
sort -t$'\t' -k1 -o "$DUMP_OUT" "$DUMP_OUT"
key_width=$(awk -F'\t' 'max < length($1) { max = length($1) } END { print max + 0 }' "$DUMP_OUT")
[[ -z "$key_width" || "$key_width" -lt 15 ]] && key_width=28
awk -F'\t' -v "w=$key_width" '{ printf "%-*s  %s\n", w, $1, $2 }' "$DUMP_OUT" > "$OUT_FILE"

echo "Updated $OUT_FILE ($(wc -l < "$OUT_FILE") keybindings)" >&2
