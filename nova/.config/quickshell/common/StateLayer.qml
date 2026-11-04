// macOS-style state layer: a faint tint on hover and a slightly stronger one
// while pressed. No Material ripple.
//
// Drop it inside any Rectangle to make that rectangle clickable:
//   Rectangle { radius: 8; StateLayer { onClicked: doThing() } }
// It fills its parent and inherits the parent's corner radii automatically.
import QtQuick
import common

MouseArea {
    id: root

    property bool disabled
    // Lets a keyboard-selected row show the hover tint without the pointer on it.
    property bool manualHoverOverride
    property bool manualPressOverride

    property real stateOpacity: pressed || manualPressOverride ? 0.14
        : containsMouse || manualHoverOverride ? 0.07 : 0

    property alias color: base.color
    property alias radius: base.radius
    property alias topLeftRadius: base.topLeftRadius
    property alias topRightRadius: base.topRightRadius
    property alias bottomLeftRadius: base.bottomLeftRadius
    property alias bottomRightRadius: base.bottomRightRadius

    anchors.fill: parent
    enabled: !disabled
    cursorShape: disabled ? undefined : Qt.PointingHandCursor
    hoverEnabled: true

    StyledRect {
        id: base

        anchors.fill: parent
        opacity: root.stateOpacity
        color: Colors.fg
        // Follow the parent's rounding when it has any, so the tint never squares
        // off a rounded row. qmllint cannot know the parent has these properties.
        // qmllint disable missing-property
        radius: root.parent?.radius ?? 0
        topLeftRadius: root.parent?.topLeftRadius ?? radius ?? 0
        topRightRadius: root.parent?.topRightRadius ?? radius ?? 0
        bottomLeftRadius: root.parent?.bottomLeftRadius ?? radius ?? 0
        bottomRightRadius: root.parent?.bottomRightRadius ?? radius ?? 0
        // qmllint enable missing-property
    }

    Behavior on stateOpacity {
        Anim {
            type: Anim.FastEffects
        }
    }
}
