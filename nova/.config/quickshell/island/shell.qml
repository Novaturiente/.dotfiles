//@ pragma UseQApplication
// Dynamic island — Quickshell. A pill at the top centre that shows the time,
// date and battery, and morphs into other pages on demand. The session shell
// under Hyprland and niri (hyprland.lua / niri startup.kdl start it).
//
// Start by hand (not autostarted yet):  qs -c island -d
//
// IPC (`qs -c island ipc call island <fn> [arg]`) — bind these to keys in niri:
//   toggle <mode>      open <mode>, or back to idle if it is already open
//   open <mode>        open <mode>; volume/brightness close after 1.5 s
//   idle               back to the clock
//   volume <arg>       "+5", "-5" or "mute"
//   brightness <arg>   "up" or "down" (same steps as scripts/brightness.sh)
// Modes: idle, volume, brightness, dashboard, tray, battery, wifi, bluetooth,
// output, input, spotlight (Mod+D search over apps, files, windows, pages, power,
// bookmarks, sums and the web; in SpotlightPage.qml), power (Left/Right/Enter; everything but Lock
// needs a second press within 3 s or a 1 s hold), polkit (password prompt; opens
// by itself when an app asks for authentication). Click the clock to open the dashboard,
// the battery for the battery page, a dot to switch workspace; click outside or press
// Esc to close (Esc on a sub-page goes back to the dashboard). On a dashboard
// tile the icon toggles, the rest opens its picker.
//
// Volume changes made anywhere flash the volume page; brightness only flashes
// when changed through here (sysfs backlight has no change signal).
//
// Notifications: the island is the notification server under Hyprland. One live
// popup morphs the idle pill into the card; two or more stack at the right edge.
// Right-clicking the clock, or the dashboard's bell, opens `hub` (media player +
// in-memory notification history); it closes like any other page.
//
// wallpaper (Ctrl+Alt+W): strip of images in ~/Pictures; Left/Right, Enter sets,
// Esc closes.
// theme (Mod+Shift+T): palettes from scripts/theme.sh --list; Left/Right, Enter applies.
// tools (Mod+T): toolbox (calculator, timer, stopwatch, alarms) in ToolsPage.qml;
// a running timer/stopwatch shows as a chip in the idle pill.
//
// Adding a mode: add its name to `modes`, a Page below, and a line in `page`.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Services.Polkit
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import Quickshell.Networking
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import common

ShellRoot {
    id: root

    readonly property var modes: ["idle", "volume", "brightness", "dashboard", "tray", "battery", "wifi", "bluetooth", "output", "input", "spotlight", "power", "polkit", "clipboard", "wallpaper", "theme", "hub", "browser", "switcher", "calendar", "pass", "keybindings", "tools"]
    readonly property var subPages: ["battery", "wifi", "bluetooth", "output", "input"]
    property string mode: "idle"
    // Anything bigger than the pill or an OSD: grabs the keyboard and closes on
    // a click outside.
    // Spotlight draws its own field pill and result panel, so the island has no surface then.
    readonly property bool islandBare: mode === "spotlight"
    readonly property bool expanded: !["idle", "volume", "brightness"].includes(mode)
    // Which slider the OSD page shows; kept apart from `mode` so the page does
    // not switch icon while it fades out.
    property string osdKind: "volume"
    // Auto-hide (Mod+B): the pill tucks up leaving a thin strip at the top edge.
    // Like the DMS bar, touching the top edge anywhere brings it back; it stays
    // while the pointer is on the edge or the pill, and tucks 250ms after it leaves.
    property bool autoHide: false
    property bool edgeHovered: false
    property bool pillHovered: false
    property bool hovered: false
    readonly property bool pointerIn: edgeHovered || pillHovered
    readonly property bool tucked: autoHide && mode === "idle" && !hovered && !notifInIsland

    onPointerInChanged: {
        if (pointerIn) {
            leaveTimer.stop();
            hovered = true;
        } else {
            leaveTimer.restart();
        }
    }

    Timer {
        id: leaveTimer
        interval: 250
        onTriggered: root.hovered = false
    }

    function show(m: string): void {
        if (!modes.includes(m))
            return;
        if (m === "volume" || m === "brightness") {
            osdKind = m;
            hideTimer.restart();
        } else {
            hideTimer.stop();
        }
        // Leaving the password prompt (Esc, click outside) cancels the request.
        if (mode === "polkit" && m !== "polkit" && polkit.flow && !polkit.flow.isCompleted)
            polkit.flow.cancelAuthenticationRequest();
        // New page: fresh cursor. Back from a dashboard picker keeps the dashboard's spot.
        if (m !== mode && !(m === "dashboard" && subPages.includes(mode))) {
            if (!expanded)
                kbNav = false;
            if (m === "dashboard")
                dashSel = 0;
            listSel = m === "battery" ? Math.max(0, profiles.indexOf(PowerProfiles.profile)) : 0;
        }
        mode = m;
        // Text fields must own the keyboard while their page is up; everywhere
        // else the island takes it back so Esc keeps working.
        if (m === "spotlight") {
            appLister.running = true;
        } else if (m === "polkit") {
            polkitField.text = "";
            Qt.callLater(() => polkitField.forceActiveFocus());
        } else if (m === "clipboard") {
            clipSearch.reset();
            clipLister.running = true;
            Qt.callLater(() => clipSearch.focusField());
        } else if (m === "theme") {
            themeLister.running = true;
            Qt.callLater(() => themeList.forceActiveFocus());
        } else if (m === "wallpaper") {
            // Land on the wallpaper that is already set.
            let i = 0;
            for (let j = 0; j < wpFiles.count; j++)
                if (wpFiles.get(j, "filePath") === root.wallpaper)
                    i = j;
            wallList.currentIndex = i;
            wallList.positionViewAtIndex(i, PathView.Center); // jump, don't scroll there
            Qt.callLater(() => wallList.forceActiveFocus());
        } else {
            if (m === "power") {
                powerSel = 0;
                powerArmed = -1;
            }
            island.forceActiveFocus();
        }
        // Pages in their own files reset, reload and take the keyboard on this.
        island.page.opened();
    }

    // OSD pages only flash when nothing bigger is open.
    function flash(m: string): void {
        if (!expanded)
            show(m);
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.mode = "idle"
    }

    function glyph(cp: int): string {
        return String.fromCodePoint(cp);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // --- Audio -------------------------------------------------------------
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    PwObjectTracker {
        objects: [root.sink, root.source]
    }
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)

    // Pipewire fires these while it binds at startup; ignore the first second.
    property bool armed: false
    Timer {
        running: true
        interval: 1000
        onTriggered: root.armed = true
    }
    onVolumeChanged: if (armed) flash("volume")
    onMutedChanged: if (armed) flash("volume")

    function setVolume(v: real): void {
        if (!sink?.audio)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    // --- App launcher ------------------------------------------------------
    readonly property string applaunch: Quickshell.env("HOME") + "/.dotfiles/scripts/quickshell/applaunch.sh"
    property var apps: [] // [{id,name,icon,file}], most-used first
    Process {
        id: appLister
        command: ["bash", root.applaunch, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.apps = JSON.parse(text);
                } catch (e) {
                    root.apps = [];
                }
            }
        }
    }
    function launchApp(file: string): void {
        Quickshell.execDetached(["bash", applaunch, "launch", file]);
        show("idle");
    }

    // --- Clipboard history (Mod+V) -----------------------------------------
    // cliphist records every copy (text, images, copied files as uri-lists);
    // the watcher lives and dies with the island (Hyprland and niri both run it).
    // Images are decoded once into clipCache for thumbnails; after each listing,
    // cache files whose id is no longer listed are deleted.
    readonly property string clipCache: Quickshell.env("HOME") + "/.cache/island/clip"
    property var clips: [] // [{line, text, image}], newest first
    Process {
        command: ["wl-paste", "--watch", "cliphist", "store"]
        running: true
    }
    Process {
        id: clipLister
        command: ["sh", "-c", "d=$1; mkdir -p \"$d\"; cliphist list | head -n 200 | while IFS= read -r l; do"
            + " case $l in *'[[ binary data'*) id=${l%%\t*}; [ -s \"$d/$id\" ] || printf '%s\\n' \"$l\" | cliphist decode > \"$d/$id\";; esac;"
            + " printf '%s\\n' \"$l\"; done > \"$d/.list\";"
            + " for f in \"$d\"/*; do [ -e \"$f\" ] || continue; grep -q \"^${f##*/}\t\" \"$d/.list\" || rm -f \"$f\"; done;"
            + " cat \"$d/.list\"", "sh", root.clipCache]
        stdout: StdioCollector {
            onStreamFinished: root.clips = text.split("\n").filter(l => l.includes("\t")).map(l => {
                const tab = l.indexOf("\t");
                const t = l.slice(tab + 1);
                return { line: l, id: l.slice(0, tab), text: t, image: t.startsWith("[[ binary data") };
            })
        }
    }
    function pickClip(c: var): void {
        // Copied files go back as text/uri-list so file managers paste files.
        const type = c.text.startsWith("file://") ? "-t text/uri-list" : "";
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy " + type, "sh", c.line]);
        show("idle");
    }

    // --- Theme picker (Mod+Shift+T) ----------------------------------------
    // Front end for scripts/theme.sh. First output line is the active theme,
    // the rest are `--list` rows: name label desc accent base text dots (tab-separated).
    readonly property string themeScript: Quickshell.env("HOME") + "/.dotfiles/scripts/theme.sh"
    property string themeCurrent: ""
    property var themes: [] // [{name,label,desc,accent,base,text,dots}]
    Process {
        id: themeLister
        command: ["sh", "-c", "bash \"$1\" --current; bash \"$1\" --list", "sh", root.themeScript]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim() !== "");
                root.themeCurrent = lines.shift() || "";
                root.themes = lines.map(l => {
                    const f = l.split("\t");
                    return { name: f[0], label: f[1], desc: f[2], accent: f[3], base: f[4], text: f[5], dots: (f[6] || "").split(",") };
                });
                const i = Math.max(0, root.themes.findIndex(t => t.name === root.themeCurrent));
                themeList.currentIndex = i;
                themeList.positionViewAtIndex(i, PathView.Center); // jump, don't scroll there
            }
        }
    }
    function applyTheme(name: string): void {
        // Detached: the apply rewrites common/Colors.qml, which reloads this
        // shell and would kill a child Process halfway through.
        Quickshell.execDetached(["bash", themeScript, name]);
        show("idle");
    }
    Process {
        id: clipDeleter
        onExited: clipLister.running = true
    }
    function deleteClip(c: var): void {
        clipDeleter.command = ["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", c.line];
        clipDeleter.running = true;
    }

    // --- Power menu --------------------------------------------------------
    // Lock runs at once; the rest need a second press within 3 s, or a 1 s hold.
    readonly property var powerActions: [
        { icon: 0xF033E, label: "Lock", confirm: false, cmd: [Quickshell.env("HOME") + "/.dotfiles/scripts/lock.sh"] },
        { icon: 0xF0343, label: "Log out", confirm: true, cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { icon: 0xF04B2, label: "Suspend", confirm: true, cmd: ["systemctl", "suspend-then-hibernate"] },
        { icon: 0xF0709, label: "Reboot", confirm: true, cmd: ["systemctl", "reboot"] },
        { icon: 0xF0425, label: "Shut down", confirm: true, cmd: ["systemctl", "poweroff"] }
    ]
    property int powerSel: 0
    property int powerArmed: -1
    // --- Keyboard navigation (pages without a text field) -------------------
    // h/j/k/l work as the arrows, g/G as Home/End. The focus ring shows only
    // once a key was pressed, so mouse use stays clean; that first key only
    // shows the ring. Pages in their own files handle their own keys.
    property int dashSel: 0 // 0 Display, 1 Sound, 2-7 the tiles (2 columns)
    property int listSel: 0 // cursor on the other pages
    property bool kbNav: false
    function navKey(e: var): int {
        if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier))
            return e.key;
        return { h: Qt.Key_Left, j: Qt.Key_Down, k: Qt.Key_Up, l: Qt.Key_Right, g: Qt.Key_Home, G: Qt.Key_End }[e.text] ?? e.key;
    }
    function pageKey(e: var): bool {
        const k = navKey(e), m = mode;
        const moves = [Qt.Key_Up, Qt.Key_Down, Qt.Key_Tab, Qt.Key_Backtab].concat(["dashboard", "battery", "tray"].includes(m) ? [Qt.Key_Left, Qt.Key_Right] : []);
        let done = true;
        if (e.text === "q" && expanded)
            show("idle");
        else if (k === Qt.Key_Backspace && subPages.includes(m))
            show("dashboard");
        else if (!kbNav && moves.includes(k) && m !== "power")
            done = true; // first move only shows the ring
        else if (m === "dashboard")
            done = dashKey(e, k);
        else if (m === "power")
            done = powerKey(k);
        else if ((m === "wifi" || m === "bluetooth") && k === Qt.Key_Left)
            show("dashboard");
        else if (m === "wifi")
            done = rowListKey(k, e, wifiRep, wifiScroll, wifiNets.length, () => Networking.wifiEnabled = !Networking.wifiEnabled, () => {
                if (wifiDev)
                    wifiDev.scannerEnabled = !wifiDev.scannerEnabled;
            });
        else if (m === "bluetooth")
            done = rowListKey(k, e, btRep, btScroll, btDevices.length, () => {
                if (btAdapter)
                    btAdapter.enabled = !btAdapter.enabled;
            }, () => {
                if (btAdapter?.enabled)
                    btAdapter.discovering = !btAdapter.discovering;
            });
        else if (m === "output" || m === "input")
            done = island.page.key(k, e);
        else if (m === "hub")
            done = hubKey(k, e);
        else if (m === "battery")
            done = batKey(k);
        else if (m === "tray")
            done = trayKey(k, e);
        else
            done = false;
        if (done)
            kbNav = true;
        return done;
    }
    // Vertical cursor over n rows (j/k, g/G); false for any other key.
    function listMove(k: int, n: int): bool {
        if (k === Qt.Key_Down)
            listSel = Math.min(n - 1, listSel + 1);
        else if (k === Qt.Key_Up)
            listSel = Math.max(0, listSel - 1);
        else if (k === Qt.Key_Home)
            listSel = 0;
        else if (k === Qt.Key_End)
            listSel = Math.max(0, n - 1);
        else
            return false;
        return true;
    }
    function dashKey(e: var, k: int): bool {
        const i = dashSel, tile = i >= 2 ? dashGrid.children[i - 2] : null;
        const step = k === Qt.Key_Right ? 0.05 : -0.05;
        if (k === Qt.Key_Tab)
            dashSel = (i + 1) % 8;
        else if (k === Qt.Key_Backtab)
            dashSel = (i + 7) % 8;
        else if (k === Qt.Key_Up)
            dashSel = i <= 1 ? 0 : i <= 3 ? 1 : i - 2;
        else if (k === Qt.Key_Down)
            dashSel = i === 0 ? 1 : i === 1 ? 2 : Math.min(7, i + 2);
        else if (k === Qt.Key_Home)
            dashSel = 0;
        else if (k === Qt.Key_End)
            dashSel = 7;
        else if ((k === Qt.Key_Left || k === Qt.Key_Right) && i === 0)
            setBrightness(brightness + step);
        else if ((k === Qt.Key_Left || k === Qt.Key_Right) && i === 1)
            setVolume(volume + step);
        else if (k === Qt.Key_Left || k === Qt.Key_Right)
            dashSel = i % 2 ? (k === Qt.Key_Left ? i - 1 : i) : (k === Qt.Key_Right ? i + 1 : i);
        else if ((k === Qt.Key_Space || e.text === "m") && i === 1 && sink?.audio)
            sink.audio.muted = !muted;
        else if (k === Qt.Key_Space && tile)
            tile.toggled();
        else if ((k === Qt.Key_Return || k === Qt.Key_Enter) && tile)
            tile.hasPage ? tile.opened() : tile.toggled();
        else if (e.text === "n")
            show("hub");
        else if (e.text === "b")
            show("battery");
        else if (e.text === "t")
            show("tray");
        else
            return false;
        return true;
    }
    function powerKey(k: int): bool {
        if (k === Qt.Key_Left)
            powerSel = Math.max(0, powerSel - 1);
        else if (k === Qt.Key_Right)
            powerSel = Math.min(powerActions.length - 1, powerSel + 1);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter)
            powerPress(powerSel, false);
        else
            return false;
        return true;
    }
    // Wi-Fi and Bluetooth lists: Enter/Space/l = the row's click, d/x = forget
    // (twice, like the mouse), t = radio on/off, r = scan.
    // shortcut: the cursor is an index, so it can land on another network when the
    // signal sort reorders the list; track the object if that bites.
    function rowListKey(k: int, e: var, rep: var, scroll: var, n: int, toggle: var, scan: var): bool {
        listSel = Math.max(0, Math.min(listSel, n - 1));
        const row = rep.itemAt(listSel);
        if (listMove(k, n))
            scroll.reveal(rep.itemAt(listSel));
        else if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space || k === Qt.Key_Right) && row)
            row.clicked();
        else if ((e.text === "d" || e.text === "x" || k === Qt.Key_Delete) && row?.action)
            row.forget();
        else if (e.text === "t")
            toggle();
        else if (e.text === "r")
            scan();
        else
            return false;
        return true;
    }
    // Hub: Enter = default action, Space/o/l = expand, h = collapse, d/x = dismiss,
    // c = copy, r = reply, 1-9 = the entry's action chips, C = clear all,
    // p / [ / ] = media play-pause / previous / next.
    function hubKey(k: int, e: var): bool {
        const n = history.length;
        listSel = Math.max(0, Math.min(listSel, n - 1));
        const row = hubRep.itemAt(listSel), t = e.text;
        if (listMove(k, n))
            hubScroll.reveal(hubRep.itemAt(listSel));
        else if ((k === Qt.Key_Return || k === Qt.Key_Enter) && row)
            histDefault(row.modelData);
        else if ((k === Qt.Key_Space || k === Qt.Key_Right || t === "o") && row)
            row.open = !row.open;
        else if (k === Qt.Key_Left && row)
            row.open = false;
        else if ((t === "d" || t === "x" || k === Qt.Key_Delete) && row)
            dismissHist(row.modelData);
        else if (t === "c" && row)
            row.copy();
        else if (t === "r" && row?.modelData.n?.hasInlineReply)
            row.reply();
        else if (t >= "1" && t <= "9" && t.length === 1 && row && histActions(row.modelData.n)[+t - 1])
            invokeHist(row.modelData, histActions(row.modelData.n)[+t - 1]);
        else if (t === "C")
            clearHistory();
        else if (t === "p" && player)
            player.togglePlaying();
        else if (t === "]" && player)
            player.next();
        else if (t === "[" && player)
            player.previous();
        else
            return false;
        return true;
    }
    // Battery: h/l (or j/k) pick a power profile, Enter/Space applies it.
    readonly property var profiles: [PowerProfile.PowerSaver, PowerProfile.Balanced].concat(PowerProfiles.hasPerformanceProfile ? [PowerProfile.Performance] : [])
    function batKey(k: int): bool {
        if (k === Qt.Key_Left || k === Qt.Key_Up)
            listSel = Math.max(0, listSel - 1);
        else if (k === Qt.Key_Right || k === Qt.Key_Down)
            listSel = Math.min(profiles.length - 1, listSel + 1);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
            PowerProfiles.profile = profiles[listSel];
        else
            return false;
        return true;
    }
    // Tray: h/l move, Enter/Space activate, m = the item's menu.
    function trayKey(k: int, e: var): bool {
        const n = SystemTray.items.values.length;
        if (k === Qt.Key_Left)
            listSel = Math.max(0, listSel - 1);
        else if (k === Qt.Key_Right)
            listSel = Math.min(n - 1, listSel + 1);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
            trayKeys.press(listSel, false);
        else if (e.text === "m")
            trayKeys.press(listSel, true);
        else
            return false;
        return true;
    }
    Timer {
        id: armTimer
        interval: 3000
        onTriggered: root.powerArmed = -1
    }
    function powerPress(i: int, held: bool): void {
        const a = powerActions[i];
        if (a.confirm && !held && powerArmed !== i) {
            powerArmed = i;
            armTimer.restart();
            return;
        }
        powerArmed = -1;
        show("idle");
        Quickshell.execDetached(a.cmd);
    }

    // --- Polkit ------------------------------------------------------------
    // The island is the session's password agent. Only one agent can register,
    // so no other agent may be started alongside it.
    PolkitAgent {
        id: polkit
        // Face unlock from the open pass page goes through polkit: come back to it after.
        onAuthenticationRequestStarted: {
            root.polkitReturn = root.mode === "pass" ? "pass" : "idle";
            root.show("polkit");
        }
    }
    property string polkitReturn: "idle"
    Connections {
        target: polkit.flow
        function onIsCompletedChanged(): void {
            if (polkit.flow?.isCompleted && root.mode === "polkit")
                root.show(root.polkitReturn);
        }
    }

    // --- Low-battery alerts --------------------------------------------------
    // One notification per threshold per discharge; plugging in re-arms them.
    property int batAlerted: 100
    onBatPctChanged: checkBattery()
    onChargingChanged: checkBattery()
    function checkBattery(): void {
        if (charging || batPct === 0) { // 0 = UPower not ready yet
            batAlerted = 100;
            return;
        }
        for (const [t, urgency, title] of [[20, "critical", "Battery critical"], [30, "normal", "Battery low"]]) {
            if (batPct <= t && batAlerted > t) {
                batAlerted = t;
                Quickshell.execDetached(["notify-send", "-u", urgency, "-a", "Battery", "-i", "battery-caution", title, batPct + "% left, plug in the charger"]);
                return;
            }
        }
    }
    // Charger plug/unplug. Keyed on onBattery, not charging: conservation mode
    // holds the battery at "pending-charge" while plugged in.
    Connections {
        target: UPower
        function onOnBatteryChanged(): void {
            if (root.batPct === 0) // UPower not ready yet (startup)
                return;
            const on = UPower.onBattery;
            Quickshell.execDetached(["notify-send", "-a", "Battery", "-i", on ? "battery" : "battery-charging",
                on ? "Charger disconnected" : "Charger connected", root.batPct + "%"]);
        }
    }

    // --- Idle suspend (battery only) ---------------------------------------
    // 30 min idle on battery -> suspend-then-hibernate. swayidle still locks at
    // 5 min and blanks at 10. Skipped while swayidle is off (Shift+Mute toggle
    // = "suspend disabled") and while anything holds an idle inhibitor (video).
    IdleMonitor {
        timeout: 1800
        respectInhibitors: true
        onIsIdleChanged: if (isIdle && UPower.onBattery)
            Quickshell.execDetached(["sh", "-c", "pgrep -x swayidle >/dev/null && systemctl suspend-then-hibernate"])
    }

    // --- Brightness --------------------------------------------------------
    property real brightness: 0
    Process {
        id: brightRead
        command: ["brightnessctl", "-m"]
        running: true
        // Output: intel_backlight,backlight,123,45%,400
        stdout: StdioCollector {
            onStreamFinished: root.brightness = parseInt(text.split(",")[3]) / 100
        }
    }
    Process {
        id: brightStep
        onExited: brightRead.running = true
    }
    function stepBrightness(dir: string): void {
        brightStep.command = [Quickshell.env("HOME") + "/.dotfiles/scripts/brightness.sh", dir];
        brightStep.running = true;
        flash("brightness");
    }
    function setBrightness(v: real): void {
        brightness = Math.max(0.01, Math.min(1, v));
        Quickshell.execDetached(["brightnessctl", "set", Math.round(brightness * 100) + "%"]);
        flash("brightness");
    }

    // --- Battery -----------------------------------------------------------
    readonly property var bat: UPower.displayDevice
    readonly property int batPct: Math.round((bat?.percentage ?? 0) * 100)
    readonly property bool charging: bat?.state === UPowerDeviceState.Charging || bat?.state === UPowerDeviceState.FullyCharged
    // The display device is an aggregate with no health; read BAT1 for that.
    readonly property var laptopBat: UPower.devices.values.find(d => d.isLaptopBattery) ?? null
    readonly property var peripherals: UPower.devices.values.filter(d => !d.isLaptopBattery && d.type !== UPowerDeviceType.LinePower && d.isPresent)
    // CPU package watts on AC, from rapl-watts.service (system/system); "" when
    // the service is not running. Polled only while the battery page is open.
    property string cpuWatts: ""
    FileView {
        id: raplFile
        path: "/run/rapl-watts"
        printErrors: false
        onLoaded: root.cpuWatts = text().trim()
        onLoadFailed: root.cpuWatts = ""
    }
    Timer {
        interval: 2000
        running: root.mode === "battery"
        repeat: true
        triggeredOnStart: true
        onTriggered: raplFile.reload()
    }

    function duration(s: real): string {
        const m = Math.round(s / 60);
        return Math.floor(m / 60) + "h " + (m % 60) + "m";
    }
    readonly property string batStatus: {
        const st = UPowerDeviceState.toString(bat?.state ?? 0);
        if (bat?.state === UPowerDeviceState.Discharging && bat.timeToEmpty > 0)
            return st + " · " + duration(bat.timeToEmpty) + " left";
        if (bat?.state === UPowerDeviceState.Charging && bat.timeToFull > 0)
            return st + " · " + duration(bat.timeToFull) + " to full";
        return st;
    }

    // --- Wi-Fi -------------------------------------------------------------
    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNet: wifiDev?.networks.values.find(n => n.connected) ?? null
    readonly property var wifiNets: (wifiDev?.networks.values ?? []).slice().sort((a, b) => b.signalStrength - a.signalStrength)
    // Secured network waiting for a password.
    property var wifiPending: null

    function wifiIcon(s: real): string {
        return glyph(s > 0.75 ? 0xF0928 : s > 0.5 ? 0xF0925 : s > 0.25 ? 0xF0922 : 0xF091F);
    }
    function wifiClick(n: var): void {
        wifiPending = null;
        if (n.connected)
            n.disconnect();
        else if (n.known || n.security === WifiSecurityType.Open)
            n.connect();
        else
            wifiPending = n;
    }

    // --- Bluetooth ---------------------------------------------------------
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btDev: Bluetooth.devices.values.find(d => d.connected) ?? null
    // Named or paired devices: connected first, then paired, then by name.
    readonly property var btDevices: Bluetooth.devices.values.filter(d => d.paired || d.deviceName !== "").sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
    // Device being paired; connected as soon as pairing finishes.
    property var btPairing: null

    function btClick(d: var): void {
        if (d.connected) {
            d.disconnect();
        } else if (d.paired) {
            d.connect();
        } else {
            btPairing = d;
            d.trusted = true;
            d.pair();
        }
    }
    function btIcon(d: var): string {
        const i = d.icon;
        if (i.includes("mouse"))
            return glyph(0xF037D);
        if (i.includes("keyboard"))
            return glyph(0xF030C);
        if (i.includes("audio") || i.includes("head"))
            return glyph(0xF02CB);
        if (i.includes("phone"))
            return glyph(0xF011C);
        return glyph(0xF00AF);
    }
    function btSub(d: var): string {
        if (d.connected)
            return "Connected" + (d.batteryAvailable ? " · " + Math.round(d.battery * 100) + "%" : "");
        if (d.state === BluetoothDeviceState.Connecting)
            return "Connecting…";
        if (d.pairing)
            return "Pairing…";
        return d.paired ? "Paired" : "Not paired";
    }

    // --- Notifications -----------------------------------------------------
    // hyprland.lua and niri's startup.kdl stop quickshell-notifications.service
    // before starting the island, so this server owns org.freedesktop.Notifications. History is memory only, newest first, capped at 50.
    // DND hides popups but still records history; critical always shows.
    // A popup that times out is NOT closed: the app's notification stays alive
    // in history (entry.n) so its actions still work; it is closed when the
    // user swipes it, clears history, or it falls off the 50-entry cap.
    property bool dnd: false
    property var popups: [] // live Notification objects, oldest first
    property var history: [] // [{key, n, app, summary, body, time}]; n null once closed
    property int notifSeq: 0
    // Popups always go to the top-right stack, never into the pill.
    readonly property bool notifInIsland: false
    // Players without a track title (e.g. a WhatsApp web tab) are not media.
    readonly property var player: {
        const ps = Mpris.players.values.filter(p => p.trackTitle);
        return ps.find(p => p.isPlaying) ?? ps[0] ?? null;
    }
    NotificationServer {
        keepOnReload: false
        persistenceSupported: false
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        inlineReplySupported: true
        onNotification: n => {
            n.tracked = true;
            // Closed by anyone (app, user, action): drop the card, keep the text.
            n.closed.connect(() => {
                root.popups = root.popups.filter(x => x !== n);
                root.history = root.history.map(h => h.n === n ? Object.assign({}, h, { n: null }) : h);
            });
            const all = [{ key: ++root.notifSeq, n: n, app: n.appName, desktop: n.desktopEntry, summary: n.summary, body: n.body.replace(/<[^>]*>/g, ""), time: new Date() }].concat(root.history);
            root.history = all.slice(0, 50);
            for (const h of all.slice(50))
                h.n?.dismiss();
            if (root.dnd && n.urgency !== NotificationUrgency.Critical)
                return;
            root.popups = root.popups.concat([n]);
        }
    }
    // Called once a card's exit animation has finished. Timed-out cards stay
    // alive for history; swiped ones are closed.
    function dropNotif(n: var, expired: bool): void {
        popups = popups.filter(x => x !== n);
        if (n && !expired)
            n.dismiss();
    }
    function clearHistory(): void {
        const old = history;
        history = [];
        for (const h of old)
            h.n?.dismiss();
    }
    function histActions(n: var): var {
        const out = [];
        if (n)
            for (let i = 0; i < n.actions.length; i++)
                if (n.actions[i].identifier !== "default")
                    out.push(n.actions[i]);
        return out;
    }
    // Run an action from history; the entry goes away like a used popup.
    function invokeHist(h: var, a: var): void {
        const n = h.n;
        if (!n || !a)
            return;
        history = history.filter(x => x.key !== h.key);
        const resident = n.resident;
        a.invoke();
        if (resident)
            n.dismiss();
    }
    // Click on a history entry: default action if the app still offers one,
    // otherwise focus the sender's window (works after the app closed it too).
    function histDefault(h: var): void {
        const n = h.n;
        if (n)
            for (let i = 0; i < n.actions.length; i++)
                if (n.actions[i].identifier === "default")
                    return invokeHist(h, n.actions[i]);
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.dotfiles/scripts/wm.sh", "focus-app", h.desktop ?? "", h.app ?? ""]);
        history = history.filter(x => x.key !== h.key);
        n?.dismiss();
    }
    // Expanded history entry: ✕ removes it (and closes it for the app).
    function dismissHist(h: var): void {
        history = history.filter(x => x.key !== h.key);
        h.n?.dismiss();
    }
    // Inline reply from history (KDE Connect SMS etc.).
    function replyHist(h: var, text: string): void {
        if (!text || !h.n)
            return;
        const n = h.n;
        history = history.filter(x => x.key !== h.key);
        n.sendInlineReply(text);
        island.forceActiveFocus(); // the reply field went away with its entry
    }

    // --- Night mode --------------------------------------------------------
    // A running hyprsunset (4000K); read when the dashboard opens or the tile is clicked.
    property bool night: false
    Process {
        id: nightRead
        command: ["pgrep", "-x", "hyprsunset"]
        onExited: code => root.night = code === 0
    }
    Process {
        id: ipcToggle
        onExited: nightRead.running = true
    }
    function runToggle(cmd: var): void {
        ipcToggle.command = cmd;
        ipcToggle.running = true;
    }
    // pkill returns before hyprsunset exits; wait it out so the pgrep re-read
    // sees the new state.
    function toggleNight(): void {
        runToggle(["sh", "-c", "if pkill -x hyprsunset; then for i in $(seq 20); do pgrep -x hyprsunset >/dev/null || break; sleep 0.1; done; else setsid -f hyprsunset -t 4000 >/dev/null 2>&1; sleep 0.2; fi"]);
    }

    // Dashboard switches without a picker page, offered by Spotlight (Wi-Fi,
    // Bluetooth and sound open their pages there instead). keys: extra search words.
    readonly property var systemToggles: [
        { title: "Do not disturb", keys: "dnd notifications", on: dnd, icon: 0xF009A, act: () => dnd = !dnd },
        { title: "Night mode", keys: "night light hyprsunset warm", on: night, icon: 0xF0594, act: () => toggleNight() }
    ]

    onModeChanged: {
        if (mode === "spotlight")
            nightRead.running = true;
        if (mode === "dashboard") {
            nightRead.running = true;
            brightRead.running = true;
        }
        if (mode !== "wifi")
            wifiPending = null;
        // Scan only while a picker is open.
        if (wifiDev && wifiDev.scannerEnabled !== (mode === "wifi"))
            wifiDev.scannerEnabled = mode === "wifi";
        if (btAdapter?.enabled && btAdapter.discovering !== (mode === "bluetooth"))
            btAdapter.discovering = mode === "bluetooth";
        island.forceActiveFocus();
    }

    IpcHandler {
        target: "island"

        function toggle(m: string): void {
            root.show(root.mode === m ? "idle" : m);
        }
        function open(m: string): void {
            root.show(m);
        }
        // Mod+Shift+P via scripts/quickshell/pass.sh, which captures the focused
        // browser's domain first.
        function pass(domain: string): void {
            passPage.prefill = domain;
            root.show("pass");
        }
        function idle(): void {
            root.show("idle");
        }
        function toggleAutoHide(): void {
            root.autoHide = !root.autoHide;
        }
        function volume(arg: string): void {
            if (arg === "mute") {
                if (root.sink?.audio)
                    root.sink.audio.muted = !root.muted;
                return;
            }
            if (arg === "micmute") {
                if (root.source?.audio)
                    root.source.audio.muted = !root.source.audio.muted;
                return;
            }
            root.setVolume(root.volume + parseFloat(arg) / 100);
        }
        function brightness(arg: string): void {
            root.stepBrightness(arg);
        }
        function getWallpaper(): string {
            return root.wallpaper;
        }
        function setWallpaper(path: string): void {
            root.setWallpaper(path);
        }
    }

    // --- Wallpaper ---------------------------------------------------------
    // One fixed image (no shuffle). Path lives in ~/.local/state/island/wallpaper;
    // the wallpaper page sets it, lock.sh reads it over IPC (getWallpaper).
    property string wallpaper: ""
    // Black veil over bright wallpapers so text in transparent terminals stays
    // readable. From the mean grey and the share of near-white pixels (stars,
    // sky); 0 for dark images, capped at 0.55.
    property real wallDim: 0
    onWallpaperChanged: {
        wallDim = 0;
        if (wallpaper)
            wallLum.running = true;
    }
    Process {
        id: wallLum
        command: ["magick", root.wallpaper, "-colorspace", "Gray", "-resize", "200x200", "(", "+clone", "-threshold", "65%", ")", "-format", "%[fx:mean]\n", "info:"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [mean, bright] = text.trim().split("\n").map(Number);
                if (!isNaN(mean) && !isNaN(bright))
                    root.wallDim = Math.min(0.55, Math.max(0, mean - 0.25) * 1.2 + bright * 1.5);
            }
        }
    }
    function setWallpaper(path: string): void {
        wpFile.setText(path);
        root.wallpaper = path;
    }
    // Top level of ~/Pictures only.
    FolderListModel {
        id: wpFiles
        folder: "file://" + Quickshell.env("HOME") + "/Pictures"
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
        showDirs: false
        sortField: FolderListModel.Name
    }
    FileView {
        id: wpFile
        path: Quickshell.env("HOME") + "/.local/state/island/wallpaper"
        onLoaded: root.wallpaper = text().trim()
    }

    // --- Building blocks ---------------------------------------------------
    // Inline components cannot see `root`, so they take everything as props.
    // T (text), Page and SearchList live in their own files in this folder.

    // macOS Control Center block: soft translucent rounded panel.
    component Module: Rectangle {
        radius: 14
        color: Qt.alpha(Colors.fg, 0.07)
        border.width: 1
        border.color: Qt.alpha(Colors.fg, 0.06)
    }

    // macOS Control Center slider: thick rounded track with the fill and an
    // optional icon inside it. Emits moved(0..1) on press and drag; a click on
    // the icon emits iconClicked instead (mute).
    component Bar: Item {
        id: bar
        property real value
        property string icon
        signal moved(real v)
        signal iconClicked
        implicitWidth: 220
        implicitHeight: 26
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.alpha(Colors.fg, 0.14)
            clip: true

            // Never narrower than the icon's circle, so the icon always sits on the fill.
            Rectangle {
                width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, bar.value)))
                height: parent.height
                radius: parent.radius
                color: Colors.accent
            }
        }
        MouseArea {
            anchors.fill: parent
            function set(x: real): void {
                bar.moved(Math.max(0, Math.min(1, x / width)));
            }
            onPressed: m => set(m.x)
            onPositionChanged: m => set(m.x)
        }
        T {
            visible: bar.icon !== ""
            width: bar.height
            horizontalAlignment: Text.AlignHCenter
            text: bar.icon
            color: Colors.base
            MouseArea {
                anchors.fill: parent
                onClicked: bar.iconClicked()
            }
        }
    }

    // Quick-settings tile, macOS Control Center style: neutral block with a
    // round icon that turns accent when on. The icon toggles; the body opens
    // the picker when there is one (chevron shown), else it toggles too.
    component Tile: Module {
        id: tile
        property string icon
        property string title
        property string sub
        property bool on
        property bool hasPage
        property bool sel // keyboard focus ring
        signal toggled
        signal opened
        width: 220
        height: 56
        border.width: sel ? 2 : 1
        border.color: sel ? Colors.accent : Qt.alpha(Colors.fg, 0.06)

        StateLayer {
            onClicked: tile.hasPage ? tile.opened() : tile.toggled()
        }
        Row {
            x: Tokens.padding.small + 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small + 2
            Rectangle {
                width: 32
                height: 32
                radius: 16
                anchors.verticalCenter: parent.verticalCenter
                color: tile.on ? Colors.accent : Qt.alpha(Colors.fg, 0.14)
                Behavior on color {
                    CAnim {}
                }
                T {
                    anchors.centerIn: parent
                    text: tile.icon
                    font.pixelSize: Tokens.fontSize.larger
                    color: tile.on ? Colors.base : Colors.fg
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: tile.toggled()
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                T {
                    anchors.verticalCenter: undefined
                    text: tile.title
                    width: 136
                    elide: Text.ElideRight
                    font.weight: Font.DemiBold
                }
                T {
                    anchors.verticalCenter: undefined
                    text: tile.sub
                    width: 136
                    elide: Text.ElideRight
                    font.pixelSize: Tokens.fontSize.small
                    color: Colors.subtext0
                }
            }
        }
        T {
            visible: tile.hasPage
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.small
            text: String.fromCodePoint(0xF0142)
            color: Colors.subtext0
        }
    }

    // Small rounded button on history entries (actions, ✕, Copy).
    component HistChip: Rectangle {
        id: chip
        property string label
        signal clicked
        width: chipLabel.implicitWidth + Tokens.padding.medium * 2
        height: chipLabel.implicitHeight + Tokens.padding.small
        radius: height / 2
        color: Colors.surface2
        T {
            id: chipLabel
            anchors.centerIn: parent
            text: chip.label
            font.pixelSize: Tokens.fontSize.smaller
        }
        MouseArea {
            anchors.fill: parent
            onClicked: chip.clicked()
        }
    }

    // Battery stat card: icon, value, label.
    component Stat: Rectangle {
        id: stat
        property string icon
        property string value
        property string label
        width: 140
        height: 72
        radius: Tokens.rounding.large
        color: Colors.surface0
        Column {
            anchors.centerIn: parent
            spacing: 2
            T {
                anchors.verticalCenter: undefined
                anchors.horizontalCenter: parent.horizontalCenter
                text: stat.icon
                color: Colors.accent
                font.pixelSize: Tokens.fontSize.large
            }
            T {
                anchors.verticalCenter: undefined
                anchors.horizontalCenter: parent.horizontalCenter
                text: stat.value
                font.bold: true
            }
            T {
                anchors.verticalCenter: undefined
                anchors.horizontalCenter: parent.horizontalCenter
                text: stat.label
                color: Colors.subtext0
                font.pixelSize: Tokens.fontSize.smaller
            }
        }
    }

    // Picker header: back chevron, title, optional scan button and on/off switch.
    component Header: Item {
        id: hdr
        property string title
        property bool hasToggle
        property bool on
        property bool hasScan
        property bool scanning
        signal back
        signal toggled
        signal scan
        implicitWidth: 448
        implicitHeight: 32

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small
            T {
                text: String.fromCodePoint(0xF0141)
                font.pixelSize: Tokens.fontSize.large
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: hdr.back()
                }
            }
            T {
                text: hdr.title
                font.bold: true
                font.pixelSize: Tokens.fontSize.larger
            }
        }
        // Filled while scanning; click to start or stop.
        Rectangle {
            visible: hdr.hasScan && hdr.on
            anchors.right: parent.right
            anchors.rightMargin: hdr.hasToggle ? 52 : 0
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            radius: 14
            color: hdr.scanning ? Colors.accent : Colors.surface1
            T {
                anchors.centerIn: parent
                text: String.fromCodePoint(0xF0450)
                color: hdr.scanning ? Colors.base : Colors.fg
            }
            MouseArea {
                anchors.fill: parent
                onClicked: hdr.scan()
            }
        }
        Rectangle {
            visible: hdr.hasToggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            // macOS switch: accent track when on, white knob either way.
            width: 40
            height: 24
            radius: 12
            color: hdr.on ? Colors.accent : Qt.alpha(Colors.fg, 0.2)
            Behavior on color {
                CAnim {}
            }
            Rectangle {
                x: hdr.on ? 18 : 2
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: 10
                color: Colors.text
                Behavior on x {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: hdr.toggled()
            }
        }
    }

    // Scrolling list, capped so long device lists do not grow the island.
    component Scroll: Flickable {
        default property alias items: col.data
        width: 448
        height: Math.min(col.implicitHeight, 264)
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            width: parent.width
            spacing: 2
        }
        // Keep a keyboard-selected row in view.
        function reveal(it: Item): void {
            if (!it)
                return;
            if (it.y < contentY)
                contentY = it.y;
            else if (it.y + it.height > contentY + height)
                contentY = it.y + it.height - height;
        }
    }

    // List row. `action` is an optional trailing icon button (forget) that
    // needs two clicks within 3 s: the first arms it, the second fires.
    component ListRow: Rectangle {
        id: row
        property string icon
        property string title
        property string sub
        property bool active
        property string action
        property bool armed
        property bool sel // keyboard focus ring
        signal clicked
        signal actionClicked
        width: 448
        height: 44
        radius: Tokens.rounding.medium
        color: active ? Colors.surface2 : sel || hover.containsMouse ? Colors.surface1 : "transparent"
        border.width: sel ? 1.5 : 0
        border.color: Colors.accent
        // First call arms, a second within 3 s fires (mouse and the d key).
        function forget(): void {
            if (armed) {
                armed = false;
                disarm.stop();
                actionClicked();
            } else {
                armed = true;
                disarm.restart();
            }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: row.clicked()
        }
        Row {
            x: Tokens.padding.medium
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.medium
            T {
                text: row.icon
                width: 20
                font.pixelSize: Tokens.fontSize.larger
                color: row.active ? Colors.accent : Colors.fg
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                T {
                    anchors.verticalCenter: undefined
                    text: row.title
                    width: row.action ? 340 : 380
                    elide: Text.ElideRight
                    font.bold: row.active
                }
                T {
                    anchors.verticalCenter: undefined
                    visible: row.armed || row.sub !== ""
                    text: row.armed ? (row.sel ? "Press d again to forget" : "Click again to forget") : row.sub
                    font.pixelSize: Tokens.fontSize.smaller
                    color: row.armed ? Colors.red : Colors.subtext0
                }
            }
        }
        Timer {
            id: disarm
            interval: 3000
            onTriggered: row.armed = false
        }
        Rectangle {
            visible: row.action !== ""
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.small
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 16
            color: row.armed ? Colors.red : act.containsMouse ? Colors.surface2 : "transparent"
            T {
                anchors.centerIn: parent
                text: row.action
                color: row.armed ? Colors.base : Colors.subtext0
            }
            MouseArea {
                id: act
                anchors.fill: parent
                hoverEnabled: true
                onClicked: row.forget()
            }
        }
    }

    // Output/input picker: volume for the current device, list to switch.
    component AudioPage: Page {
        id: ap
        property string title
        property string icon
        property var nodes: []
        property var current: null
        property bool ring // keyboard focus ring shown
        property int sel: 0
        signal back
        signal pick(var node)
        onOpened: sel = Math.max(0, nodes.indexOf(current))
        // h/l volume, m mute, j/k/g/G pick a device, Enter/Space switch to it.
        function key(k: int, e: var): bool {
            const a = current?.audio;
            if ((k === Qt.Key_Left || k === Qt.Key_Right) && a) {
                a.muted = false;
                a.volume = Math.max(0, Math.min(1, a.volume + (k === Qt.Key_Right ? 0.05 : -0.05)));
            } else if (e.text === "m" && a)
                a.muted = !a.muted;
            else if (k === Qt.Key_Down)
                sel = Math.min(nodes.length - 1, sel + 1);
            else if (k === Qt.Key_Up)
                sel = Math.max(0, sel - 1);
            else if (k === Qt.Key_Home)
                sel = 0;
            else if (k === Qt.Key_End)
                sel = nodes.length - 1;
            else if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) && nodes[sel])
                pick(nodes[sel]);
            else
                return false;
            apScroll.reveal(apRep.itemAt(sel));
            return true;
        }

        Column {
            spacing: Tokens.spacing.medium
            Header {
                title: ap.title
                onBack: ap.back()
            }
            Row {
                spacing: Tokens.spacing.medium
                T {
                    text: ap.icon
                    width: 24
                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (ap.current?.audio) ap.current.audio.muted = !ap.current.audio.muted
                    }
                }
                Bar {
                    width: 360
                    value: ap.current?.audio?.volume ?? 0
                    onMoved: v => {
                        if (!ap.current?.audio)
                            return;
                        ap.current.audio.muted = false;
                        ap.current.audio.volume = v;
                    }
                }
                T {
                    text: Math.round((ap.current?.audio?.volume ?? 0) * 100) + "%"
                    width: 40
                }
            }
            Scroll {
                id: apScroll
                Repeater {
                    id: apRep
                    model: ap.nodes
                    delegate: ListRow {
                        required property var modelData
                        required property int index
                        sel: ap.ring && index === ap.sel
                        active: modelData === ap.current
                        icon: active ? String.fromCodePoint(0xF012C) : ""
                        title: modelData.description || modelData.nickname || modelData.name
                        onClicked: ap.pick(modelData)
                    }
                }
            }
        }
    }

    component Tray: Row {
        id: tray
        property int sel: -1 // keyboard focus ring, -1 = none
        spacing: Tokens.spacing.small
        // Left click / Enter activates; right click / m opens the item's menu.
        function press(i: int, menu: bool): void {
            const it = trayRep.itemAt(i);
            if (!it)
                return;
            const item = it.modelData;
            if (!menu && !item.onlyMenu) {
                item.activate();
            } else if (item.hasMenu) {
                const p = it.mapToItem(null, 0, 0);
                item.display(QsWindow.window, p.x, p.y);
            }
        }

        T {
            visible: SystemTray.items.values.length === 0
            text: "No tray items"
            color: Colors.subtext
        }
        Repeater {
            id: trayRep
            model: SystemTray.items
            delegate: Image {
                id: icon
                required property SystemTrayItem modelData
                required property int index
                width: 20
                height: 20
                sourceSize: Qt.size(20, 20)
                source: modelData.icon

                Rectangle {
                    visible: tray.sel === icon.index
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: 6
                    color: "transparent"
                    border.width: 1.5
                    border.color: Colors.accent
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: m => tray.press(icon.index, m.button !== Qt.LeftButton)
                }
            }
        }
    }

    // --- Windows -----------------------------------------------------------
    // Wallpaper, one per screen. Bottom layer, below every window.
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            exclusionMode: ExclusionMode.Ignore
            color: Colors.crust
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "island-wallpaper"
            mask: Region {}
            Image {
                anchors.fill: parent
                source: root.wallpaper ? "file://" + root.wallpaper : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(parent.width, parent.height)
            }
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: root.wallDim
                Behavior on opacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }
            }
        }
    }

    // Invisible strip that only reserves space at the top for the pill.
    // The island window itself is fullscreen and ignores exclusion.
    PanelWindow {
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 1
        exclusiveZone: root.autoHide ? 0 : 34
        color: "transparent"
        WlrLayershell.namespace: "island-spacer"
        mask: Region {}
    }

    // --- Scroll edges (Hyprland scrolling layout) ---------------------------
    // A thin accent glow on a screen's left/right edge while tiled windows of its
    // active workspace extend past that edge (columns scrolled off-screen).
    // Recomputed 80ms after any Hyprland event that can move windows; under
    // niri hyprctl fails and nothing shows. Focus events stay in: focusing a
    // column scrolls the layout. Title/layer/etc. events can't move a window
    // and fire constantly (terminal titles), so they're skipped.
    readonly property var edgeQuietEvents: ["windowtitle", "windowtitlev2", "activelayout", "submap", "urgent",
        "openlayer", "closelayer", "screencast", "bell", "configreloaded", "ignoregrouplock", "lockgroups"]
    property var scrollEdges: ({}) // monitor name -> {left, right}
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (!root.edgeQuietEvents.includes(event.name)) edgeDebounce.restart(); }
    }
    Timer {
        id: edgeDebounce
        interval: 80
        running: true
        onTriggered: edgeQuery.running = true
    }
    Process {
        id: edgeQuery
        command: ["sh", "-c", "jq -cn --argjson m \"$(hyprctl -j monitors)\" --argjson c \"$(hyprctl -j clients)\" '"
            + "[$m[] as $o | ($c | map(select(.workspace.id == $o.activeWorkspace.id and (.floating | not)))) as $w"
            + " | {key: $o.name, value: {left: any($w[]; .at[0] < $o.x),"
            + " right: any($w[]; .at[0] + .size[0] > $o.x + $o.width / $o.scale)}}] | from_entries'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.scrollEdges = JSON.parse(text); } catch (e) { root.scrollEdges = {}; }
            }
        }
    }
    Variants {
        model: Array.from(Quickshell.screens).reduce((a, s) => a.concat([{ screen: s, side: "left" }, { screen: s, side: "right" }]), [])
        PanelWindow {
            id: scrollEdge
            required property var modelData
            readonly property bool lit: root.scrollEdges[modelData.screen.name]?.[modelData.side] ?? false
            screen: modelData.screen
            anchors.top: true
            anchors.bottom: true
            anchors.left: modelData.side === "left"
            anchors.right: modelData.side === "right"
            implicitWidth: 3
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "island-scroll-edge"
            mask: Region {}
            Rectangle {
                anchors.fill: parent
                opacity: scrollEdge.lit ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                // Brightest at mid-height, fading out towards the corners.
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.darker(Colors.accent, 1.6) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    // Auto-hide reveal trigger: full-width 2px strip on the top edge, on the
    // Overlay layer so nothing above it can take the pointer.
    PanelWindow {
        visible: root.autoHide
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 2
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "island-edge"

        Item {
            anchors.fill: parent
            HoverHandler {
                onHoveredChanged: root.edgeHovered = hovered
            }
        }
    }

    // Popups stack at the top-right edge, out of the way of the island.
    PanelWindow {
        visible: !root.notifInIsland && root.popups.length > 0
        anchors.top: true
        anchors.right: true
        // Full height with input masked to the cards: resizing the layer surface
        // every frame while a card collapses made the stack's bottom jitter.
        anchors.bottom: true
        mask: Region {
            item: notifStack
        }
        // No top margin: the window starts at the screen edge; the gap is the
        // Column's topPadding instead.
        margins.right: Tokens.padding.medium
        implicitWidth: 440
        color: "transparent"
        // Ignore the island's 34px reserved strip so the stack starts at the screen edge.
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "island-notifications"
        // OnDemand only while hovered: Hyprland focuses an OnDemand layer when it
        // maps, so an always-OnDemand stack steals focus on every new popup.
        // ponytail: moving the mouse off the card mid-reply drops the keyboard.
        WlrLayershell.keyboardFocus: stackHover.hovered ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        Column {
            id: notifStack
            width: parent.width
            HoverHandler {
                id: stackHover
            }
            topPadding: Tokens.padding.medium
            // No spacing or move transition: each slot carries its own gap, which
            // collapses with the card, so the cards below glide up in one motion.
            Repeater {
                model: ScriptModel {
                    values: root.notifInIsland ? [] : root.popups
                }
                Item {
                    id: slot
                    required property var modelData
                    width: 440
                    height: card.implicitHeight + card.gap
                    NotifCard {
                        id: card
                        modelData: slot.modelData
                        implicitWidth: 440
                        gap: Tokens.spacing.medium
                        onDismissed: root.dropNotif(modelData, expired)
                    }
                }
            }
        }
    }

    PanelWindow {
        id: win

        // Fullscreen so a click anywhere outside the pill can close it. The mask
        // limits input to the pill unless something is expanded, so normally
        // clicks fall through to the windows below.
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "island"
        // A notification in the pill may carry an inline reply field: OnDemand
        // lets a click on it take the keyboard without grabbing it otherwise.
        WlrLayershell.keyboardFocus: root.expanded ? WlrKeyboardFocus.Exclusive
            : root.notifInIsland && root.pillHovered ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        mask: Region {
            item: root.expanded ? catcher : island
        }

        MouseArea {
            id: catcher
            anchors.fill: parent
            onClicked: root.show("idle")
        }

        // Soft drop shadow; a sibling because the pill clips its children.
        RectangularShadow {
            visible: !root.islandBare
            anchors.fill: island
            radius: island.radius
            offset.y: 6
            blur: 24
            spread: -2
            color: Colors.shadow
        }

        Rectangle {
            id: island

            readonly property Item page: root.notifInIsland ? notifPage : ({
                    hub: hubPage,
                    idle: idlePage,
                    volume: osdPage,
                    brightness: osdPage,
                    dashboard: dashPage,
                    tray: trayPage,
                    battery: batPage,
                    wifi: wifiPage,
                    bluetooth: btPage,
                    output: outPage,
                    input: inPage,
                    spotlight: spotlightPage,
                    power: powerPage,
                    polkit: polkitPage,
                    clipboard: clipPage,
                    wallpaper: wallPage,
                    theme: themePage,
                    browser: browserPage,
                    switcher: switcherPage,
                    calendar: calendarPage,
                    pass: passPage,
                    keybindings: keybindsPage,
                    tools: toolsPage
                })[root.mode]

            anchors.top: parent.top
            anchors.topMargin: root.tucked ? 4 - height : 0
            anchors.horizontalCenter: parent.horizontalCenter

            Behavior on anchors.topMargin {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            HoverHandler {
                onHoveredChanged: root.pillHovered = hovered
            }
            // Open pages get a wider margin so content clears the 28px corners.
            width: page.implicitWidth + (root.islandBare ? 0 : root.expanded ? Tokens.padding.largeIncreased : Tokens.padding.large) * 2
            height: page.implicitHeight + (root.islandBare ? 0 : root.expanded ? Tokens.padding.large : Tokens.padding.small) * 2
            radius: Math.min(height / 2, Tokens.rounding.extraLarge)
            color: root.islandBare ? "transparent" : Colors.bg
            border.color: root.islandBare ? "transparent" : Colors.outline
            clip: true
            focus: true

            Keys.onEscapePressed: root.show(root.subPages.includes(root.mode) ? "dashboard" : "idle")
            Keys.onPressed: e => e.accepted = root.pageKey(e)

            Behavior on width {
                Anim {
                    type: Anim.FastSpatial
                }
            }
            Behavior on height {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            // Left click on the pill (the clock; dots and battery have their own)
            // opens the dashboard, right click the hub (notifications); inside open
            // pages it keeps clicks from the catcher behind.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: e => {
                    if (!root.expanded)
                        root.show(e.button === Qt.RightButton ? "hub" : "dashboard");
                }
            }

            Page {
                id: idlePage
                active: island.page === idlePage

                Row {
                    spacing: Tokens.spacing.medium

                    // Workspace dots: focused one is accent-coloured.
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        Repeater {
                            model: ScriptModel {
                                values: Hyprland.workspaces.values.filter(w => w.id > 0).sort((a, b) => a.id - b.id)
                            }
                            Rectangle {
                                required property var modelData
                                readonly property bool cur: modelData.id === Hyprland.focusedWorkspace?.id
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 3.5
                                color: cur ? Colors.accent : Colors.overlay1
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + parent.modelData.id + " })")
                                }
                            }
                        }
                    }

                    // Scratchpad (Mod+grave): square while it holds windows;
                    // accent when shown over the workspace, dim when hidden.
                    Rectangle {
                        id: scratchDot
                        readonly property var ws: Hyprland.workspaces.values.find(w => w.name === "special:scratch") ?? null
                        // shortcut: starts false until the next toggle if the island restarts while it is shown.
                        property bool shown: false
                        visible: (ws?.toplevels.values.length ?? 0) > 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: 1.5
                        color: shown ? Colors.accent : "transparent"
                        border.width: 1.5
                        border.color: shown ? Colors.accent : Colors.overlay1
                        Connections {
                            target: Hyprland
                            // data: "special:scratch,eDP-1" when shown, ",eDP-1" when hidden
                            function onRawEvent(ev) {
                                if (ev.name === "activespecial")
                                    scratchDot.shown = ev.data.startsWith("special:scratch,");
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -3
                            onClicked: Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"scratch\")")
                        }
                    }

                    // Running timer / stopwatch from the toolbox; click opens it.
                    T {
                        visible: toolsPage.pillText !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: toolsPage.pillText
                        color: Colors.accent
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -3
                            onClicked: {
                                toolsPage.startView = toolsPage.pillView;
                                root.show("tools");
                            }
                        }
                    }

                    T {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(clock.date, "h:mm AP")
                        font.bold: true
                    }

                    // Horizontal battery: outline, fill by charge, nub on the right.
                    Item {
                        id: batIcon
                        // 80% is the charge cap, so treat it as full.
                        readonly property real level: Math.min(1, root.batPct / 80)
                        // red -> yellow -> green as level goes 0 -> 0.5 -> 1
                        readonly property color tint: {
                            const lo = level < 0.5;
                            const a = lo ? Colors.red : Colors.yellow;
                            const b = lo ? Colors.yellow : Colors.green;
                            const t = lo ? level * 2 : level * 2 - 1;
                            return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
                        }
                        anchors.verticalCenter: parent.verticalCenter
                        width: batRow.width
                        height: batRow.height
                    Row {
                        id: batRow
                        spacing: 4
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            // Solid body: dim track for the empty part, fill flush to the edges.
                            Rectangle {
                                width: 22
                                height: 11
                                radius: 3
                                color: Qt.rgba(batIcon.tint.r, batIcon.tint.g, batIcon.tint.b, 0.3)
                                Rectangle {
                                    height: parent.height
                                    width: Math.max(parent.radius * 2, parent.width * batIcon.level)
                                    radius: parent.radius
                                    color: batIcon.tint
                                }
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2
                                height: 5
                                radius: 1
                                color: batIcon.tint
                            }
                        }
                        T {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.bat?.state === UPowerDeviceState.Charging
                            text: root.glyph(0xF140B)
                            color: batIcon.tint
                        }
                        T {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.batPct + "%"
                        }
                    }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.show("battery")
                        }
                    }
                }
            }

            // A single live notification, drawn inside the pill.
            Page {
                id: notifPage
                active: island.page === notifPage

                Item {
                    width: 430
                    height: islandCard.implicitHeight
                    clip: true // the card slides in from the right
                    Column {
                        id: islandCard
                        width: 430
                        Repeater {
                            model: ScriptModel {
                                values: root.notifInIsland ? root.popups : []
                            }
                            NotifCard {
                                implicitWidth: 430
                                border.color: critical ? Colors.red : "transparent"
                                onDismissed: root.dropNotif(modelData, expired)
                            }
                        }
                    }
                }
            }

            // Hub: media player (if any) above notification history.
            Page {
                id: hubPage
                active: island.page === hubPage

                Column {
                    width: 448
                    spacing: Tokens.spacing.small
                    topPadding: Tokens.padding.small
                    bottomPadding: Tokens.padding.small

                    Rectangle {
                        visible: root.player !== null
                        width: 448
                        height: 72
                        radius: Tokens.rounding.large
                        color: Colors.surface0
                        Image {
                            id: art
                            x: Tokens.padding.small
                            anchors.verticalCenter: parent.verticalCenter
                            width: 56
                            height: 56
                            source: root.player?.trackArtUrl ?? ""
                            sourceSize: Qt.size(112, 112)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Column {
                            x: art.x + art.width + Tokens.spacing.medium
                            anchors.verticalCenter: parent.verticalCenter
                            width: 448 - x - 120
                            T {
                                anchors.verticalCenter: undefined
                                width: parent.width
                                elide: Text.ElideRight
                                font.bold: true
                                text: root.player?.trackTitle || root.player?.identity || ""
                            }
                            T {
                                anchors.verticalCenter: undefined
                                width: parent.width
                                elide: Text.ElideRight
                                color: Colors.subtext0
                                font.pixelSize: Tokens.fontSize.smaller
                                text: root.player?.trackArtist ?? ""
                            }
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: Tokens.padding.medium
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.spacing.medium
                            T {
                                text: root.glyph(0xF04AE)
                                font.pixelSize: Tokens.fontSize.larger
                                opacity: root.player?.canGoPrevious ? 1 : 0.4
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    onClicked: root.player?.previous()
                                }
                            }
                            T {
                                text: root.glyph(root.player?.isPlaying ? 0xF03E4 : 0xF040A)
                                font.pixelSize: Tokens.fontSize.larger
                                color: Colors.accent
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    onClicked: root.player?.togglePlaying()
                                }
                            }
                            T {
                                text: root.glyph(0xF04AD)
                                font.pixelSize: Tokens.fontSize.larger
                                opacity: root.player?.canGoNext ? 1 : 0.4
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    onClicked: root.player?.next()
                                }
                            }
                        }
                    }

                    Item {
                        width: 448
                        height: 24
                        T {
                            text: "Notifications"
                            font.bold: true
                        }
                        T {
                            anchors.right: parent.right
                            visible: root.history.length > 0
                            text: "Clear"
                            color: Colors.accent
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                onClicked: root.clearHistory()
                            }
                        }
                    }

                    Scroll {
                        id: hubScroll
                        visible: root.history.length > 0
                        Repeater {
                            id: hubRep
                            model: root.history
                            Rectangle {
                                id: hrow
                                required property var modelData
                                required property int index
                                readonly property bool sel: root.kbNav && index === root.listSel
                                property bool open: false
                                function copy(): void {
                                    copyChip.clicked();
                                }
                                function reply(): void {
                                    open = true;
                                    Qt.callLater(() => { if (histReply.visible) histReply.forceActiveFocus(); });
                                }
                                width: 448
                                height: hcol.implicitHeight + Tokens.padding.small * 2
                                radius: Tokens.rounding.medium
                                color: open ? Colors.surface1 : Colors.surface0
                                border.width: sel ? 1.5 : 0
                                border.color: Colors.accent
                                // Click = default action, else focus the sender's window.
                                // Right click = show the full text.
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: e => {
                                        if (e.button === Qt.RightButton) {
                                            hrow.open = !hrow.open;
                                            // Ready to type straight away, like the popup card.
                                            if (hrow.open)
                                                Qt.callLater(() => { if (histReply.visible) histReply.forceActiveFocus(); });
                                        } else
                                            root.histDefault(hrow.modelData);
                                    }
                                }
                                Column {
                                    id: hcol
                                    x: Tokens.padding.medium
                                    y: Tokens.padding.small
                                    width: parent.width - Tokens.padding.medium * 2
                                    T {
                                        anchors.verticalCenter: undefined
                                        width: parent.width
                                        elide: Text.ElideRight
                                        font.pixelSize: Tokens.fontSize.smaller
                                        color: Colors.subtext0
                                        text: (modelData.app || "?") + " · " + Qt.formatTime(modelData.time, "h:mm AP")
                                    }
                                    T {
                                        anchors.verticalCenter: undefined
                                        width: parent.width
                                        elide: Text.ElideRight
                                        wrapMode: hrow.open ? Text.Wrap : Text.NoWrap
                                        font.bold: true
                                        text: modelData.summary
                                    }
                                    T {
                                        anchors.verticalCenter: undefined
                                        visible: text !== ""
                                        width: parent.width
                                        wrapMode: Text.Wrap
                                        maximumLineCount: hrow.open ? 1000 : 2
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
                                        color: Colors.subtext0
                                        text: modelData.body
                                    }
                                    Flow {
                                        width: parent.width
                                        spacing: Tokens.spacing.small
                                        topPadding: visible ? Tokens.spacing.small : 0
                                        visible: chips.count > 0 || hrow.open
                                        // Expanded: ✕ first, like the popup card.
                                        HistChip {
                                            visible: hrow.open
                                            label: "✕"
                                            onClicked: root.dismissHist(hrow.modelData)
                                        }
                                        Repeater {
                                            id: chips
                                            model: root.histActions(hrow.modelData.n)
                                            HistChip {
                                                required property var modelData
                                                required property int index
                                                // Number = its key while the row has the keyboard.
                                                label: (hrow.sel && index < 9 ? (index + 1) + "  " : "") + modelData.text
                                                onClicked: root.invokeHist(hrow.modelData, modelData)
                                            }
                                        }
                                        HistChip {
                                            id: copyChip
                                            visible: hrow.open
                                            label: copyTimer.running ? "Copied" : "Copy"
                                            onClicked: {
                                                Quickshell.clipboardText = hrow.modelData.body;
                                                copyTimer.restart();
                                            }
                                            Timer {
                                                id: copyTimer
                                                interval: 2000
                                            }
                                        }
                                    }
                                    Item {
                                        width: parent.width
                                        height: visible ? 34 + Tokens.spacing.small : 0
                                        visible: hrow.open && (hrow.modelData.n?.hasInlineReply ?? false)
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: 34
                                            radius: Tokens.rounding.small
                                            color: Colors.inputBg
                                            StyledTextField {
                                                id: histReply
                                                anchors.fill: parent
                                                font.family: "JetBrainsMono Nerd Font"
                                                placeholderText: hrow.modelData.n?.inlineReplyPlaceholder || "Reply…"
                                                Keys.onEscapePressed: island.forceActiveFocus()
                                                onAccepted: root.replyHist(hrow.modelData, text)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    T {
                        anchors.verticalCenter: undefined
                        visible: root.history.length === 0
                        text: "No notifications"
                        color: Colors.subtext0
                    }
                }
            }

            Page {
                id: osdPage
                active: island.page === osdPage
                readonly property bool isVol: root.osdKind === "volume"
                readonly property real value: isVol ? root.volume : root.brightness

                Row {
                    spacing: Tokens.spacing.medium
                    T {
                        text: root.glyph(osdPage.isVol ? (root.muted ? 0xF075F : 0xF057E) : 0xF00E0)
                        font.pixelSize: Tokens.fontSize.larger
                    }
                    Bar {
                        implicitHeight: 8 // thin in the pill, like the macOS HUD
                        value: osdPage.value
                        onMoved: v => osdPage.isVol ? root.setVolume(v) : root.setBrightness(v)
                    }
                    T {
                        text: Math.round(osdPage.value * 100) + "%"
                        width: 40
                    }
                }
            }

            SpotlightPage {
                id: spotlightPage
                active: island.page === spotlightPage
                apps: root.apps
                powerActions: root.powerActions
                toggles: root.systemToggles
                onOpenTool: v => {
                    toolsPage.startView = v;
                    root.show("tools");
                }
                onLaunchApp: file => root.launchApp(file)
                onRunPower: i => root.powerPress(i, true)
                onOpenMode: m => root.show(m)
                onCloseRequested: root.show("idle")
            }

            Page {
                id: clipPage
                active: island.page === clipPage

                SearchList {
                    id: clipSearch
                    glyph: root.glyph(0xF0147)
                    placeholder: "Search clipboard…"
                    countText: "Shift+Del deletes · " + model.length
                    maxRows: 7
                    model: {
                        const q = text.toLowerCase();
                        return root.clips.filter(c => q === "" || c.text.toLowerCase().includes(q)).map(c => {
                            const file = c.text.startsWith("file://");
                            return {
                                title: c.image ? "Image" : file ? c.text.replace(/^file:\/\//, "") : c.text,
                                sub: c.image ? c.text.replace(/^\[\[ binary data |\s*\]\]$/g, "") : file ? "File" : "",
                                glyph: root.glyph(file ? 0xF0214 : 0xF0147),
                                thumb: c.image ? "file://" + root.clipCache + "/" + c.id : "",
                                clip: c
                            };
                        });
                    }
                    onKeyPressed: e => {
                        if (e.key === Qt.Key_Delete && (e.modifiers & Qt.ShiftModifier)) {
                            if (current)
                                root.deleteClip(current.clip);
                            e.accepted = true;
                        }
                    }
                    onAccepted: (i, row) => {
                        if (row)
                            root.pickClip(row.clip);
                    }
                    onEscaped: root.show("idle")
                }
            }

            BrowserPage {
                id: browserPage
                active: island.page === browserPage
                onCloseRequested: root.show("idle")
            }
            SwitcherPage {
                id: switcherPage
                active: island.page === switcherPage
                onCloseRequested: root.show("idle")
            }
            CalendarPage {
                id: calendarPage
                active: island.page === calendarPage
                onCloseRequested: root.show("idle")
            }
            PassPage {
                id: passPage
                active: island.page === passPage
                onCloseRequested: root.show("idle")
            }
            KeybindsPage {
                id: keybindsPage
                active: island.page === keybindsPage
                onCloseRequested: root.show("idle")
            }
            ToolsPage {
                id: toolsPage
                active: island.page === toolsPage
                onCloseRequested: root.show("idle")
                onOpenPage: m => root.show(m)
            }

            Page {
                id: themePage
                active: island.page === themePage

                Column {
                    spacing: Tokens.spacing.small
                    topPadding: Tokens.padding.small
                    bottomPadding: Tokens.padding.small

                    // Same strip as the wallpaper page: PathView wraps, the
                    // selected card stays in the middle. Each card is painted in
                    // the theme's own colours. Esc falls through to the island.
                    PathView {
                        id: themeList
                        readonly property int cardW: 200
                        readonly property real step: cardW + Tokens.spacing.small
                        function pick(): void {
                            if (root.themes[currentIndex])
                                root.applyTheme(root.themes[currentIndex].name);
                        }
                        width: 3 * step - Tokens.spacing.small
                        height: 88
                        clip: true
                        model: root.themes
                        // 3, not 5: with only four themes, 5 slots would show one twice.
                        pathItemCount: 3
                        preferredHighlightBegin: 0.5
                        preferredHighlightEnd: 0.5
                        highlightRangeMode: PathView.StrictlyEnforceRange
                        snapMode: PathView.SnapOneItem
                        highlightMoveDuration: 220
                        path: Path {
                            startX: themeList.width / 2 - 1.5 * themeList.step
                            startY: themeList.height / 2
                            PathLine {
                                x: themeList.width / 2 + 1.5 * themeList.step
                                y: themeList.height / 2
                            }
                        }
                        Keys.onLeftPressed: decrementCurrentIndex()
                        Keys.onRightPressed: incrementCurrentIndex()
                        Keys.onReturnPressed: pick()
                        Keys.onEnterPressed: pick()
                        Keys.onPressed: e => {
                            if (e.text === "h")
                                decrementCurrentIndex();
                            else if (e.text === "l")
                                incrementCurrentIndex();
                            else
                                return;
                            e.accepted = true;
                        }
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            readonly property bool sel: index === themeList.currentIndex
                            width: themeList.cardW
                            height: themeList.height
                            radius: Tokens.rounding.medium
                            color: modelData.base
                            border.color: sel ? Colors.accent : Colors.outline
                            border.width: sel ? 2 : 1
                            opacity: sel ? 1 : 0.6
                            Column {
                                x: Tokens.padding.medium
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Tokens.spacing.small
                                T {
                                    anchors.verticalCenter: undefined
                                    width: themeList.cardW - 2 * Tokens.padding.medium - 20
                                    elide: Text.ElideRight
                                    text: modelData.label
                                    color: modelData.text
                                }
                                Row {
                                    spacing: 6
                                    Repeater {
                                        model: modelData.dots
                                        Rectangle {
                                            required property string modelData
                                            width: 14
                                            height: 14
                                            radius: 7
                                            color: modelData
                                        }
                                    }
                                }
                            }
                            // Marks the active theme.
                            T {
                                anchors.verticalCenter: undefined
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: Tokens.padding.small
                                visible: modelData.name === root.themeCurrent
                                text: "✓"
                                color: modelData.accent
                                font.pixelSize: Tokens.fontSize.large
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: sel ? themeList.pick() : themeList.currentIndex = index
                            }
                        }
                    }

                    T {
                        anchors.verticalCenter: undefined
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: themeList.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.themes[themeList.currentIndex] ? root.themes[themeList.currentIndex].desc : ""
                        color: Colors.subtext0
                    }
                }
            }

            Page {
                id: wallPage
                active: island.page === wallPage

                Column {
                    spacing: Tokens.spacing.small
                    topPadding: Tokens.padding.small
                    bottomPadding: Tokens.padding.small

                    // PathView wraps around, so the selected card always sits in
                    // the middle with neighbours on both sides. Esc falls
                    // through to the island.
                    PathView {
                        id: wallList
                        readonly property int cardW: 160
                        readonly property real step: cardW + Tokens.spacing.small
                        function pick(): void {
                            if (!wpFiles.count)
                                return;
                            root.setWallpaper(wpFiles.get(currentIndex, "filePath"));
                            root.show("idle");
                        }
                        width: 5 * step - Tokens.spacing.small
                        height: cardW * 9 / 16
                        clip: true
                        model: wpFiles
                        pathItemCount: 5
                        preferredHighlightBegin: 0.5
                        preferredHighlightEnd: 0.5
                        highlightRangeMode: PathView.StrictlyEnforceRange
                        snapMode: PathView.SnapOneItem
                        highlightMoveDuration: 220
                        // Five slots of `step`; slot centres land on the card positions.
                        path: Path {
                            startX: wallList.width / 2 - 2.5 * wallList.step
                            startY: wallList.height / 2
                            PathLine {
                                x: wallList.width / 2 + 2.5 * wallList.step
                                y: wallList.height / 2
                            }
                        }
                        Keys.onLeftPressed: decrementCurrentIndex()
                        Keys.onRightPressed: incrementCurrentIndex()
                        Keys.onReturnPressed: pick()
                        Keys.onEnterPressed: pick()
                        Keys.onPressed: e => {
                            if (e.text === "h")
                                decrementCurrentIndex();
                            else if (e.text === "l")
                                incrementCurrentIndex();
                            else
                                return;
                            e.accepted = true;
                        }
                        delegate: Rectangle {
                            required property int index
                            required property string filePath
                            width: wallList.cardW
                            height: wallList.height
                            radius: Tokens.rounding.medium
                            color: Colors.surface1
                            border.color: index === wallList.currentIndex ? Colors.accent : Colors.outline
                            border.width: index === wallList.currentIndex ? 2 : 1
                            clip: true
                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                source: "file://" + filePath
                                // Decode at card size; the originals are multi-megapixel.
                                sourceSize.width: wallList.cardW * 2
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            // Marks the wallpaper that is already set.
                            Rectangle {
                                visible: filePath === root.wallpaper
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                width: 20
                                height: 20
                                radius: 10
                                color: Colors.accent
                                T {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: Colors.bg
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: index === wallList.currentIndex ? wallList.pick() : wallList.currentIndex = index
                            }
                        }
                    }

                    T {
                        anchors.verticalCenter: undefined
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: wpFiles.count ? wpFiles.get(wallList.currentIndex, "fileName") + "   (" + (wallList.currentIndex + 1) + "/" + wpFiles.count + ")" : "no images in ~/Pictures"
                        color: Colors.subtext0
                    }
                }
            }

            Page {
                id: powerPage
                active: island.page === powerPage

                Row {
                    spacing: Tokens.spacing.small
                    Repeater {
                        model: root.powerActions
                        // macOS-style round glass buttons; the selected one turns accent,
                        // an armed one red.
                        delegate: Item {
                            id: pbtn
                            required property int index
                            required property var modelData
                            readonly property bool armed: root.powerArmed === index
                            readonly property bool sel: index === root.powerSel
                            width: 84
                            height: 92
                            Column {
                                anchors.centerIn: parent
                                spacing: Tokens.spacing.small
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 56
                                    height: 56
                                    radius: 28
                                    color: pbtn.armed ? Colors.red : pbtn.sel ? Colors.accent : Qt.alpha(Colors.fg, 0.1)
                                    border.width: 1
                                    border.color: Qt.alpha(Colors.fg, 0.06)
                                    Behavior on color {
                                        CAnim {}
                                    }
                                    T {
                                        anchors.centerIn: parent
                                        text: root.glyph(pbtn.modelData.icon)
                                        font.pixelSize: Tokens.fontSize.large
                                        color: pbtn.armed ? Colors.crust : pbtn.sel ? Colors.base : Colors.fg
                                    }
                                }
                                T {
                                    anchors.verticalCenter: undefined
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: pbtn.armed ? "Again?" : pbtn.modelData.label
                                    font.pixelSize: Tokens.fontSize.small
                                    color: pbtn.armed || pbtn.sel ? Colors.fg : Colors.subtext0
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                pressAndHoldInterval: 1000
                                onEntered: root.powerSel = pbtn.index
                                onClicked: root.powerPress(pbtn.index, false)
                                onPressAndHold: root.powerPress(pbtn.index, true)
                            }
                        }
                    }
                }
            }

            Page {
                id: polkitPage
                active: island.page === polkitPage
                readonly property var flow: polkit.flow

                Column {
                    spacing: Tokens.spacing.small
                    topPadding: Tokens.padding.small
                    bottomPadding: Tokens.padding.small
                    T {
                        anchors.verticalCenter: undefined
                        text: root.glyph(0xF033E) + "  Authentication required"
                        font.bold: true
                    }
                    T {
                        anchors.verticalCenter: undefined
                        width: 448
                        wrapMode: Text.Wrap
                        text: polkitPage.flow?.message ?? ""
                        color: Colors.subtext0
                    }
                    Rectangle {
                        width: 448
                        height: 40
                        radius: Tokens.rounding.small
                        color: Colors.inputBg
                        StyledTextField {
                            id: polkitField
                            anchors.fill: parent
                            font.family: "JetBrainsMono Nerd Font"
                            background: null
                            echoMode: polkitPage.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                            placeholderText: polkitPage.flow?.inputPrompt || "Password"
                            onAccepted: {
                                polkitPage.flow?.submit(text);
                                text = "";
                            }
                        }
                    }
                    T {
                        anchors.verticalCenter: undefined
                        width: 448
                        wrapMode: Text.Wrap
                        visible: text !== ""
                        text: polkitPage.flow?.failed ? "Wrong password, try again" : (polkitPage.flow?.supplementaryMessage ?? "")
                        color: polkitPage.flow?.failed || polkitPage.flow?.supplementaryIsError ? Colors.red : Colors.subtext0
                    }
                }
            }

            Page {
                id: dashPage
                active: island.page === dashPage
                // Size from the Column, not childrenRect (implicitHeight binding loop).
                implicitWidth: dashCol.implicitWidth
                implicitHeight: dashCol.implicitHeight

                // Bell, top-right: opens the notification hub.
                T {
                    anchors.right: dashCol.right
                    anchors.top: dashCol.top
                    text: root.glyph(0xF009A)
                    font.pixelSize: Tokens.fontSize.large
                    color: root.history.length > 0 ? Colors.accent : Colors.subtext0
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        onClicked: root.show("hub")
                    }
                }

                Column {
                    id: dashCol
                    spacing: Tokens.spacing.medium

                    Row {
                        spacing: Tokens.spacing.medium
                        T {
                            text: Qt.formatDateTime(clock.date, "h:mm AP")
                            font.bold: true
                            font.pixelSize: Tokens.fontSize.large
                        }
                        T {
                            text: Qt.formatDateTime(clock.date, "dddd d MMMM")
                            color: Colors.subtext0
                        }
                        T {
                            text: root.glyph(root.charging ? 0xF0084 : 0xF0079) + " " + root.batPct + "%"
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.show("battery")
                            }
                        }
                    }
                    // Display and Sound modules, as in macOS Control Center.
                    Repeater {
                        model: [
                            { label: "Display", sound: false },
                            { label: "Sound", sound: true }
                        ]
                        Module {
                            id: sliderMod
                            required property var modelData
                            required property int index
                            border.width: root.kbNav && root.dashSel === index ? 2 : 1
                            border.color: root.kbNav && root.dashSel === index ? Colors.accent : Qt.alpha(Colors.fg, 0.06)
                            width: 448
                            height: sliderCol.implicitHeight + 2 * Tokens.padding.medium
                            Column {
                                id: sliderCol
                                x: Tokens.padding.medium
                                y: Tokens.padding.medium
                                width: parent.width - 2 * Tokens.padding.medium
                                spacing: Tokens.spacing.small
                                Item {
                                    width: parent.width
                                    height: modLabel.implicitHeight
                                    T {
                                        id: modLabel
                                        text: sliderMod.modelData.label
                                        font.weight: Font.DemiBold
                                    }
                                    T {
                                        anchors.right: parent.right
                                        text: Math.round((sliderMod.modelData.sound ? root.volume : root.brightness) * 100) + "%"
                                        color: Colors.subtext0
                                        font.pixelSize: Tokens.fontSize.small
                                    }
                                }
                                Bar {
                                    anchors.verticalCenter: undefined
                                    width: parent.width
                                    value: sliderMod.modelData.sound ? root.volume : root.brightness
                                    icon: root.glyph(!sliderMod.modelData.sound ? 0xF00E0 : root.muted ? 0xF075F : 0xF057E)
                                    onMoved: v => sliderMod.modelData.sound ? root.setVolume(v) : root.setBrightness(v)
                                    onIconClicked: if (sliderMod.modelData.sound && root.sink?.audio) root.sink.audio.muted = !root.muted
                                }
                            }
                        }
                    }
                    // Children stay in this order: root.dashKey indexes them (2-7).
                    Grid {
                        id: dashGrid
                        columns: 2
                        spacing: Tokens.spacing.small

                        Tile {
                            sel: root.kbNav && root.dashSel === 2
                            on: Networking.wifiEnabled
                            hasPage: true
                            icon: root.glyph(on ? 0xF05A9 : 0xF05AA)
                            title: root.wifiNet?.name ?? "Wi-Fi"
                            sub: root.wifiNet ? Math.round(root.wifiNet.signalStrength * 100) + "%" : (on ? "Not connected" : "Off")
                            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                            onOpened: root.show("wifi")
                        }
                        Tile {
                            sel: root.kbNav && root.dashSel === 3
                            on: root.btAdapter?.enabled ?? false
                            hasPage: true
                            icon: root.glyph(on ? 0xF00AF : 0xF00B2)
                            title: root.btDev?.name ?? "Bluetooth"
                            sub: !on ? "Off" : root.btDev ? (root.btDev.batteryAvailable ? Math.round(root.btDev.battery * 100) + "%" : "Connected") : "No device"
                            onToggled: if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled
                            onOpened: root.show("bluetooth")
                        }
                        Tile {
                            sel: root.kbNav && root.dashSel === 4
                            on: !root.muted
                            hasPage: true
                            icon: root.glyph(on ? 0xF057E : 0xF075F)
                            title: root.sink?.description ?? "Output"
                            sub: Math.round(root.volume * 100) + "%"
                            onToggled: if (root.sink?.audio) root.sink.audio.muted = !root.muted
                            onOpened: root.show("output")
                        }
                        Tile {
                            sel: root.kbNav && root.dashSel === 5
                            on: !(root.source?.audio?.muted ?? true)
                            hasPage: true
                            icon: root.glyph(on ? 0xF036C : 0xF036D)
                            title: root.source?.description ?? "Microphone"
                            sub: Math.round((root.source?.audio?.volume ?? 0) * 100) + "%"
                            onToggled: if (root.source?.audio) root.source.audio.muted = !root.source.audio.muted
                            onOpened: root.show("input")
                        }
                        Tile {
                            sel: root.kbNav && root.dashSel === 6
                            on: root.dnd
                            icon: root.glyph(on ? 0xF009B : 0xF009A)
                            title: "Do not disturb"
                            sub: on ? "On" : "Off"
                            onToggled: root.dnd = !root.dnd
                        }
                        Tile {
                            sel: root.kbNav && root.dashSel === 7
                            on: root.night
                            icon: root.glyph(0xF0594)
                            title: "Night mode"
                            sub: on ? "On" : "Off"
                            onToggled: root.toggleNight()
                        }
                    }
                    Tray {}
                }
            }

            Page {
                id: wifiPage
                active: island.page === wifiPage

                Column {
                    spacing: Tokens.spacing.medium
                    Header {
                        title: "Wi-Fi"
                        hasToggle: true
                        on: Networking.wifiEnabled
                        hasScan: true
                        scanning: root.wifiDev?.scannerEnabled ?? false
                        onBack: root.show("dashboard")
                        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                        onScan: if (root.wifiDev) root.wifiDev.scannerEnabled = !root.wifiDev.scannerEnabled
                    }
                    Scroll {
                        id: wifiScroll
                        Repeater {
                            id: wifiRep
                            model: root.wifiNets
                            delegate: ListRow {
                                required property var modelData
                                required property int index
                                sel: root.kbNav && index === root.listSel
                                active: modelData.connected
                                icon: root.wifiIcon(modelData.signalStrength)
                                title: modelData.name
                                sub: (modelData.connected ? "Connected" : modelData.stateChanging ? "Working…" : modelData.known ? "Saved" : modelData.security === WifiSecurityType.Open ? "Open" : "Secured") + (modelData.security === WifiSecurityType.Open ? "" : "  " + root.glyph(0xF033E))
                                action: modelData.known ? root.glyph(0xF0A7A) : ""
                                onClicked: root.wifiClick(modelData)
                                onActionClicked: modelData.forget()
                            }
                        }
                    }
                    Rectangle {
                        visible: root.wifiPending !== null
                        width: 448
                        height: 36
                        radius: Tokens.rounding.small
                        color: Colors.inputBg
                        StyledTextField {
                            id: pskField
                            anchors.fill: parent
                            echoMode: TextInput.Password
                            font.family: "JetBrainsMono Nerd Font"
                            placeholderText: "Password for " + (root.wifiPending?.name ?? "")
                            onAccepted: {
                                root.wifiPending?.connectWithPsk(text);
                                text = "";
                                root.wifiPending = null;
                                island.forceActiveFocus();
                            }
                        }
                        onVisibleChanged: if (visible) pskField.forceActiveFocus()
                    }
                }
            }

            Page {
                id: btPage
                active: island.page === btPage

                Column {
                    spacing: Tokens.spacing.medium
                    Header {
                        title: "Bluetooth"
                        hasToggle: true
                        on: root.btAdapter?.enabled ?? false
                        hasScan: true
                        scanning: root.btAdapter?.discovering ?? false
                        onBack: root.show("dashboard")
                        onToggled: if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled
                        onScan: if (root.btAdapter?.enabled) root.btAdapter.discovering = !root.btAdapter.discovering
                    }
                    Scroll {
                        id: btScroll
                        Repeater {
                            id: btRep
                            model: root.btDevices
                            delegate: ListRow {
                                id: btRow
                                required property var modelData
                                required property int index
                                sel: root.kbNav && index === root.listSel
                                active: modelData.connected
                                icon: root.btIcon(modelData)
                                title: modelData.name
                                sub: root.btSub(modelData)
                                action: modelData.paired ? root.glyph(0xF0A7A) : ""
                                onClicked: root.btClick(modelData)
                                onActionClicked: modelData.forget()

                                Connections {
                                    target: btRow.modelData
                                    function onPairedChanged(): void {
                                        if (btRow.modelData.paired && root.btPairing === btRow.modelData) {
                                            root.btPairing = null;
                                            btRow.modelData.connect();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            AudioPage {
                id: outPage
                active: island.page === outPage
                title: "Output"
                icon: root.glyph(root.muted ? 0xF075F : 0xF057E)
                nodes: root.sinks
                current: root.sink
                ring: root.kbNav
                onBack: root.show("dashboard")
                onPick: n => Pipewire.preferredDefaultAudioSink = n
            }

            AudioPage {
                id: inPage
                active: island.page === inPage
                title: "Input"
                icon: root.glyph(root.source?.audio?.muted ? 0xF036D : 0xF036C)
                nodes: root.sources
                current: root.source
                ring: root.kbNav
                onBack: root.show("dashboard")
                onPick: n => Pipewire.preferredDefaultAudioSource = n
            }

            Page {
                id: batPage
                active: island.page === batPage

                Column {
                    spacing: Tokens.spacing.medium

                    Row {
                        spacing: Tokens.spacing.medium
                        T {
                            text: root.glyph(root.charging ? 0xF0084 : 0xF0079) + " " + root.batPct + "%"
                            font.pixelSize: Tokens.fontSize.extraLarge
                            font.bold: true
                        }
                        T {
                            text: root.batStatus
                            color: Colors.subtext0
                        }
                    }
                    Row {
                        spacing: Tokens.spacing.small
                        Stat {
                            icon: root.glyph(0xF05F6)
                            value: root.laptopBat?.healthSupported ? Math.round(root.laptopBat.healthPercentage) + "%" : "n/a"
                            label: "Health"
                        }
                        Stat {
                            icon: root.glyph(0xF0079)
                            value: (root.laptopBat?.energyCapacity ?? 0).toFixed(1) + " Wh"
                            label: "Capacity"
                        }
                        Stat {
                            icon: root.glyph(0xF140B)
                            // On AC and not charging (full, or held at the 80% cap) the
                            // battery moves ~0 W and nothing else reports system draw.
                            readonly property bool moving: UPower.onBattery || root.bat?.state === UPowerDeviceState.Charging
                            value: moving ? (root.bat?.changeRate ?? 0).toFixed(1) + " W" : root.cpuWatts !== "" ? root.cpuWatts + " W" : "On AC"
                            label: UPower.onBattery ? "Draw" : moving ? "Charging" : root.cpuWatts !== "" ? "CPU draw" : "Idle battery"
                        }
                    }
                    // Power profile (tlp-pd serves the power-profiles D-Bus API).
                    Row {
                        spacing: Tokens.spacing.small
                        Repeater {
                            model: [
                                { p: PowerProfile.PowerSaver, icon: 0xF032A, label: "Saver" },
                                { p: PowerProfile.Balanced, icon: 0xF04C5, label: "Balanced" },
                                { p: PowerProfile.Performance, icon: 0xF0E7A, label: "Performance" }
                            ]
                            delegate: Rectangle {
                                id: prof
                                required property var modelData
                                required property int index
                                readonly property bool on: PowerProfiles.profile === modelData.p
                                border.width: root.kbNav && index === root.listSel ? 2 : 0
                                border.color: on ? Colors.fg : Colors.accent
                                visible: modelData.p !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                                width: 140
                                height: 44
                                radius: Tokens.rounding.large
                                color: on ? Colors.accent : Colors.surface0
                                T {
                                    anchors.centerIn: parent
                                    text: root.glyph(prof.modelData.icon) + "  " + prof.modelData.label
                                    color: prof.on ? Colors.base : Colors.fg
                                    font.bold: prof.on
                                }
                                StateLayer {
                                    radius: prof.radius
                                    onClicked: PowerProfiles.profile = prof.modelData.p
                                }
                            }
                        }
                    }
                    Repeater {
                        model: root.peripherals
                        delegate: T {
                            required property var modelData
                            anchors.verticalCenter: undefined
                            text: root.glyph(modelData.type === UPowerDeviceType.Mouse ? 0xF037D : modelData.type === UPowerDeviceType.Keyboard ? 0xF030C : 0xF0079) + "  " + (modelData.model || "Device") + "  " + Math.round(modelData.percentage * 100) + "%"
                        }
                    }
                }
            }

            Page {
                id: trayPage
                active: island.page === trayPage
                Tray {
                    id: trayKeys
                    sel: root.kbNav ? root.listSel : -1
                }
            }
        }
    }
}
