//@ pragma UseQApplication
// Window switcher — Quickshell. Replaces scripts/rofi/windows.sh. Bound to Mod+Tab.
// Uses the Wayland foreign-toplevel list (no external process). Single-column
// list: app icon + title + app_id. Enter/click focuses (toplevel.activate()).
// (niri has no per-window screencopy, so no live preview — list only.)
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ShellRoot {
    id: root

    // Space-galaxy palette
    readonly property color bg:      "#e61e1e2e"
    readonly property color inputBg: "#d0313244"
    readonly property color outline: "#45475a"
    readonly property color accent:  "#cba6f7"   // mauve
    readonly property color selBg:   "#45475a"   // surface1
    readonly property color fg:      "#cdd6f4"
    readonly property color subtext: "#7f849c"
    readonly property string uiFont: "JetBrainsMono Nerd Font"

    property int sel: 0
    property string filter: ""

    readonly property var rows: {
        var all = ToplevelManager.toplevels.values;
        var qy = filter.toLowerCase();
        var out = [];
        for (var i = 0; i < all.length; i++) {
            var t = all[i];
            if (qy === "" || ((t.title || "") + " " + (t.appId || "")).toLowerCase().indexOf(qy) !== -1) out.push(t);
        }
        return out;
    }
    function activate(t) { if (t) t.activate(); win.visible = false; }

    IpcHandler {
        target: "switcher"
        function toggle(): void {
            if (win.visible) { win.visible = false; return; }
            search.text = "";                               // clear stale filter text (onTextChanged resets filter+sel)
            sel = (rows.length > 1 ? 1 : 0);                // preselect previous window
            win.visible = true;
        }
    }

    PanelWindow {
        id: win
        visible: false
        anchors { top: false; bottom: false; left: false; right: false }
        implicitWidth: 760
        readonly property int maxH: 600
        implicitHeight: Math.min(maxH, 92 + Math.max(1, list.count) * 54)
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-switcher"

        onVisibleChanged: if (visible) Qt.callLater(function () { search.forceActiveFocus(); })

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

                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 48; radius: 0
                    color: inputBg; border.color: accent; border.width: 1
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 10
                        Text { text: ""; color: accent; font.family: uiFont; font.pixelSize: 18 }
                        TextField {
                            id: search
                            Layout.fillWidth: true; focus: true
                            color: fg; font.family: uiFont; font.pixelSize: 16; background: null
                            placeholderText: "Switch window…"
                            placeholderTextColor: subtext
                            onTextChanged: { filter = text; sel = 0; }
                            Keys.onPressed: (e) => {
                                if (e.key === Qt.Key_Escape) { win.visible = false; e.accepted = true; }
                                else if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) {
                                    if (rows.length) sel = (sel + 1) % rows.length; e.accepted = true;
                                } else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || (e.key === Qt.Key_Tab && (e.modifiers & Qt.ShiftModifier))) {
                                    if (rows.length) sel = (sel - 1 + rows.length) % rows.length; e.accepted = true;
                                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                    activate(rows.length ? rows[sel] : null); e.accepted = true;
                                }
                            }
                        }
                        Text { text: rows.length + ""; color: subtext; font.family: uiFont; font.pixelSize: 13 }
                    }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { }
                    model: rows
                    currentIndex: sel
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        width: ListView.view.width; height: 54; radius: 0
                        color: index === sel ? selBg : "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 14
                            Image {
                                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                source: Quickshell.iconPath(modelData.appId, "application-x-executable")
                                sourceSize.width: 30; sourceSize.height: 30; fillMode: Image.PreserveAspectFit
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text { text: modelData.title || "(untitled)"; color: fg; font.family: uiFont; font.pixelSize: 15
                                       elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: modelData.appId || ""; color: index === sel ? fg : subtext; font.family: uiFont; font.pixelSize: 12
                                       elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                        }
                        MouseArea { anchors.fill: parent; hoverEnabled: true
                            onEntered: sel = index
                            onClicked: activate(modelData) }
                    }
                }
            }
        }
    }
}
