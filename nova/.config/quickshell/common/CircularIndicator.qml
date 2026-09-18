// Indeterminate spinner: an arc that sweeps around while `running` is true.
//
// ponytail: caelestia's version is a full Material 3 indeterminate indicator
// driven by a C++ CircularIndicatorManager, with advance/retreat phases and a
// completion animation. This is a plain rotating arc with the same four
// properties the panels actually set. Swap in the real thing only if the
// simplified motion looks wrong next to the rest of the M3 widgets.
import QtQuick
import QtQuick.Shapes
import common

Item {
    id: root

    property bool running: true
    property real implicitSize: Tokens.font.body.medium.pointSize * 3
    property real strokeWidth: Tokens.padding.extraSmall
    property color fgColour: Colors.m3primary
    property color bgColour: Colors.m3secondaryContainer

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    visible: opacity > 0
    opacity: running ? 1 : 0

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Shape {
        id: shape

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: true

        // Full background ring.
        ShapePath {
            strokeColor: root.bgColour
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.strokeWidth) / 2
                radiusY: (root.height - root.strokeWidth) / 2
                startAngle: 0
                sweepAngle: 360
            }
        }

        // The sweeping arc.
        ShapePath {
            strokeColor: root.fgColour
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                id: arc

                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.strokeWidth) / 2
                radiusY: (root.height - root.strokeWidth) / 2
                startAngle: 0
                sweepAngle: 90
            }
        }
    }

    NumberAnimation {
        target: arc
        property: "startAngle"
        running: root.running
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: Tokens.anim.durations.extraLarge
    }
}
