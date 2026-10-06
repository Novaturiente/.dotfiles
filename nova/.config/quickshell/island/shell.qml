//@ pragma UseQApplication
// Dynamic island — Quickshell. A pill at the top centre that shows the time,
// date and battery, and morphs into other pages on demand. Replaces the DMS bar
// on Hyprland (hyprland.lua hides the bar and starts this).
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
// output, input. Click the island to open the dashboard; click outside or press
// Esc to close (Esc on a sub-page goes back to the dashboard). On a dashboard
// tile the icon toggles, the rest opens its picker.
//
// Volume changes made anywhere flash the volume page; brightness only flashes
// when changed through here (sysfs backlight has no change signal).
//
// Adding a mode: add its name to `modes`, a Page below, and a line in `page`.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Networking
import Quickshell.Bluetooth
import QtQuick
import common

ShellRoot {
    id: root

    readonly property var modes: ["idle", "volume", "brightness", "dashboard", "tray", "battery", "wifi", "bluetooth", "output", "input"]
    readonly property var subPages: ["battery", "wifi", "bluetooth", "output", "input"]
    property string mode: "idle"
    // Anything bigger than the pill or an OSD: grabs the keyboard and closes on
    // a click outside.
    readonly property bool expanded: !["idle", "volume", "brightness"].includes(mode)
    // Which slider the OSD page shows; kept apart from `mode` so the page does
    // not switch icon while it fades out.
    property string osdKind: "volume"
    // Auto-hide (Mod+B): the pill tucks up leaving a thin strip at the top edge;
    // hovering the strip, an OSD or any open page brings it back.
    property bool autoHide: false
    property bool hovered: false
    readonly property bool tucked: autoHide && mode === "idle" && !hovered

    function show(m: string): void {
        if (!modes.includes(m))
            return;
        if (m === "volume" || m === "brightness") {
            osdKind = m;
            hideTimer.restart();
        } else {
            hideTimer.stop();
        }
        mode = m;
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

    // --- DND / night mode --------------------------------------------------
    // DND lives in the notifications daemon, night mode in DMS; both are read
    // over their IPC whenever the dashboard opens or a tile is clicked.
    property bool dnd: false
    property bool night: false
    Process {
        id: dndRead
        command: ["qs", "-c", "notifications", "ipc", "call", "notifs", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.dnd = text.startsWith("dnd on")
        }
    }
    Process {
        id: nightRead
        command: ["dms", "ipc", "call", "night", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.night = /: enabled/.test(text)
        }
    }
    Process {
        id: ipcToggle
        onExited: {
            dndRead.running = true;
            nightRead.running = true;
        }
    }
    function runToggle(cmd: var): void {
        ipcToggle.command = cmd;
        ipcToggle.running = true;
    }

    onModeChanged: {
        if (mode === "dashboard") {
            dndRead.running = true;
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
            root.setVolume(root.volume + parseFloat(arg) / 100);
        }
        function brightness(arg: string): void {
            root.stepBrightness(arg);
        }
    }

    // --- Building blocks ---------------------------------------------------
    // Inline components cannot see `root`, so they take everything as props.
    component T: Text {
        color: Colors.fg
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: Tokens.fontSize.normal
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }

    // One island page: fades in when active, sizes itself to its content.
    component Page: Item {
        property bool active
        anchors.centerIn: parent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        opacity: active ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }
    }

    // Plain slider; emits moved(0..1) on press and drag.
    component Bar: Item {
        id: bar
        property real value
        signal moved(real v)
        implicitWidth: 220
        implicitHeight: 16
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: Colors.surface1

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, bar.value))
                height: parent.height
                radius: 3
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
    }

    // Quick-settings tile: accent fill when on. The icon toggles; the body opens
    // the picker when there is one (chevron shown), else it toggles too.
    component Tile: Rectangle {
        id: tile
        property string icon
        property string title
        property string sub
        property bool on
        property bool hasPage
        signal toggled
        signal opened
        width: 220
        height: 52
        radius: Tokens.rounding.large
        color: on ? Colors.accent : Colors.surface0
        readonly property color ink: on ? Colors.base : Colors.fg

        MouseArea {
            anchors.fill: parent
            onClicked: tile.hasPage ? tile.opened() : tile.toggled()
        }
        Row {
            x: Tokens.padding.small
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small
            Rectangle {
                width: 36
                height: 36
                radius: 18
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(tile.ink, 0.12)
                T {
                    anchors.centerIn: parent
                    text: tile.icon
                    font.pixelSize: Tokens.fontSize.large
                    color: tile.ink
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
                    width: 140
                    elide: Text.ElideRight
                    font.bold: true
                    color: tile.ink
                }
                T {
                    anchors.verticalCenter: undefined
                    text: tile.sub
                    width: 140
                    elide: Text.ElideRight
                    font.pixelSize: Tokens.fontSize.smaller
                    color: tile.on ? Colors.surface1 : Colors.subtext0
                }
            }
        }
        T {
            visible: tile.hasPage
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.small
            text: String.fromCodePoint(0xF0142)
            color: tile.ink
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
            width: 44
            height: 24
            radius: 12
            color: hdr.on ? Colors.accent : Colors.surface1
            Rectangle {
                x: hdr.on ? 22 : 2
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: 10
                color: hdr.on ? Colors.base : Colors.subtext0
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
        signal clicked
        signal actionClicked
        width: 448
        height: 44
        radius: Tokens.rounding.medium
        color: active ? Colors.surface1 : hover.containsMouse ? Colors.surface0 : "transparent"

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
                    text: row.armed ? "Click again to forget" : row.sub
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
                onClicked: {
                    if (row.armed) {
                        row.armed = false;
                        disarm.stop();
                        row.actionClicked();
                    } else {
                        row.armed = true;
                        disarm.restart();
                    }
                }
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
        signal back
        signal pick(var node)

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
                Repeater {
                    model: ap.nodes
                    delegate: ListRow {
                        required property var modelData
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
        spacing: Tokens.spacing.small

        T {
            visible: SystemTray.items.values.length === 0
            text: "No tray items"
            color: Colors.subtext
        }
        Repeater {
            model: SystemTray.items
            delegate: Image {
                id: icon
                required property SystemTrayItem modelData
                width: 20
                height: 20
                sourceSize: Qt.size(20, 20)
                source: modelData.icon

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: m => {
                        const item = icon.modelData;
                        if (m.button === Qt.LeftButton && !item.onlyMenu) {
                            item.activate();
                        } else if (item.hasMenu) {
                            const p = icon.mapToItem(null, 0, 0);
                            item.display(QsWindow.window, p.x, p.y);
                        }
                    }
                }
            }
        }
    }

    // --- Windows -----------------------------------------------------------
    // Invisible strip that only reserves space at the top for the pill.
    // The island window itself is fullscreen and ignores exclusion.
    PanelWindow {
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 1
        exclusiveZone: root.autoHide ? 0 : 42
        color: "transparent"
        WlrLayershell.namespace: "island-spacer"
        mask: Region {}
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
        WlrLayershell.keyboardFocus: root.expanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: Region {
            item: root.expanded ? catcher : island
        }

        MouseArea {
            id: catcher
            anchors.fill: parent
            onClicked: root.show("idle")
        }

        Rectangle {
            id: island

            readonly property Item page: ({
                    idle: idlePage,
                    volume: osdPage,
                    brightness: osdPage,
                    dashboard: dashPage,
                    tray: trayPage,
                    battery: batPage,
                    wifi: wifiPage,
                    bluetooth: btPage,
                    output: outPage,
                    input: inPage
                })[root.mode]

            anchors.top: parent.top
            anchors.topMargin: root.tucked ? 4 - height : Tokens.spacing.small
            anchors.horizontalCenter: parent.horizontalCenter

            Behavior on anchors.topMargin {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            HoverHandler {
                onHoveredChanged: root.hovered = hovered
            }
            width: page.implicitWidth + Tokens.padding.large * 2
            height: page.implicitHeight + Tokens.padding.small * 2
            radius: Math.min(height / 2, Tokens.rounding.extraLarge)
            color: Colors.bg
            border.color: Colors.outline
            clip: true
            focus: true

            Keys.onEscapePressed: root.show(root.subPages.includes(root.mode) ? "dashboard" : "idle")

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

            // Opens the dashboard from the pill; inside open pages it just keeps
            // clicks from reaching the catcher behind.
            MouseArea {
                anchors.fill: parent
                onClicked: if (!root.expanded) root.show("dashboard")
            }

            Page {
                id: idlePage
                active: island.page === idlePage

                Row {
                    spacing: Tokens.spacing.medium
                    T {
                        text: Qt.formatDateTime(clock.date, "h:mm AP")
                        font.bold: true
                    }
                    T {
                        text: Qt.formatDateTime(clock.date, "ddd d MMM")
                        color: Colors.subtext0
                    }
                    T {
                        text: root.glyph(root.charging ? 0xF0084 : 0xF0079) + " " + root.batPct + "%"
                        color: !root.charging && root.batPct <= 15 ? Colors.red : Colors.fg
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.show("battery")
                        }
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
                        value: osdPage.value
                        onMoved: v => osdPage.isVol ? root.setVolume(v) : root.setBrightness(v)
                    }
                    T {
                        text: Math.round(osdPage.value * 100) + "%"
                        width: 40
                    }
                }
            }

            Page {
                id: dashPage
                active: island.page === dashPage

                Column {
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
                    Row {
                        spacing: Tokens.spacing.medium
                        T {
                            text: root.glyph(root.muted ? 0xF075F : 0xF057E)
                            width: 24
                            MouseArea {
                                anchors.fill: parent
                                onClicked: if (root.sink?.audio) root.sink.audio.muted = !root.muted
                            }
                        }
                        Bar {
                            width: 360
                            value: root.volume
                            onMoved: v => root.setVolume(v)
                        }
                        T {
                            text: Math.round(root.volume * 100) + "%"
                            width: 40
                        }
                    }
                    Row {
                        spacing: Tokens.spacing.medium
                        T {
                            text: root.glyph(0xF00E0)
                            width: 24
                        }
                        Bar {
                            width: 360
                            value: root.brightness
                            onMoved: v => root.setBrightness(v)
                        }
                        T {
                            text: Math.round(root.brightness * 100) + "%"
                            width: 40
                        }
                    }
                    Grid {
                        columns: 2
                        spacing: Tokens.spacing.small

                        Tile {
                            on: Networking.wifiEnabled
                            hasPage: true
                            icon: root.glyph(on ? 0xF05A9 : 0xF05AA)
                            title: root.wifiNet?.name ?? "Wi-Fi"
                            sub: root.wifiNet ? Math.round(root.wifiNet.signalStrength * 100) + "%" : (on ? "Not connected" : "Off")
                            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                            onOpened: root.show("wifi")
                        }
                        Tile {
                            on: root.btAdapter?.enabled ?? false
                            hasPage: true
                            icon: root.glyph(on ? 0xF00AF : 0xF00B2)
                            title: root.btDev?.name ?? "Bluetooth"
                            sub: !on ? "Off" : root.btDev ? (root.btDev.batteryAvailable ? Math.round(root.btDev.battery * 100) + "%" : "Connected") : "No device"
                            onToggled: if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled
                            onOpened: root.show("bluetooth")
                        }
                        Tile {
                            on: !root.muted
                            hasPage: true
                            icon: root.glyph(on ? 0xF057E : 0xF075F)
                            title: root.sink?.description ?? "Output"
                            sub: Math.round(root.volume * 100) + "%"
                            onToggled: if (root.sink?.audio) root.sink.audio.muted = !root.muted
                            onOpened: root.show("output")
                        }
                        Tile {
                            on: !(root.source?.audio?.muted ?? true)
                            hasPage: true
                            icon: root.glyph(on ? 0xF036C : 0xF036D)
                            title: root.source?.description ?? "Microphone"
                            sub: Math.round((root.source?.audio?.volume ?? 0) * 100) + "%"
                            onToggled: if (root.source?.audio) root.source.audio.muted = !root.source.audio.muted
                            onOpened: root.show("input")
                        }
                        Tile {
                            on: root.dnd
                            icon: root.glyph(on ? 0xF009B : 0xF009A)
                            title: "Do not disturb"
                            sub: on ? "On" : "Off"
                            onToggled: root.runToggle(["qs", "-c", "notifications", "ipc", "call", "notifs", "dnd"])
                        }
                        Tile {
                            on: root.night
                            icon: root.glyph(0xF0594)
                            title: "Night mode"
                            sub: on ? "On" : "Off"
                            onToggled: root.runToggle(["dms", "ipc", "call", "night", "toggle"])
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
                        Repeater {
                            model: root.wifiNets
                            delegate: ListRow {
                                required property var modelData
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
                        Repeater {
                            model: root.btDevices
                            delegate: ListRow {
                                id: btRow
                                required property var modelData
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
                            value: (root.bat?.changeRate ?? 0).toFixed(1) + " W"
                            label: "Power"
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
                Tray {}
            }
        }
    }
}
