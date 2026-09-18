// Thin pill scrollbar that stays invisible until the list is scrolled or hovered,
// then fades out again 600ms after the list stops moving.
//
// Ported from caelestia-shell components/controls/StyledScrollBar.qml, minus its
// position-sync machinery.
// ponytail: dragging the bar and scrolling with the pointer over it are handled by
// Qt's stock behaviour here rather than upstream's animated nonAnimPosition
// bookkeeping; port that back if grabbing the bar itself ever feels abrupt.
//
// Usage: ScrollBar.vertical: StyledScrollBar { flickable: theListView }
import QtQuick
import QtQuick.Templates as T
import common

T.ScrollBar {
    id: root

    required property Flickable flickable
    property bool shouldBeActive

    implicitWidth: Tokens.padding.extraSmall

    onHoveredChanged: shouldBeActive = hovered || flickable.moving

    contentItem: StyledRect {
        anchors.left: parent.left
        anchors.right: parent.right

        opacity: {
            if (root.size === 1)
                return 0;
            if (mouse.containsMouse)
                return 0.8;
            if (root.policy === T.ScrollBar.AlwaysOn || root.shouldBeActive)
                return 0.6;
            return 0;
        }

        radius: Tokens.rounding.full
        color: Colors.accent

        MouseArea {
            id: mouse

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Connections {
        function onMovingChanged(): void {
            if (root.flickable.moving)
                root.shouldBeActive = true;
            else
                hideDelay.restart();
        }

        target: root.flickable
    }

    Timer {
        id: hideDelay

        interval: 600
        onTriggered: root.shouldBeActive = root.flickable.moving || root.hovered
    }
}
