// Material 3 slider: a filled track, a tall pill handle that stretches on press,
// and a remaining-track stub. Emits interaction(value) on drag and on click.
//
// Ported from caelestia-shell components/controls/StyledSlider.qml.
// ponytail: upstream's wavy-line variant needs the C++ WavyLine type and no
// panel here uses it, so only the straight fill is kept. CUtils.clamp is inlined.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Templates
import common

Slider {
    id: root

    property int radius: Tokens.rounding.medium
    property bool interactionOnMove: true
    readonly property bool dragging: mouse.pressed

    property color fgColour: enabled ? Colors.m3primary : Qt.alpha(Colors.m3onSurface, 0.38)
    property color bgColour: enabled ? Colors.m3secondaryContainer : Qt.alpha(Colors.m3onSurface, 0.1)

    property real pos: visualPosition
    property real filledWidth

    signal interaction(v: real)

    function clamp01(v) {
        return Math.max(0, Math.min(1, v));
    }

    // Assigned rather than declared so the drag Binding below can take over.
    Component.onCompleted: filledWidth = Qt.binding(() => (width - handle.implicitWidth - handle.anchors.leftMargin) * pos)

    implicitWidth: 200
    implicitHeight: 12

    contentItem: Item {
        anchors.fill: parent

        StyledRect {
            id: remaining

            anchors.left: handle.right
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.spacing.extraSmall

            implicitHeight: parent.height * (parent.height <= 12 ? opacity : Math.min(opacity * 2, 1))
            // Fades the stub out as the handle approaches the end.
            opacity: Math.min(width, 12) / 12

            radius: root.radius
            topLeftRadius: Tokens.rounding.extraSmall / 2
            bottomLeftRadius: Tokens.rounding.extraSmall / 2
            color: root.bgColour
        }

        // The dot at the far end of the track.
        StyledRect {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 4 * remaining.opacity

            implicitWidth: implicitHeight
            implicitHeight: 4 * remaining.opacity
            opacity: remaining.opacity

            radius: Tokens.rounding.full
            color: root.fgColour
        }

        StyledRect {
            id: handle

            anchors.left: filled.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.spacing.extraSmall

            implicitWidth: 4
            implicitHeight: {
                // Taller sliders get a proportionally shorter handle.
                const t = Math.max(0, Math.min(1, (parent.height - 12) / 16));
                const lerp = (a, b) => a + (b - a) * t;
                return parent.height * (mouse.pressed ? lerp(3.5, 1.5) : lerp(3, 1.2));
            }

            radius: Tokens.rounding.full
            color: root.fgColour

            Behavior on implicitHeight {
                Anim {
                    type: Anim.FastSpatial
                }
            }
        }

        StyledRect {
            id: filled

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: root.filledWidth
            implicitHeight: root.height

            radius: root.radius
            topRightRadius: Tokens.rounding.extraSmall / 2
            bottomRightRadius: Tokens.rounding.extraSmall / 2
            color: root.fgColour
        }
    }

    Binding {
        id: posBinding

        target: root
        property: "pos"
        value: root.clamp01(mouse.pressStartPos + mouse.dragMovement)
        when: mouse.pressed
    }

    MouseArea {
        id: mouse

        property real pressStartX
        property real pressStartPos
        property real dragMovement

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        preventStealing: true
        implicitHeight: handle.implicitHeight

        onPressed: e => {
            // The fill must track the finger exactly while dragging, so the
            // smoothing Behavior is off for the duration of the press.
            widthBehavior.enabled = false;
            pressStartX = e.x;
            pressStartPos = root.visualPosition;
        }
        onPositionChanged: e => {
            dragMovement = (e.x - pressStartX) / width;
            if (root.interactionOnMove)
                root.interaction(posBinding.value);
        }
        onReleased: e => {
            // No drag means it was a click: jump to wherever was clicked.
            const finalPos = dragMovement !== 0 ? posBinding.value : root.clamp01(e.x / width);
            root.interaction(finalPos);
            widthBehavior.enabled = true;
            dragMovement = 0;
        }
    }

    Behavior on filledWidth {
        id: widthBehavior

        Anim {}
    }
}
