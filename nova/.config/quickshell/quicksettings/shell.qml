//@ pragma UseQApplication
// Quick settings — wifi, bluetooth, audio and battery in one layer-shell panel,
// anchored top-right and toggled by Mod+Ctrl+S.
//
// The four panels are ported by hand from caelestia-shell's bar popouts. There
// they hang off caelestia's own bar and open on hover; this system runs
// DankMaterialShell's bar instead, so they are stacked in one resident daemon
// and toggled over IPC like every other menu in this repo.
//
// The window covers the whole screen while open, transparent except for the
// panel itself, so a click anywhere else dismisses it. Upstream got that from
// HyprlandFocusGrab, which is Hyprland-only; niri has no equivalent protocol,
// and layer-shell surfaces are never told about clicks that miss them.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import common
import quicksettings

ShellRoot {
    id: root

    // Every `qs -c <name>` is its own process, so this shrinks the tokens for
    // this daemon alone and leaves the other menus at full size.
    Component.onCompleted: Tokens.scale = 0.8

    PanelWindow {
        id: win

        // `shown` is what callers set. The window stays mapped until the close
        // animation has run out, which is what `visible` tracks.
        property bool shown: false
        property real anim: shown ? 1 : 0

        visible: shown || anim > 0

        // Full screen: the dismiss layer needs to cover everything the panel
        // does not.
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-quicksettings"

        // Clicks that reach this have missed the panel, because the panel's own
        // blocker below is stacked above it.
        MouseArea {
            anchors.fill: parent
            onClicked: win.shown = false
        }

        Rectangle {
            id: panel

            readonly property int pad: Tokens.padding.large

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.rightMargin: 8

            implicitWidth: Tokens.sizes.bar.networkWidth + pad * 2
            // Cap at most of the screen so a long network list scrolls instead
            // of running off the bottom.
            implicitHeight: Math.min(parent.height - 80, content.implicitHeight + pad * 2)
            width: implicitWidth
            height: implicitHeight

            // Same motion as the other menus: expressive-fast on the way in,
            // which overshoots slightly and settles, and the quicker effects
            // curve on the way out, because a panel that bounces while closing
            // reads as a glitch.
            transform: Scale {
                origin.x: panel.width
                origin.y: 0
                xScale: win.anim
                yScale: win.anim
            }
            opacity: Math.min(1, win.anim)

            radius: Tokens.rounding.large
            color: Colors.bg
            border.color: Colors.outline
            border.width: 1

            focus: true
            Keys.onEscapePressed: {
                // The password dialog takes escape first, if it is up.
                if (popouts.currentName === "wirelesspassword")
                    popouts.currentName = "network";
                else
                    win.shown = false;
            }

            // Absorbs clicks that land on the panel but miss a control, so they
            // never reach the dismiss layer underneath. Declared first, which
            // puts it below every control here.
            MouseArea {
                anchors.fill: parent
            }

            Flickable {
                id: flick

                anchors.fill: parent
                anchors.margins: panel.pad
                contentHeight: content.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                visible: popouts.currentName !== "wirelesspassword"

                ScrollBar.vertical: StyledScrollBar {
                    flickable: flick
                }

                ColumnLayout {
                    id: content

                    width: flick.width
                    spacing: Tokens.spacing.largeIncreased

                    NetworkPanel {
                        id: network

                        Layout.fillWidth: true
                        popouts: popouts
                    }

                    Separator {}

                    BluetoothPanel {
                        Layout.fillWidth: true
                        popouts: popouts
                    }

                    Separator {}

                    AudioPanel {
                        Layout.fillWidth: true
                        popouts: popouts
                    }

                    Separator {}

                    BatteryPanel {
                        Layout.fillWidth: true
                    }
                }
            }

            // The password prompt replaces the whole panel while it is up, the
            // way it replaces the popout upstream.
            WirelessPassword {
                anchors.fill: parent
                anchors.margins: panel.pad
                visible: popouts.currentName === "wirelesspassword"
                popouts: popouts
                network: network.passwordNetwork
            }
        }
    }

    // Shared by the network panel and its password prompt, which is the only
    // thing this object still coordinates now that there is no popout row.
    PopoutState {
        id: popouts

        currentName: "network"
        hasCurrent: win.shown
    }

    IpcHandler {
        target: "quicksettings"

        function toggle(): void {
            if (win.shown) {
                win.shown = false;
                return;
            }
            open();
        }

        function open(): void {
            popouts.currentName = "network";
            win.shown = true;
            // NetworkManager's scan results go stale within a minute or two, and
            // on a cold daemon start the list is still empty. Kick a scan every
            // time the panel opens so it is never showing nothing.
            Nmcli.rescanWifi();
        }

        function close(): void {
            win.shown = false;
        }
    }

    component Separator: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Colors.outline
    }
}
