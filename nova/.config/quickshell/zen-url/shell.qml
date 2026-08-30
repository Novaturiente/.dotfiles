//@ pragma UseQApplication
// Zen URL bar — triggered by Mod+S (niri). Replaces the older rofi url menu.
// Shows Zen bookmarks + history (with favicons) as you type; opens the pick
// or the typed text in Zen, then focuses the window. Run: `qs -c zen-url`.
//
// Data + launch reuse the bash helpers (sqlite/favicon/niri-focus live there):
//   scripts/quickshell/zen-urls.sh  -> JSON list on stdout
//   scripts/quickshell/zen-open.sh  -> resolve+open+focus a url/typed text
// ponytail: inline theme; extract to a shared module when a 2nd menu migrates.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ShellRoot {
    readonly property string scriptDir: Quickshell.env("HOME") + "/.dotfiles/scripts/quickshell"

    // Space-galaxy palette — fixed, matches scripts/rofi/config.rasi (rofi -theme black).
    // Deliberately NOT wallpaper-derived.
    readonly property color bg:      "#e61e1e2e"  // deep space (≈90% opaque)
    readonly property color inputBg: "#d0313244"  // starry gray, translucent
    readonly property color outline: "#45475a"    // starry gray (frame)
    readonly property color accent:  "#cba6f7"   // mauve    // cosmic purple (border/glyph/selection)
    readonly property color selBg:   "#45475a"   // surface1    // selected row = cosmic purple
    readonly property color fg:      "#cdd6f4"    // bright starlight
    readonly property color subtext: "#7f849c"    // dim stardust (urls/count)
    readonly property string uiFont: "JetBrainsMono Nerd Font"

    // full list (from zen-urls.sh) and the current filtered view
    property var allRows: []
    property var rows: []
    property int selected: 0

    function applyFilter(q) {
        var needle = q.trim().toLowerCase();
        if (needle === "") { rows = allRows; selected = 0; return; }
        var terms = needle.split(/\s+/);
        var out = [];
        for (var i = 0; i < allRows.length; i++) {
            var hay = (allRows[i].title + " " + allRows[i].url).toLowerCase();
            var ok = true;
            for (var t = 0; t < terms.length; t++)
                if (hay.indexOf(terms[t]) === -1) { ok = false; break; }
            if (ok) out.push(allRows[i]);
        }
        rows = out;
        selected = 0;
    }

    function accept() {
        // pick the highlighted row if the list has matches; else open typed text.
        var choice = (rows.length > 0 && selected >= 0 && selected < rows.length)
            ? rows[selected].url
            : input.text;
        if (choice.trim() === "") { win.visible = false; return; }
        opener.command = ["bash", scriptDir + "/zen-open.sh", choice];
        opener.running = true;
        win.visible = false;
    }

    // Resident daemon: stay running, toggle the window via IPC (engine boot is
    // paid once at login, so Mod+S is instant). Bind: qs -c zen-url ipc call menu toggle
    IpcHandler {
        target: "menu"
        function toggle(): void {
            if (win.visible) { win.visible = false; }
            else { input.text = ""; selected = 0; loader.running = true; win.visible = true; }
        }
    }

    // load bookmarks + history as JSON (primed once at boot, refreshed on show)
    Process {
        id: loader
        running: true
        command: ["bash", scriptDir + "/zen-urls.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { allRows = JSON.parse(text); }
                catch (e) { allRows = []; }
                applyFilter(input.text);
            }
        }
    }

    // fire-and-forget opener
    Process { id: opener }

    PanelWindow {
        id: win
        visible: false                 // daemon starts hidden; IPC toggle reveals it
        anchors { top: false; bottom: false; left: false; right: false }
        implicitWidth: 760
        implicitHeight: 520
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-zen-url"

        onVisibleChanged: if (visible) input.forceActiveFocus()

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: bg
            border.color: outline
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // ── input box ───────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: 0
                    color: inputBg
                    border.color: accent
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        Text {
                            text: ""            // globe glyph (browser)
                            color: accent
                            
                            font.family: uiFont; font.pixelSize: 18
                        }
                        TextField {
                            id: input
                            Layout.fillWidth: true
                            focus: true
                            color: fg
                            font.family: uiFont; font.pixelSize: 16
                            placeholderText: "Search bookmarks & history, or type a URL…"
                            placeholderTextColor: subtext
                            background: null
                            onTextChanged: applyFilter(text)

                            // keys the list needs; everything else types normally
                            Keys.onPressed: (e) => {
                                if (e.key === Qt.Key_Escape) {
                                    win.visible = false; e.accepted = true;
                                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                    accept(); e.accepted = true;
                                } else if (e.key === Qt.Key_Down || (e.key === Qt.Key_N && (e.modifiers & Qt.ControlModifier))) {
                                    if (rows.length) selected = (selected + 1) % rows.length;
                                    e.accepted = true;
                                } else if (e.key === Qt.Key_Up || (e.key === Qt.Key_P && (e.modifiers & Qt.ControlModifier))) {
                                    if (rows.length) selected = (selected - 1 + rows.length) % rows.length;
                                    e.accepted = true;
                                }
                            }
                        }
                        Text {
                            text: rows.length + ""
                            color: subtext
                            font.family: uiFont; font.pixelSize: 12
                        }
                    }
                }

                // ── results ─────────────────────────────────────────────────
                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: rows
                    currentIndex: selected
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        width: ListView.view.width
                        height: 48
                        radius: 0
                        color: index === selected ? selBg : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // favicon (fallback glyph when none)
                            Item {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                Image {
                                    anchors.fill: parent
                                    source: modelData.icon ? "file://" + modelData.icon : ""
                                    visible: modelData.icon !== ""
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize.width: 20
                                    sourceSize.height: 20
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: modelData.icon === ""
                                    text: modelData.bookmark ? "" : ""
                                    color: subtext
                                    
                                    font.family: uiFont; font.pixelSize: 15
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: (modelData.bookmark ? "★ " : "") + modelData.title
                                    color: fg
                                    font.family: uiFont; font.pixelSize: 14
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: modelData.url
                                    color: subtext
                                    font.family: uiFont; font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: selected = index
                            onClicked: { selected = index; accept(); }
                        }
                    }
                }
            }
        }
    }
}
