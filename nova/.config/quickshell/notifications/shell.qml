//@ pragma UseQApplication
// Notification popups — Quickshell. Replaces DankMaterialShell's notification
// popups; see CLAUDE.md for why the two cannot both run.
//
// This daemon owns org.freedesktop.Notifications, so it must start before DMS.
// Popups only: there is no notification centre and no history. Once a card is
// dismissed or expires it is gone.
//
// IPC (`qs -c notifications ipc call notifs <fn>`):
//   dnd     toggle do-not-disturb, returns the new state
//   status  report whether do-not-disturb is on, and how many cards are up
//   clear   dismiss everything currently on screen
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import common

ShellRoot {
    id: root

    // Cards currently on screen, oldest first. Plain array plus ScriptModel so the
    // Repeater diffs it instead of rebuilding every delegate on each change.
    property var popups: []
    property bool dnd: false

    readonly property int cardWidth: 430
    readonly property int edgeMargin: Tokens.padding.medium

    function push(n: var): void {
        popups = popups.concat([n]);
    }

    // Called once a card's exit animation has finished.
    function drop(n: var): void {
        popups = popups.filter(x => x !== n);
        if (n)
            n.dismiss();
    }

    NotificationServer {
        id: server

        // Nothing survives a reload, because nothing is persisted in the first place.
        keepOnReload: false
        persistenceSupported: false

        actionsSupported: true
        actionIconsSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        inlineReplySupported: false

        onNotification: n => {
            // Without this the server drops the notification as soon as the signal
            // handler returns.
            n.tracked = true;

            // Do-not-disturb still lets critical through, as the spec expects.
            if (root.dnd && n.urgency !== NotificationUrgency.Critical) {
                n.dismiss();
                return;
            }

            root.push(n);
        }
    }

    IpcHandler {
        target: "notifs"

        function dnd(): string {
            root.dnd = !root.dnd;
            return root.dnd ? "on" : "off";
        }

        function status(): string {
            return (root.dnd ? "dnd on" : "dnd off") + ", " + root.popups.length + " showing";
        }

        function clear(): void {
            for (const n of root.popups)
                n.dismiss();
            root.popups = [];
        }
    }

    PanelWindow {
        id: win

        // Only mapped while something is showing, so it never sits in the way.
        visible: root.popups.length > 0
        anchors { top: true; right: true }
        margins { top: root.edgeMargin; right: root.edgeMargin }

        implicitWidth: root.cardWidth
        // A zero-height layer surface is not valid, hence the floor of 1.
        implicitHeight: Math.max(1, stack.implicitHeight)

        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-notifications"
        // Popups never take the keyboard; they are clicked, not typed into.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // Sit below the bar rather than under it, without reserving space itself.
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0

        Column {
            id: stack

            width: parent.width
            spacing: Tokens.spacing.medium

            // Cards sliding up as one above them is dismissed.
            move: Transition {
                Anim {
                    property: "y"
                }
            }

            add: Transition {
                Anim {
                    property: "y"
                }
            }

            Repeater {
                model: ScriptModel {
                    values: root.popups
                }

                NotifCard {
                    implicitWidth: root.cardWidth
                    onDismissed: root.drop(modelData)
                }
            }
        }
    }
}
