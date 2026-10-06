-- ═══════════════════════════════════════════════════════════════════════════
-- KEYBINDINGS — port of niri modules/binds.kdl
-- Mod = SUPER. Comments name the niri action each bind replaces.
-- ═══════════════════════════════════════════════════════════════════════════
local M   = "SUPER"
local dsp = hl.dsp
local S   = "~/.dotfiles/scripts/"

local function bind(keys, action, opts) hl.bind(keys, action, opts) end
local function run(cmd) return dsp.exec_cmd(cmd) end
local LOCK   = { locked = true, repeating = true }
local REPEAT = { repeating = true }

-- ── Help / theme ───────────────────────────────────────────────────────────
bind(M .. " + SHIFT + slash", run(S .. "quickshell/keybindings.sh"))
bind(M .. " + SHIFT + T",     run(S .. "quickshell/theme.sh"))
bind(M .. " + ALT + W",       run(S .. "quickshell/wallpaper.sh"))

-- ── Applications ───────────────────────────────────────────────────────────
bind(M .. " + space",          run("ghostty"))
bind(M .. " + W",              run("zen-browser"))
bind(M .. " + CTRL + W",       run("qutebrowser"))
bind(M .. " + SHIFT + W",      run("vpn-run qutebrowser"))
bind(M .. " + Return",         run("ghostty --title='tmux' -e zsh -ic tmux"))
bind(M .. " + D",              run("dms ipc call spotlight toggle"))
bind(M .. " + SHIFT + D",      run(S .. "rofi/tv-edit.sh"))
bind(M .. " + N",              run("emacsclient -c --alternate-editor="))
bind(M .. " + T",              run(S .. "tasks.sh"))
bind(M .. " + CTRL + T",       run("~/.local/bin/tv-remote"))
bind(M .. " + E",              run("ghostty -e explorenova"))

-- ── Utilities & menus ──────────────────────────────────────────────────────
bind(M .. " + O",              run(S .. "file_picker.sh"))
bind(M .. " + SHIFT + O",      run(S .. "ocr_select.sh"))
bind(M .. " + S",              run(S .. "quickshell/zen-url.sh"))
bind(M .. " + CTRL + G",       run(S .. "fix_grammar.sh"))
bind(M .. " + SHIFT + C",      run(S .. "quickshell/cal.sh"))
bind(M .. " + SHIFT + N",      run("dms ipc call notepad toggle"))
bind(M .. " + V",              run("dms ipc call clipboard toggle"))
bind(M .. " + SHIFT + P",      run(S .. "quickshell/pass.sh"))
bind(M .. " + CTRL + S",       run("dms ipc call control-center toggle"))
bind(M .. " + P",              run("scrcpy --max-fps 60 -Sw --turn-screen-off --stay-awake --keep-active --power-off-on-close --window-height=1150"))
bind(M .. " + CTRL + P",       run("scrcpy --max-fps 60 -Sw --turn-screen-off --stay-awake --keep-active --power-off-on-close --new-display=1920x1080 --window-title 'dexmode'"))
bind("ALT + space",            run("handy --toggle-transcription"))

-- ── Screenshots (niri's built-in UI → grim/slurp/satty) ─────────────────────
local shot = "~/Desktop/Screenshots/Screenshot\\ from\\ $(date +%Y-%m-%d\\ %H-%M-%S).png"
local function save(geom) -- grim to file + clipboard, like niri's screenshot actions
    return run("mkdir -p ~/Desktop/Screenshots && f=" .. shot .. " && grim " .. geom .. " \"$f\" && wl-copy < \"$f\"")
end
bind(M .. " + SHIFT + S", run("grim -g \"$(slurp)\" - | satty -f - --copy-command 'wl-copy'"))
bind("Print",             save("-g \"$(slurp)\""))
bind("CTRL + Print",      save("-o \"$(hyprctl -j monitors | jq -r '.[] | select(.focused).name')\""))
bind("ALT + Print",       save("-g \"$(hyprctl -j activewindow | jq -r '\"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\"')\""))

-- ── Screen recording ───────────────────────────────────────────────────────
bind(M .. " + CTRL + R",                 run(S .. "record-script.sh"))
bind(M .. " + CTRL + SHIFT + R",         run(S .. "record-script.sh --region"))
bind(M .. " + CTRL + ALT + R",           run(S .. "record-script.sh --fullscreen-both"))
bind(M .. " + CTRL + ALT + SHIFT + R",   run(S .. "record-script.sh --region-both"))

-- ── System controls ────────────────────────────────────────────────────────
bind(M .. " + SHIFT + L",       run(S .. "lock.sh"))
bind(M .. " + SHIFT + E",       run("dms ipc call powermenu toggle"))
bind(M .. " + Q",               dsp.window.close())
bind(M .. " + BackSpace",       dsp.window.close())
bind("CTRL + ALT + Delete",     dsp.exit())
bind(M .. " + CTRL + SHIFT + P", dsp.dpms({ action = "off" }))
bind("XF86PowerOff",            run("systemctl suspend-then-hibernate"), { locked = true })
bind("switch:on:Lid Switch",    run("systemctl suspend-then-hibernate"), { locked = true })
bind(M .. " + B",               run("qs -c island ipc call island toggleAutoHide"))

-- niri toggle-keyboard-shortcuts-inhibit: a submap where only Mod+Escape is live,
-- so every other key reaches the focused app (VMs, remote desktops).
bind(M .. " + Escape", dsp.submap("passthru"))
hl.define_submap("passthru", function()
    hl.bind(M .. " + Escape", dsp.submap("reset"))
end)

-- ── Media keys ─────────────────────────────────────────────────────────────
bind("XF86AudioRaiseVolume",         run("dms ipc call audio increment 5"), LOCK)
bind("XF86AudioLowerVolume",         run("dms ipc call audio decrement 5"), LOCK)
-- Brightness goes through the island so it flashes its OSD (sysfs has no change
-- signal); falls back to the script if the island is not running.
local BRIGHT = "qs -c island ipc call island brightness %s || " .. S .. "brightness.sh %s"
bind("SHIFT + XF86AudioRaiseVolume", run(BRIGHT:format("up", "up")),     LOCK)
bind("SHIFT + XF86AudioLowerVolume", run(BRIGHT:format("down", "down")), LOCK)
bind("XF86AudioMute",                run("dms ipc call audio mute"),        { locked = true })
bind("SHIFT + XF86AudioMute",        run("if pkill swayidle; then notify-send 'Suspend disabled'; else swayidle & notify-send 'Suspend enabled'; fi"), { locked = true })
bind("XF86AudioMicMute",             run("dms ipc call audio micmute"),     { locked = true })
bind("XF86MonBrightnessUp",          run(BRIGHT:format("up", "up")),     LOCK)
bind("XF86MonBrightnessDown",        run(BRIGHT:format("down", "down")), LOCK)

-- ── Columns (focus-column-* / move-column-*) ────────────────────────────────
for _, k in ipairs({ "left", "H" }) do
    bind(M .. " + " .. k,          dsp.focus({ direction = "l" }))
    bind(M .. " + CTRL + " .. k,   dsp.layout("swapcol l"))
end
for _, k in ipairs({ "right", "L" }) do
    bind(M .. " + " .. k,          dsp.focus({ direction = "r" }))
    bind(M .. " + CTRL + " .. k,   dsp.layout("swapcol r"))
end

-- ── Windows inside a column (move-window-up/down) ───────────────────────────
for _, k in ipairs({ "down", "J" }) do bind(M .. " + CTRL + " .. k, dsp.window.move({ direction = "d" })) end
for _, k in ipairs({ "up",   "K" }) do bind(M .. " + CTRL + " .. k, dsp.window.move({ direction = "u" })) end

-- ── Monitors ───────────────────────────────────────────────────────────────
bind(M .. " + SHIFT + left",  dsp.focus({ monitor = "l" }))
bind(M .. " + SHIFT + right", dsp.focus({ monitor = "r" }))
for k, d in pairs({ left = "l", down = "d", up = "u", right = "r", H = "l", J = "d", K = "u", L = "r" }) do
    bind(M .. " + SHIFT + CTRL + " .. k, dsp.window.move({ monitor = d }))
end

-- ── Workspaces (niri vertical workspaces → relative ids) ─────────────────────
-- r+1 also opens the next empty workspace, like niri's trailing empty one.
for _, k in ipairs({ "down", "J", "Page_Down" }) do bind(M .. " + " .. k, dsp.focus({ workspace = "r+1" })) end
for _, k in ipairs({ "up",   "K", "Page_Up" })   do bind(M .. " + " .. k, dsp.focus({ workspace = "r-1" })) end
for _, k in ipairs({ "Page_Down", "U" }) do bind(M .. " + CTRL + " .. k, dsp.window.move({ workspace = "r+1" })) end
for _, k in ipairs({ "Page_Up",   "I" }) do bind(M .. " + CTRL + " .. k, dsp.window.move({ workspace = "r-1" })) end
-- niri move-workspace-up/down (Mod+Shift+U/I, Page_Up/Down): no Hyprland equivalent, unbound.

for i = 1, 9 do
    bind(M .. " + " .. i,          dsp.focus({ workspace = i }))
    bind(M .. " + CTRL + " .. i,   dsp.window.move({ workspace = i }))
end

-- Window switcher (Mod+Tab) and niri's overview slot (Alt+Tab).
bind(M .. " + Tab",  run(S .. "quickshell/switcher.sh"))
bind("ALT + Tab",    run(S .. "quickshell/switcher.sh"))

-- ── Mouse wheel ────────────────────────────────────────────────────────────
bind(M .. " + mouse_down",                dsp.focus({ direction = "r" }))
bind(M .. " + mouse_up",                  dsp.focus({ direction = "l" }))
bind(M .. " + CTRL + mouse_down",         dsp.focus({ workspace = "r+1" }))
bind(M .. " + CTRL + mouse_up",           dsp.focus({ workspace = "r-1" }))
bind(M .. " + mouse_right",               dsp.window.move({ workspace = "r+1" }))
bind(M .. " + mouse_left",                dsp.window.move({ workspace = "r-1" }))
bind(M .. " + CTRL + mouse_right",        dsp.layout("swapcol r"))
bind(M .. " + CTRL + mouse_left",         dsp.layout("swapcol l"))
bind(M .. " + SHIFT + mouse_down",        dsp.focus({ direction = "r" }))
bind(M .. " + SHIFT + mouse_up",          dsp.focus({ direction = "l" }))
bind(M .. " + CTRL + SHIFT + mouse_down", dsp.layout("swapcol r"))
bind(M .. " + CTRL + SHIFT + mouse_up",   dsp.layout("swapcol l"))

-- Drag / resize with Mod + mouse (niri does this by default).
bind(M .. " + mouse:272", dsp.window.drag(),   { mouse = true })
bind(M .. " + mouse:273", dsp.window.resize(), { mouse = true })

-- ── Window management ──────────────────────────────────────────────────────
bind(M .. " + bracketleft",  dsp.layout("consume_or_expel prev"))
bind(M .. " + bracketright", dsp.layout("consume_or_expel next"))
bind(M .. " + comma",        dsp.layout("consume"))
bind(M .. " + period",       dsp.layout("expel"))

bind(M .. " + R",            dsp.layout("colresize +conf"))           -- switch-preset-column-width
bind(M .. " + SHIFT + R",    dsp.window.resize({ x = 0, y = -100, relative = true })) -- no preset heights in Hyprland
bind(M .. " + ALT + R",      dsp.layout("promote"))                   -- closest to reset-window-height
bind(M .. " + F",            dsp.layout("colresize 1.0"))             -- maximize-column
bind(M .. " + SHIFT + F",    dsp.window.fullscreen({ mode = "fullscreen" }))
bind(M .. " + C",            dsp.layout("fit active"))                -- center-column
bind(M .. " + CTRL + C",     dsp.layout("fit visible"))               -- center-visible-columns

bind(M .. " + minus",         dsp.layout("colresize -0.1"),                              REPEAT)
bind(M .. " + equal",         dsp.layout("colresize +0.1"),                              REPEAT)
bind(M .. " + SHIFT + minus", dsp.window.resize({ x = 0, y = -100, relative = true }),   REPEAT)
bind(M .. " + SHIFT + equal", dsp.window.resize({ x = 0, y = 100,  relative = true }),   REPEAT)

bind(M .. " + CTRL + F", dsp.window.float({ action = "toggle" }))
-- switch-focus-between-floating-and-tiling
bind(M .. " + SHIFT + Tab", function()
    local w = hl.get_active_window()
    local floating = w ~= nil and w.floating
    hl.dispatch(dsp.window.cycle_next({ tiled = floating, floating = not floating }))
end)
