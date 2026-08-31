//@ pragma UseQApplication
// Keybindings cheat-sheet — Quickshell. Replaces scripts/keybindings/keybindings.sh
// (rofi). Big window: app tabs on the left, that app's keybindings on the right.
// Bound to Mod+Shift+Slash. Resident daemon, toggled over IPC.
//
// Data + extraction live in scripts/quickshell/kbctl.sh:
//   refresh -> re-run the per-app extractors (correct config paths)
//   list    -> JSON [{app, count, bindings:[{key,desc}]}]
// Enter copies the highlighted "key  desc" to the clipboard.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ShellRoot {
    id: root
    readonly property string kbctl: Quickshell.env("HOME") + "/.dotfiles/scripts/quickshell/kbctl.sh"

    // Space-galaxy palette
    readonly property color bg:      "#e61e1e2e"
    readonly property color inputBg: "#d0313244"
    readonly property color outline: "#45475a"
    readonly property color accent:  "#cba6f7"   // mauve
    readonly property color selBg:   "#45475a"   // surface1
    readonly property color fg:      "#cdd6f4"
    readonly property color subtext: "#7f849c"
    readonly property string uiFont: "JetBrainsMono Nerd Font"

    property var apps: []          // [{app,count,bindings:[{key,desc}]}]
    property int curApp: 0

    // ── process plumbing ──────────────────────────────────────────────────
    Process {
        id: lister
        command: ["bash", kbctl, "list"]
        stdout: StdioCollector { onStreamFinished: {
            try { var a = JSON.parse(text); if (a.length) { apps = a; if (curApp >= a.length) curApp = 0; } }
            catch (e) {}
        } }
    }
    Process {
        id: refresher
        command: ["bash", kbctl, "refresh"]
        stdout: StdioCollector { onStreamFinished: lister.running = true }
    }
    function loadFast() { lister.running = true; }
    function refresh()  { refresher.running = true; }        // chains to list on finish
    Process { id: copier }
    function copyLine(s) { copier.command = ["bash", "-c", "printf %s " + JSON.stringify(s) + " | wl-copy"]; copier.running = true; }

    IpcHandler {
        target: "kb"
        function toggle(): void {
            if (win.visible) { win.visible = false; return; }
            curApp = 0; search.text = "";        // reset to first app tab + clear filter
            loadFast(); refresh(); win.visible = true;
        }
    }
    Component.onCompleted: refresh()   // prime at daemon boot

    readonly property var curBindings: (apps.length && apps[curApp]) ? apps[curApp].bindings : []

    PanelWindow {
        id: win
        visible: false
        anchors { top: false; bottom: false; left: false; right: false }
        implicitWidth: 1240
        implicitHeight: 820
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-keybindings"

        // ponytail: open-only expand-from-centre; close hides instantly
        property real anim: 0
        Behavior on anim { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        onVisibleChanged: { anim = visible ? 1 : 0; if (visible) Qt.callLater(function () { search.forceActiveFocus(); }) }

        Rectangle {
            anchors.fill: parent
            transform: Scale { origin.y: win.height / 2; yScale: win.anim }
            radius: 4
            color: bg
            border.color: outline
            border.width: 1

            // ═══ LEFT: app tabs (fixed-width anchored pane) ═════════════════
            ColumnLayout {
                id: leftPane
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 16 }
                width: 240
                spacing: 4
                Text { text: "󰌌  Keybindings"; color: accent; font.family: uiFont; font.pixelSize: 18; font.bold: true; Layout.bottomMargin: 8 }
                Repeater {
                    model: apps
                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 46; radius: 0
                        color: index === curApp ? selBg : (tabMa.containsMouse ? inputBg : "transparent")
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                            Text { text: modelData.app; color: fg; font.family: uiFont; font.pixelSize: 16; Layout.fillWidth: true }
                            Text { text: modelData.count; color: index === curApp ? fg : subtext; font.family: uiFont; font.pixelSize: 13 }
                        }
                        MouseArea { id: tabMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: { curApp = index; search.text = ""; search.forceActiveFocus(); } }
                    }
                }
                Item { Layout.fillHeight: true }
                Text { text: "Tab / Shift+Tab switch\nEnter copy · Esc close"; color: subtext; font.family: uiFont; font.pixelSize: 11; Layout.fillWidth: true }
            }

            Rectangle { anchors { left: leftPane.right; leftMargin: 12; top: parent.top; bottom: parent.bottom; topMargin: 16; bottomMargin: 16 }
                        width: 1; color: outline }

            // ═══ RIGHT: search + bindings (anchored, fills remaining width) ══
            ColumnLayout {
                anchors { left: leftPane.right; leftMargin: 25; right: parent.right; top: parent.top; bottom: parent.bottom
                          rightMargin: 16; topMargin: 16; bottomMargin: 16 }
                spacing: 10

                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 48; radius: 0
                        color: inputBg; border.color: accent; border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                            Text { text: ""; color: accent; font.family: uiFont; font.pixelSize: 17 }
                            TextField {
                                id: search
                                Layout.fillWidth: true; focus: true
                                color: fg; font.family: uiFont; font.pixelSize: 16; background: null
                                placeholderText: (apps.length ? apps[curApp].app : "") + " — filter keys or actions…"
                                placeholderTextColor: subtext
                                onTextChanged: kbList.currentIndex = 0
                                Keys.onPressed: (e) => {
                                    if (e.key === Qt.Key_Escape) { win.visible = false; e.accepted = true; }
                                    else if (e.key === Qt.Key_Down) { kbList.incrementCurrentIndex(); e.accepted = true; }
                                    else if (e.key === Qt.Key_Up)   { kbList.decrementCurrentIndex(); e.accepted = true; }
                                    else if (e.key === Qt.Key_Backtab || (e.key === Qt.Key_Tab && (e.modifiers & Qt.ShiftModifier))) {
                                        if (apps.length) { curApp = (curApp - 1 + apps.length) % apps.length; search.text = ""; } e.accepted = true;
                                    } else if (e.key === Qt.Key_Tab) {
                                        if (apps.length) { curApp = (curApp + 1) % apps.length; search.text = ""; } e.accepted = true;
                                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                        var m = kbList.currentItem ? kbList.currentItem.rowData : null;
                                        if (m) copyLine(m.key + "  " + m.desc);
                                        e.accepted = true;
                                    }
                                }
                            }
                            Text { text: kbList.count + ""; color: subtext; font.family: uiFont; font.pixelSize: 13 }
                        }
                    }

                    ListView {
                        id: kbList
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { }
                        model: {
                            var qy = search.text.toLowerCase();
                            var out = [];
                            for (var i = 0; i < curBindings.length; i++) {
                                var b = curBindings[i];
                                if (qy === "" || (b.key + " " + b.desc).toLowerCase().indexOf(qy) !== -1) out.push(b);
                            }
                            return out;
                        }
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            property var rowData: modelData
                            width: ListView.view.width; height: 38; radius: 0
                            color: index === kbList.currentIndex ? selBg : (index % 2 ? "#14cdd6f4" : "transparent")
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 16
                                Text { text: modelData.key; color: index === kbList.currentIndex ? fg : accent; font.family: uiFont; font.pixelSize: 14
                                       Layout.preferredWidth: 260; elide: Text.ElideRight }
                                Text { text: modelData.desc; color: fg; font.family: uiFont; font.pixelSize: 14
                                       Layout.fillWidth: true; elide: Text.ElideRight }
                            }
                            MouseArea { anchors.fill: parent; hoverEnabled: true
                                onEntered: kbList.currentIndex = index
                                onClicked: copyLine(modelData.key + "  " + modelData.desc) }
                        }
                    }
                }
            }
        }
    }
