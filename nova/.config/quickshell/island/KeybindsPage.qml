// Keybindings cheat sheet: app tabs on the left, that app's bindings on the
// right. Data comes from scripts/quickshell/kbctl.sh:
//   refresh -> re-run the per-app extractors
//   list    -> JSON [{app, count, bindings:[{key,desc}]}]
// Tab / Shift+Tab switch app, Enter or click copies "key  desc".
import QtQuick
import Quickshell
import Quickshell.Io
import common

Page {
    id: page

    readonly property string kbctl: Quickshell.env("HOME") + "/.dotfiles/scripts/quickshell/kbctl.sh"
    property var apps: []
    property int curApp: 0
    readonly property var curBindings: (apps.length && apps[curApp]) ? apps[curApp].bindings : []

    function switchApp(d: int): void {
        if (!apps.length)
            return;
        curApp = (curApp + d + apps.length) % apps.length;
        list.reset();
    }
    function copy(b): void {
        if (!b)
            return;
        // Text goes as an argument, never through a shell, so $ and ` stay literal.
        copier.command = ["wl-copy", "--", b.key + "  " + b.desc];
        copier.running = true;
    }

    onOpened: {
        curApp = 0;
        list.reset();
        lister.running = true;
        refresher.running = true; // chains to another list when done
        Qt.callLater(() => list.focusField());
    }

    Process {
        id: lister
        command: ["bash", page.kbctl, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const a = JSON.parse(text);
                    if (a.length) {
                        page.apps = a;
                        if (page.curApp >= a.length)
                            page.curApp = 0;
                    }
                } catch (e) {}
            }
        }
    }
    Process {
        id: refresher
        command: ["bash", page.kbctl, "refresh"]
        stdout: StdioCollector {
            onStreamFinished: lister.running = true
        }
    }
    Process {
        id: copier
    }

    Item {
        width: 1100
        height: 640

        // ── left: app tabs ────────────────────────────────────────────────
        Column {
            id: leftPane
            x: Tokens.padding.large
            y: Tokens.padding.large
            width: 240
            spacing: Tokens.spacing.extraSmall

            Row {
                height: 40
                spacing: Tokens.spacing.small
                T {
                    text: "󰌌"
                    color: Colors.accent
                    font.pixelSize: Tokens.fontSize.large
                }
                T {
                    text: "Keybindings"
                    font.weight: Font.Medium
                    font.pixelSize: Tokens.fontSize.large
                }
            }
            Item {
                width: 1
                height: Tokens.spacing.small
            }
            Repeater {
                model: page.apps
                delegate: Rectangle {
                    id: tab
                    required property int index
                    required property var modelData
                    readonly property bool sel: index === page.curApp
                    width: leftPane.width
                    height: 46
                    radius: Tokens.rounding.medium
                    color: sel ? Colors.surface2 : "transparent"
                    T {
                        x: Tokens.padding.medium
                        width: parent.width - 2 * Tokens.padding.medium - tabCount.width
                        text: tab.modelData.app
                        elide: Text.ElideRight
                        color: tab.sel ? Colors.accent : Colors.fg
                        font.weight: tab.sel ? Font.Medium : Font.Normal
                        font.pixelSize: Tokens.fontSize.larger
                    }
                    T {
                        id: tabCount
                        anchors.right: parent.right
                        anchors.rightMargin: Tokens.padding.medium
                        text: tab.modelData.count
                        color: tab.sel ? Colors.accent : Colors.subtext
                        font.pixelSize: Tokens.fontSize.smaller
                    }
                    StateLayer {
                        onClicked: {
                            page.curApp = tab.index;
                            list.reset();
                            list.focusField();
                        }
                    }
                }
            }
        }
        T {
            anchors.verticalCenter: undefined
            anchors.left: leftPane.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.padding.large
            width: leftPane.width
            wrapMode: Text.WordWrap
            lineHeight: 1.3
            text: "Tab / Shift+Tab switch\nEnter copy · Esc close"
            color: Colors.subtext
            font.pixelSize: Tokens.fontSize.smaller
        }

        Rectangle {
            id: divider
            x: leftPane.x + leftPane.width + Tokens.spacing.large
            y: Tokens.padding.large
            width: 1
            height: parent.height - 2 * Tokens.padding.large
            color: Colors.outline
        }

        // ── right: filter + bindings ──────────────────────────────────────
        SearchList {
            id: list
            x: divider.x + 1 + Tokens.spacing.large
            y: Tokens.padding.small
            listWidth: parent.width - x - Tokens.padding.large
            maxRows: 10
            glyph: "\u{f0349}" // nf-md-magnify (U+F002 is the fl ligature in SF Pro)
            placeholder: (page.apps.length ? page.apps[page.curApp].app : "") + " — filter keys or actions…"
            emptyText: page.apps.length ? "No matching bindings" : "Loading…"
            model: {
                const q = text.toLowerCase();
                const out = [];
                for (const b of page.curBindings)
                    if (q === "" || (b.key + " " + b.desc).toLowerCase().includes(q))
                        out.push({
                            title: b.key,
                            sub: b.desc,
                            glyph: "󰌌",
                            key: b.key,
                            desc: b.desc
                        });
                return out;
            }
            onAccepted: (i, row) => page.copy(row)
            onEscaped: page.closeRequested()
            onKeyPressed: e => {
                if (e.key === Qt.Key_Backtab || (e.key === Qt.Key_Tab && (e.modifiers & Qt.ShiftModifier)))
                    page.switchApp(-1);
                else if (e.key === Qt.Key_Tab)
                    page.switchApp(1);
                else
                    return;
                e.accepted = true;
            }
        }
    }
}
