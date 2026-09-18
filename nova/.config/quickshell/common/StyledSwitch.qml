// Material 3 switch: a pill track with a thumb that widens on press and draws a
// check or cross as it slides. Ported from caelestia-shell
// components/controls/StyledSwitch.qml.
//
// Colours.layer() becomes Colors.layer(), which is a pass-through here, and the
// rounding/duration scale factors upstream exposes for user config are dropped.
import QtQuick
import QtQuick.Shapes
import QtQuick.Templates
import common

Switch {
    id: root

    property bool disabled

    enabled: !disabled

    implicitWidth: implicitIndicatorWidth
    implicitHeight: implicitIndicatorHeight

    indicator: StyledRect {
        radius: Tokens.rounding.full
        color: {
            if (root.disabled)
                return root.checked ? Qt.alpha(Colors.m3onSurface, 0.12) : Qt.alpha(Colors.m3surfaceContainerHighest, 0.38);
            return root.checked ? Colors.m3primary : Colors.m3surfaceContainerHighest;
        }

        implicitWidth: implicitHeight * 1.7
        implicitHeight: Tokens.font.body.medium.pointSize + Tokens.padding.small * 2

        // The thumb.
        StyledRect {
            id: thumb

            readonly property real nonAnimWidth: root.pressed ? implicitHeight * 1.2 : implicitHeight

            radius: Tokens.rounding.full
            color: {
                if (root.disabled)
                    return root.checked ? Colors.m3surface : Qt.alpha(Colors.m3onSurface, 0.12);
                return root.checked ? Colors.m3onPrimary : Colors.m3outline;
            }

            x: root.checked ? parent.implicitWidth - nonAnimWidth - Tokens.padding.extraSmall / 2 : Tokens.padding.extraSmall / 2
            implicitWidth: nonAnimWidth
            implicitHeight: parent.implicitHeight - Tokens.padding.extraSmall
            anchors.verticalCenter: parent.verticalCenter

            // Hover and press tint on the thumb itself.
            StyledRect {
                anchors.fill: parent
                radius: parent.radius

                color: root.checked ? Colors.m3primary : Colors.m3onSurface
                opacity: root.pressed ? 0.1 : root.hovered ? 0.08 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            // Two strokes that morph between a check, a cross, and a flat dash
            // while pressed.
            Shape {
                id: icon

                property point start1: {
                    if (root.pressed)
                        return Qt.point(width * 0.2, height / 2);
                    if (root.checked)
                        return Qt.point(width * 0.15, height / 2);
                    return Qt.point(width * 0.15, height * 0.15);
                }
                property point end1: {
                    if (root.pressed) {
                        if (root.checked)
                            return Qt.point(width * 0.4, height / 2);
                        return Qt.point(width * 0.8, height / 2);
                    }
                    if (root.checked)
                        return Qt.point(width * 0.4, height * 0.7);
                    return Qt.point(width * 0.85, height * 0.85);
                }
                property point start2: {
                    if (root.pressed) {
                        if (root.checked)
                            return Qt.point(width * 0.4, height / 2);
                        return Qt.point(width * 0.2, height / 2);
                    }
                    if (root.checked)
                        return Qt.point(width * 0.4, height * 0.7);
                    return Qt.point(width * 0.15, height * 0.85);
                }
                property point end2: {
                    if (root.pressed)
                        return Qt.point(width * 0.8, height / 2);
                    if (root.checked)
                        return Qt.point(width * 0.85, height * 0.2);
                    return Qt.point(width * 0.85, height * 0.15);
                }

                anchors.centerIn: parent
                width: height
                height: parent.implicitHeight - Tokens.padding.medium
                preferredRendererType: Shape.CurveRenderer
                asynchronous: true

                ShapePath {
                    strokeWidth: Tokens.font.body.large.pointSize * 0.15
                    strokeColor: {
                        if (root.disabled)
                            return root.checked ? Colors.m3outline : Colors.m3surfaceContainer;
                        return root.checked ? Colors.m3primary : Colors.m3surfaceContainerHighest;
                    }
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    startX: icon.start1.x
                    startY: icon.start1.y

                    PathLine {
                        x: icon.end1.x
                        y: icon.end1.y
                    }
                    PathMove {
                        x: icon.start2.x
                        y: icon.start2.y
                    }
                    PathLine {
                        x: icon.end2.x
                        y: icon.end2.y
                    }

                    Behavior on strokeColor {
                        CAnim {}
                    }
                }

                Behavior on start1 {
                    PropAnim {}
                }
                Behavior on end1 {
                    PropAnim {}
                }
                Behavior on start2 {
                    PropAnim {}
                }
                Behavior on end2 {
                    PropAnim {}
                }
            }

            Behavior on x {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            Behavior on implicitWidth {
                Anim {
                    type: Anim.FastSpatial
                }
            }
        }
    }

    // Cursor only; the Switch template handles the clicking.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: false
    }

    component PropAnim: PropertyAnimation {
        duration: Tokens.anim.durations.expressiveFastSpatial
        easing.type: Easing.Bezier
        easing.bezierCurve: Tokens.anim.curves.expressiveFastSpatial
    }
}
