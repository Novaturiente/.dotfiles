//@ pragma UseQApplication
// App launcher (drun) — Quickshell. Replaces `rofi -show drun -theme spotlight`.
// Bound to Mod+D. Resident daemon, toggled over IPC.
//
// scripts/quickshell/applaunch.sh: list (JSON, most-used first) / launch <file>.
// Icons resolve via Quickshell.iconPath(name). Enter or click launches + hides.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ShellRoot {
    id: root
    readonly property string applaunch: Quickshell.env("HOME") + "/.dotfiles/scripts/quickshell/applaunch.sh"

    // Space-galaxy palette
    readonly property color bg:      "#e61e1e2e"
    readonly property color inputBg: "#d0313244"
    readonly property color outline: "#45475a"
    readonly property color accent:  "#cba6f7"   // mauve
    readonly property color selBg:   "#45475a"   // surface1
    readonly property color fg:      "#cdd6f4"
    readonly property color subtext: "#7f849c"
    readonly property string uiFont: "JetBrainsMono Nerd Font"

    property var apps: []          // [{id,name,icon,file}]

    Process {
        id: lister
        command: ["bash", applaunch, "list"]
        stdout: StdioCollector { onStreamFinished: { try { apps = JSON.parse(text); } catch (e) { apps = []; } } }
    }
    Process { id: launcher }
    function reload() { lister.running = true; }
    function launch(file) {
        launcher.command = ["bash", applaunch, "launch", file];
        launcher.running = true;
        win.visible = false;
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (win.visible) { win.visible = false; return; }
            search.text = ""; reload(); win.visible = true;
        }
    }
    Component.onCompleted: reload()

    PanelWindow {
        id: win
        visible: false
        anchors { top: false; bottom: false; left: false; right: false }
        implicitWidth: 680
        readonly property int maxH: 560
        implicitHeight: Math.min(maxH, 104 + Math.max(1, appList.count) * 52)
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-launcher"

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

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // search
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 50; radius: 0
                    color: inputBg; border.color: accent; border.width: 1
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 10
                        Text { text: ""; color: accent; font.family: uiFont; font.pixelSize: 20 }
                        TextField {
                            id: search
                            Layout.fillWidth: true; focus: true
                            color: fg; font.family: uiFont; font.pixelSize: 17; background: null
                            placeholderText: "Search applications…"
                            placeholderTextColor: subtext
                            onTextChanged: appList.currentIndex = 0
                            Keys.onPressed: (e) => {
                                if (e.key === Qt.Key_Escape) { win.visible = false; e.accepted = true; }
                                else if (e.key === Qt.Key_Down) { appList.incrementCurrentIndex(); e.accepted = true; }
                                else if (e.key === Qt.Key_Up)   { appList.decrementCurrentIndex(); e.accepted = true; }
                                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                    var m = appList.currentItem ? appList.currentItem.rowData : null;
                                    if (m) launch(m.file);
                                    e.accepted = true;
                                }
                            }
                        }
                        Text { text: appList.count + ""; color: subtext; font.family: uiFont; font.pixelSize: 13 }
                    }
                }

                ListView {
                    id: appList
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { }
                    model: {
                        var qy = search.text.toLowerCase();
                        if (qy === "") return apps;
                        var out = [];
                        for (var i = 0; i < apps.length; i++)
                            if (apps[i].name.toLowerCase().indexOf(qy) !== -1) out.push(apps[i]);
                        return out;
                    }
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        property var rowData: modelData
                        width: ListView.view.width; height: 52; radius: 0
                        color: index === appList.currentIndex ? selBg : "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 14
                            Image {
                                Layout.preferredWidth: 32; Layout.preferredHeight: 32
                                source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                sourceSize.width: 32; sourceSize.height: 32
                                fillMode: Image.PreserveAspectFit
                            }
                            Text { text: modelData.name; color: fg; font.family: uiFont; font.pixelSize: 16
                                   Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                        MouseArea { anchors.fill: parent; hoverEnabled: true
                            onEntered: appList.currentIndex = index
                            onClicked: launch(modelData.file) }
                    }
                }
            }
        }
    }
}
