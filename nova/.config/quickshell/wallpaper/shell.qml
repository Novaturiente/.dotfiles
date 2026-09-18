//@ pragma UseQApplication
// Wallpaper picker — Quickshell. Bound to Mod+Alt+W. Resident daemon, toggled over IPC.
//
// Coverflow of every image in ~/Pictures (top level only). Left/Right move the
// stack, Enter runs `dms ipc call wallpaper set <path>`, Escape closes.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel
import common

ShellRoot {
    id: root

    // ponytail: FolderListModel instead of a shell script — the folder listing
    // is a native QML type, so there is no process to spawn or parse.
    readonly property string folder: "file://" + Quickshell.env("HOME") + "/Pictures"

    readonly property color bg:      Colors.bg
    readonly property color outline: Colors.outline
    readonly property color accent:  Colors.accent
    readonly property color fg:      Colors.fg
    readonly property color subtext: Colors.subtext
    readonly property string uiFont: "JetBrainsMono Nerd Font"

    property string current: ""

    FolderListModel {
        id: files
        folder: root.folder
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    Process {
        id: reader
        command: ["dms", "ipc", "call", "wallpaper", "get"]
        stdout: StdioCollector { onStreamFinished: current = text.trim() }
    }

    Process { id: setter }

    function apply(path) {
        if (!path) return;
        setter.command = ["dms", "ipc", "call", "wallpaper", "set", path];
        setter.running = true;
        current = path;
        win.visible = false;
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            if (win.visible) { win.visible = false; return; }
            reader.running = true;
            win.visible = true;
        }
    }

    PanelWindow {
        id: win
        visible: false
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-wallpaper"

        property real anim: 0
        Behavior on anim { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        onVisibleChanged: {
            anim = visible ? 1 : 0;
            if (visible) Qt.callLater(function () {
                keys.forceActiveFocus();
                // Land on the wallpaper that is already set.
                for (var i = 0; i < files.count; i++)
                    if (files.get(i, "filePath") === current) { flow.currentIndex = i; return; }
            });
        }

        // Scrim. Clicking it closes, like the other menus' Escape.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55 * win.anim)
            MouseArea { anchors.fill: parent; onClicked: win.visible = false }
        }

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Escape) { win.visible = false; e.accepted = true; }
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_L) { flow.incrementCurrentIndex(); e.accepted = true; }
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_H) { flow.decrementCurrentIndex(); e.accepted = true; }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    apply(files.count ? files.get(flow.currentIndex, "filePath") : ""); e.accepted = true;
                }
            }

            // ponytail: PathView is Qt's built-in carousel — the stacked-card
            // look is a path plus scale/z/opacity attributes, not custom paint.
            PathView {
                id: flow
                anchors.fill: parent
                opacity: win.anim
                model: files
                pathItemCount: 5
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                snapMode: PathView.SnapOneItem
                movementDirection: PathView.Shortest
                highlightMoveDuration: 220
                dragMargin: width

                readonly property real cardW: Math.min(720, win.width * 0.46)
                readonly property real cardH: cardW * 9 / 16

                // Five stops, so the neighbours tuck behind the centre card
                // instead of sitting beside it: each step out is a shorter
                // hop, smaller and dimmer, which reads as a deck.
                path: Path {
                    startX: flow.width / 2 - flow.cardW * 0.88
                    startY: flow.height / 2
                    PathAttribute { name: "iScale"; value: 0.58 }
                    PathAttribute { name: "iOpacity"; value: 0.28 }
                    PathAttribute { name: "iZ"; value: 0 }
                    PathLine { x: flow.width / 2 - flow.cardW * 0.52; y: flow.height / 2 }
                    PathAttribute { name: "iScale"; value: 0.78 }
                    PathAttribute { name: "iOpacity"; value: 0.62 }
                    PathAttribute { name: "iZ"; value: 50 }
                    PathLine { x: flow.width / 2; y: flow.height / 2 }
                    PathAttribute { name: "iScale"; value: 1.0 }
                    PathAttribute { name: "iOpacity"; value: 1.0 }
                    PathAttribute { name: "iZ"; value: 100 }
                    PathLine { x: flow.width / 2 + flow.cardW * 0.52; y: flow.height / 2 }
                    PathAttribute { name: "iScale"; value: 0.78 }
                    PathAttribute { name: "iOpacity"; value: 0.62 }
                    PathAttribute { name: "iZ"; value: 50 }
                    PathLine { x: flow.width / 2 + flow.cardW * 0.88; y: flow.height / 2 }
                    PathAttribute { name: "iScale"; value: 0.58 }
                    PathAttribute { name: "iOpacity"; value: 0.28 }
                    PathAttribute { name: "iZ"; value: 0 }
                }

                delegate: Item {
                    required property string filePath
                    required property string fileName
                    required property int index

                    width: flow.cardW
                    height: flow.cardH
                    scale: PathView.iScale === undefined ? 0.58 : PathView.iScale
                    opacity: PathView.iOpacity === undefined ? 0.28 : PathView.iOpacity
                    z: PathView.iZ === undefined ? 0 : PathView.iZ

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: bg
                        border.color: index === flow.currentIndex ? accent : outline
                        border.width: index === flow.currentIndex ? 2 : 1
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            source: "file://" + filePath
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            // Decode at card size; the originals are multi-megapixel.
                            sourceSize.width: Math.round(flow.cardW)
                        }

                        // Marks the wallpaper that is already set.
                        Rectangle {
                            visible: filePath === current
                            anchors.top: parent.top; anchors.right: parent.right
                            anchors.margins: 8
                            width: 26; height: 26; radius: 13
                            color: accent
                            Text {
                                anchors.centerIn: parent
                                text: "✓"; color: bg
                                font.family: uiFont; font.pixelSize: 14
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: index === flow.currentIndex ? apply(filePath) : flow.currentIndex = index
                    }
                }
            }

            // Filename of the centre card, plus the key hints.
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.max(40, win.height * 0.12)
                spacing: 6
                opacity: win.anim

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: files.count ? files.get(flow.currentIndex, "fileName") : "no images in ~/Pictures"
                    color: fg; font.family: uiFont; font.pixelSize: 15
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: files.count ? "←/→ browse   ⏎ set   esc close   ("
                          + (flow.currentIndex + 1) + "/" + files.count + ")" : ""
                    color: subtext; font.family: uiFont; font.pixelSize: 12
                }
            }
        }
    }
}
