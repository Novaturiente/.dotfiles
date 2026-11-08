// Mod+D Spotlight: one field over apps, open windows, island pages, the Mod+T
// tools, system toggles, power actions, novabrowser bookmarks/history, files
// under ~ and the web. A sum
// shows its answer first. Nothing is listed until you type.
//
// Enter launches / focuses / opens files (xdg-open) / opens a folder as a tmux
// session (scripts/quickshell/tmux-open.sh) / copies the answer / opens the
// url or searches the web (scripts/quickshell/browser-open.sh). Power actions
// other than Lock need a second Enter within 3 s. Esc closes.
//
// Files: fd over ~ with hidden files, caches skipped, 150 ms after the last key.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import common
import "tools.js" as Tools

Page {
    id: page

    // Pinned to the top, not centred: while the island animates to a new
    // result height, a centred page slides up and the clip hides the field.
    anchors.centerIn: undefined
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter

    property var apps: []         // shell's root.apps, most-used first
    property var powerActions: [] // shell's root.powerActions
    property var toggles: []      // shell's root.systemToggles
    signal openTool(string view)  // a ToolsPage view: calc, timer, stopwatch, alarm
    signal launchApp(string file)
    signal runPower(int index)
    signal openMode(string mode)

    readonly property string home: Quickshell.env("HOME")
    readonly property string scriptDir: home + "/.dotfiles/scripts/quickshell"
    readonly property var islandPages: [
        // keys: extra search words.
        { title: "Wi-Fi", keys: "wifi wireless network", mode: "wifi", icon: 0xF05A9 },
        { title: "Bluetooth", keys: "bt", mode: "bluetooth", icon: 0xF00AF },
        { title: "Sound output", keys: "volume audio speaker mute", mode: "output", icon: 0xF057E },
        { title: "Microphone", keys: "mic input mute", mode: "input", icon: 0xF036C },
        { title: "Battery", mode: "battery", icon: 0xF0079 },
        { title: "Clipboard history", mode: "clipboard", icon: 0xF0147 },
        { title: "Calendar", mode: "calendar", icon: 0xF00ED },
        { title: "Passwords", mode: "pass", icon: 0xF0306 },
        { title: "Keybindings", mode: "keybindings", icon: 0xF030C },
        { title: "Tools", mode: "tools", icon: 0xF00EC },
        { title: "Power menu", mode: "power", icon: 0xF0425 },
        { title: "Dashboard", mode: "dashboard", icon: 0xF0E4 },
        { title: "Wallpaper", mode: "wallpaper", icon: 0xF02E9 },
        { title: "Theme", mode: "theme", icon: 0xF03D8 }
    ]
    readonly property var tools: [
        { title: "Calculator", view: "calc", icon: 0xF00EC },
        { title: "Timer", view: "timer", icon: 0xF051B },
        { title: "Stopwatch", view: "stopwatch", icon: 0xF13AB },
        { title: "Alarms", view: "alarm", icon: 0xF0020 }
    ]
    property var urls: []  // browser-urls.sh rows, loaded on open
    property var files: [] // [{dir, path}] from the last fd run
    property int armed: -1 // power action waiting for its second Enter

    readonly property string query: search.text.trim()
    readonly property var rows: {
        const q = query;
        if (q === "")
            return [];
        const terms = q.toLowerCase().split(/\s+/);
        const has = s => {
            const l = (s || "").toLowerCase();
            return terms.every(t => l.includes(t));
        };
        const g = cp => String.fromCodePoint(cp);
        const out = [];

        // A plain number is not a sum worth showing.
        const ans = Tools.calc(q);
        if (ans && !/^[\d.,\s]+$/.test(q))
            out.push({ kind: "calc", title: "= " + ans, sub: "Calculator · Enter copies", glyph: g(0xF00EC), value: ans });

        const hits = apps.filter(a => has(a.name));
        const lq = q.toLowerCase();
        const starts = hits.filter(a => a.name.toLowerCase().startsWith(lq));
        starts.concat(hits.filter(a => !starts.includes(a))).slice(0, 6).forEach(a => out.push({
                    kind: "app", title: a.name, sub: a.comment || "Application",
                    icon: Quickshell.iconPath(a.icon, "application-x-executable"), file: a.file
                }));

        ToplevelManager.toplevels.values.filter(t => has((t.title || "") + " " + (t.appId || ""))).slice(0, 4).forEach(t => out.push({
                    kind: "win", title: t.title || "(untitled)", sub: "Window · " + (t.appId || ""),
                    icon: Quickshell.iconPath(t.appId, "application-x-executable"), win: t
                }));

        tools.filter(t => has(t.title)).forEach(t => out.push({ kind: "tool", title: t.title, sub: "Tools", glyph: g(t.icon), view: t.view }));

        toggles.filter(t => has(t.title + " " + t.keys)).forEach(t => out.push({
                    kind: "toggle", title: t.title, sub: "System · " + (t.on ? "On" : "Off") + " · Enter toggles", glyph: g(t.icon), act: t.act
                }));

        islandPages.filter(p => has(p.title + " " + (p.keys || ""))).forEach(p => out.push({ kind: "page", title: p.title, sub: "Island", glyph: g(p.icon), mode: p.mode }));

        powerActions.forEach((a, i) => {
            if (has(a.label))
                out.push({ kind: "power", title: armed === i ? a.label + ": press Enter again" : a.label, sub: "System", glyph: g(a.icon), index: i, confirm: a.confirm });
        });

        urls.filter(r => has(r.title + " " + r.url)).slice(0, 4).forEach(r => out.push({
                    kind: "url", title: (r.bookmark ? "★ " : "") + r.title, sub: r.url,
                    icon: r.icon ? "file://" + r.icon : "", glyph: g(r.bookmark ? 0xF00C0 : 0xF059F), value: r.url
                }));

        // Older fd results still show while a newer run is pending, if they match.
        files.filter(f => has(f.path.slice(f.path.lastIndexOf("/") + 1))).slice(0, 8).forEach(f => out.push({
                    kind: "file", title: f.path.slice(f.path.lastIndexOf("/") + 1),
                    sub: f.path.replace(home, "~"), glyph: g(f.dir ? 0xF024B : 0xF0214), value: f.path, dir: f.dir
                }));

        // Same url test as browser-open.sh, which does the real resolving.
        const isUrl = !/\s/.test(q) && /^([a-z][a-z0-9+.-]*:\/\/|localhost|127\.0\.0\.1|[^\s]+\.[a-z]{2,}(:\d+)?(\/|$))/i.test(q);
        out.push({ kind: "web", title: isUrl ? "Open " + q : "Search the web for “" + q + "”", sub: "Web", glyph: g(0xF059F), value: q });
        return out;
    }

    function accept(row: var): void {
        if (!row)
            return;
        switch (row.kind) {
        case "app":
            launchApp(row.file);
            return;
        case "page":
            openMode(row.mode);
            return;
        case "tool":
            openTool(row.view);
            return;
        case "toggle":
            row.act();
            break;
        case "power":
            if (row.confirm && armed !== row.index) {
                armed = row.index;
                armTimer.restart();
                return;
            }
            runPower(row.index);
            return;
        case "win":
            row.win.activate();
            break;
        case "calc":
            Quickshell.execDetached(["wl-copy", row.value]);
            break;
        case "file":
            Quickshell.execDetached(row.dir ? ["bash", scriptDir + "/tmux-open.sh", row.value] : ["xdg-open", row.value]);
            break;
        default: // url, web
            Quickshell.execDetached(["bash", scriptDir + "/browser-open.sh", row.value]);
        }
        closeRequested();
    }

    onOpened: {
        search.reset();
        files = [];
        armed = -1;
        urlLoader.running = true;
        Qt.callLater(() => search.focusField());
    }

    Timer {
        id: armTimer
        interval: 3000
        onTriggered: page.armed = -1
    }

    Process {
        id: urlLoader
        command: ["bash", page.scriptDir + "/browser-urls.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.urls = JSON.parse(text);
                } catch (e) {
                    page.urls = [];
                }
            }
        }
    }

    Timer {
        id: fileTimer
        interval: 150
        onTriggered: {
            if (finder.running) { // a full miss walks all of ~ (~0.6 s); wait for it
                restart();
                return;
            }
            // fd gets only the first word; rows' has() checks the rest.
            const word = page.query.split(/\s+/)[0];
            if (word.length < 2) {
                page.files = [];
                return;
            }
            // Folders and files in parallel so each line says which it is.
            const fd = "fd -H -i -F --one-file-system -E .git -E .cache -E node_modules -E .local -E target -E build ";
            finder.command = ["sh", "-c", "{ " + fd + "-t d --max-results 4 --format 'd {}' -- \"$1\" ~ & " + fd + "-t f --max-results 12 --format 'f {}' -- \"$1\" ~; wait; }", "sh", word];
            finder.running = true;
        }
    }

    Process {
        id: finder
        stdout: StdioCollector {
            onStreamFinished: page.files = text.split("\n").filter(l => l.length > 2).map(l => ({ dir: l[0] === "d", path: l.slice(2) }))
        }
    }

    SearchList {
        id: search
        glyph: String.fromCodePoint(0xF0349)
        placeholder: "Search apps, files, windows, the web… or type a sum"
        emptyText: ""
        detached: true
        countText: ""
        model: page.rows
        onTextChanged: {
            page.armed = -1;
            fileTimer.restart();
        }
        onAccepted: (i, row) => page.accept(row)
        onEscaped: page.closeRequested()
    }
}
