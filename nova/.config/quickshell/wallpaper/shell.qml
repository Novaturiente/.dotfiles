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
        // Island draws the wallpaper under Hyprland; DMS under niri.
        command: ["sh", "-c", "qs -c island ipc call island getWallpaper 2>/dev/null || dms ipc call wallpaper get"]
        stdout: StdioCollector { onStreamFinished: current = text.trim() }
    }

    Process { id: setter }

    function apply(path) {
        if (!path) return;
        setter.command = ["sh", "-c", "qs -c island ipc call island setWallpaper \"$1\" 2>/dev/null || dms ipc call wallpaper set \"$1\"", "sh", path];
        setter.running = true;
        current = path;
        win.shown = false;
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            if (win.shown) { win.shown = false; return; }
            reader.running = true;
            win.shown = true;
        }
    }

    PanelWindow {
        id: win
        // `shown` is what callers set. The window stays mapped until the close
        // animation has run out, which is what `visible` tracks.
        property bool shown: false
        visible: shown || anim > 0
        // ponytail: no resident daemon; quit once hidden and idle (Qt.quit kills running Processes)
        onVisibleChanged: if (!visible) quitter.start()
        Timer { id: quitter; interval: 200; repeat: true; onTriggered: if (win.visible) stop(); else if (!(reader.running || setter.running)) Qt.quit() }
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-wallpaper"

        property real anim: shown ? 1 : 0
        // Opening rides caelestia's expressive fast-spatial curve, which overshoots a
        // touch and settles. Closing rides the effects curve instead: it is quicker and
        // does not overshoot, because a panel that bounces on its way out reads as a
        // glitch. Anim.DefaultSpatial (500ms) is what upstream's launcher uses for the
        // open; that felt slow for menus opened this often.
        Behavior on anim { Anim { type: win.shown ? Anim.FastSpatial : Anim.FastEffects } }
        onShownChanged: {
            if (shown) Qt.callLater(function () {
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
            MouseArea { anchors.fill: parent; onClicked: win.shown = false }
        }

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Escape) { win.shown = false; e.accepted = true; }
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
