//@ pragma UseQApplication
// Clipboard manager — Quickshell frontend for cliphist, with image previews.
// Bound to Mod+V (replaces the DMS clipboard). Resident daemon, toggled over IPC.
//
// scripts/quickshell/clipctl.sh: list (JSON, images decoded to cache) / copy / delete.
// Enter or click copies the entry back to the clipboard; Delete removes it.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ShellRoot {
    id: root
    readonly property string clipctl: Quickshell.env("HOME") + "/.dotfiles/scripts/quickshell/clipctl.sh"

    // Space-galaxy palette
    readonly property color bg:      "#e61e1e2e"
    readonly property color inputBg: "#d0313244"
    readonly property color outline: "#45475a"
    readonly property color accent:  "#cba6f7"   // mauve
    readonly property color selBg:   "#45475a"   // surface1
    readonly property color fg:      "#cdd6f4"
    readonly property color subtext: "#7f849c"
    readonly property string uiFont: "JetBrainsMono Nerd Font"

    property var entries: []       // [{id,image,text,thumb}]

    Process {
        id: lister
        command: ["bash", clipctl, "list"]
        stdout: StdioCollector { onStreamFinished: { try { entries = JSON.parse(text); } catch (e) { entries = []; } } }
    }
    Process { id: doer }
    function reload() { lister.running = true; }
    function copy(id)   { doer.command = ["bash", clipctl, "copy", id]; doer.running = true; win.visible = false; }
    function del(id)    { doer.command = ["bash", clipctl, "delete", id]; doer.running = true; reload(); }

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            if (win.visible) { win.visible = false; return; }
            search.text = ""; clipList.currentIndex = 0; reload(); win.visible = true;
        }
    }
    Component.onCompleted: reload()

    readonly property var rows: {
        var qy = search.text.toLowerCase();
        if (qy === "") return entries;
        var out = [];
        for (var i = 0; i < entries.length; i++)
            if ((entries[i].text || "").toLowerCase().indexOf(qy) !== -1) out.push(entries[i]);
        return out;
    }
    // quick-pick / activate by absolute index (Alt+1..0, Enter, click)
    function pick(i) { if (i >= 0 && i < rows.length) copy(rows[i].id); }

    PanelWindow {
        id: win
        visible: false
        anchors { top: false; bottom: false; left: false; right: false }
        implicitWidth: 720
        implicitHeight: 640
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-clipboard"

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
                            placeholderText: "Search clipboard…  (Enter copy · Del remove)"
                            placeholderTextColor: subtext
                            onTextChanged: clipList.currentIndex = 0
                            Keys.onPressed: (e) => {
                                if (e.key === Qt.Key_Escape) { win.visible = false; e.accepted = true; }
                                else if (e.key === Qt.Key_Down) { clipList.incrementCurrentIndex(); e.accepted = true; }
                                else if (e.key === Qt.Key_Up)   { clipList.decrementCurrentIndex(); e.accepted = true; }
                                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                    pick(clipList.currentIndex); e.accepted = true;
                                } else if (e.key === Qt.Key_Delete || (e.key === Qt.Key_D && (e.modifiers & Qt.ControlModifier))) {
                                    if (rows.length && rows[clipList.currentIndex]) del(rows[clipList.currentIndex].id); e.accepted = true;
                                } else if ((e.modifiers & Qt.AltModifier) && e.key >= Qt.Key_1 && e.key <= Qt.Key_9) {
                                    pick(e.key - Qt.Key_1); e.accepted = true;            // Alt+1..9 -> item 1..9
                                } else if ((e.modifiers & Qt.AltModifier) && e.key === Qt.Key_0) {
                                    pick(9); e.accepted = true;                            // Alt+0 -> item 10
                                }
                            }
                        }
                        Text { text: rows.length + ""; color: subtext; font.family: uiFont; font.pixelSize: 13 }
                    }
                }

                ListView {
                    id: clipList
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { }
                    model: rows
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    spacing: 2
                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        width: ListView.view.width
                        height: modelData.image ? 104 : 46
                        radius: 0
                        color: index === clipList.currentIndex ? selBg : (index % 2 ? "#14cdd6f4" : "transparent")

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
                            // index badge
                            Text { text: (index + 1); color: subtext; font.family: uiFont; font.pixelSize: 11
                                   Layout.preferredWidth: 28 }

                            // image preview OR text
                            Loader {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                sourceComponent: modelData.image ? imgComp : txtComp
                                Component {
                                    id: imgComp
                                    RowLayout {
                                        spacing: 12
                                        Image {
                                            Layout.preferredHeight: 88; Layout.preferredWidth: 140
                                            source: modelData.thumb ? "file://" + modelData.thumb : ""
                                            fillMode: Image.PreserveAspectFit
                                            horizontalAlignment: Image.AlignLeft
                                            sourceSize.height: 176; asynchronous: true
                                        }
                                        Text { text: modelData.text.replace(/^\[\[ binary data /, "").replace(/ \]\]$/, "")
                                               color: index === clipList.currentIndex ? fg : subtext; font.family: uiFont; font.pixelSize: 12
                                               Layout.fillWidth: true; verticalAlignment: Text.AlignVCenter }
                                    }
                                }
                                Component {
                                    id: txtComp
                                    Text {
                                        text: modelData.text; color: fg; font.family: uiFont; font.pixelSize: 14
                                        elide: Text.ElideRight; maximumLineCount: 1
                                        verticalAlignment: Text.AlignVCenter; anchors.fill: parent
                                    }
                                }
                            }
                        }
                        MouseArea { anchors.fill: parent; hoverEnabled: true
                            onEntered: clipList.currentIndex = index
                            onClicked: copy(modelData.id) }
                    }
                }
            }
        }
    }
}
