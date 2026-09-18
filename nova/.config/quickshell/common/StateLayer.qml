// Material 3 state layer: a hover tint plus a press ripple that grows from the
// exact point clicked and fades once it has covered the widget.
//
// Ported from caelestia-shell components/StateLayer.qml. Two upstream
// dependencies are replaced: CUtils.clamp becomes the local clamp01 function,
// and the Material palette role m3onSurface becomes this repo's Colors.fg.
//
// Drop it inside any Rectangle to make that rectangle clickable:
//   Rectangle { radius: 8; StateLayer { onClicked: doThing() } }
// It fills its parent and inherits the parent's corner radii automatically.
import QtQuick
import QtQuick.Shapes
import common

MouseArea {
    id: root

    property bool disabled
    // Lets a keyboard-selected row show the hover tint without the pointer on it.
    property bool manualHoverOverride
    property bool manualPressOverride

    property real stateOpacity: containsMouse || manualHoverOverride ? 0.08 : 0

    property real pressX: width / 2
    property real pressY: height / 2
    property real circleRadius
    property real endRadiusAtPress

    property alias color: base.color
    property alias radius: base.radius
    property alias topLeftRadius: base.topLeftRadius
    property alias topRightRadius: base.topRightRadius
    property alias bottomLeftRadius: base.bottomLeftRadius
    property alias bottomRightRadius: base.bottomRightRadius

    // The ripple has to reach whichever corner is furthest from the press point.
    readonly property real endRadius: Math.sqrt(Math.max(distSq(0, 0), distSq(width, 0), distSq(0, height), distSq(width, height))) * 1.3

    function distSq(x: real, y: real): real {
        return (pressX - x) ** 2 + (pressY - y) ** 2;
    }

    // Guards against NaN: endRadius is 0 while a row still has no size, and
    // circleRadius / 0 would otherwise reach Qt.alpha as an invalid alpha.
    function clamp01(v: real): real {
        return isNaN(v) ? 0 : Math.max(0, Math.min(1, v));
    }

    // Corner radii cannot exceed half the shorter side, or the arcs cross over.
    function clampRadius(r: real): real {
        return Math.max(0, Math.min(r, width / 2, height / 2));
    }

    function press(x: real, y: real): void {
        pressX = x;
        pressY = y;
        fadeAnim.complete();
        circleRadius = 0;
        circle.opacity = 0.1;
        endRadiusAtPress = endRadius;
        rippleAnim.restart();
    }

    // Once the ripple has all but covered the widget and the button is up, fade out.
    function maybeFade(): void {
        if (!(pressed || manualPressOverride) && circleRadius > endRadiusAtPress * 0.99 && !fadeAnim.running)
            fadeAnim.start();
    }

    anchors.fill: parent
    enabled: !disabled
    cursorShape: disabled ? undefined : Qt.PointingHandCursor
    hoverEnabled: true

    onPressed: e => press(e.x, e.y)
    onPressedChanged: {
        if (!(pressed || manualPressOverride) && !rippleAnim.running && circle.opacity > 0)
            fadeAnim.start();
    }
    onManualPressOverrideChanged: maybeFade()
    onCircleRadiusChanged: maybeFade()

    Anim {
        id: rippleAnim

        alwaysRunToEnd: true
        target: root
        property: "circleRadius"
        to: root.endRadius
        curve: Tokens.anim.curves.standard
        duration: Tokens.anim.durations.expressiveSlowEffects * 2
    }

    Anim {
        id: fadeAnim

        target: circle
        property: "opacity"
        to: 0
        type: Anim.SlowEffects
    }

    // Flat hover tint underneath the ripple.
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

    // The ripple itself: a radial gradient clipped to the parent's rounded shape.
    // The outer gradient stop softens the leading edge and then fades the whole
    // circle in as it approaches full size.
    Shape {
        id: circle

        anchors.fill: parent
        opacity: 0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: base.color
            fillGradient: RadialGradient {
                centerX: root.pressX
                centerY: root.pressY
                centerRadius: root.circleRadius
                focalX: centerX
                focalY: centerY

                GradientStop {
                    position: 0
                    color: Qt.alpha(base.color, 1)
                }
                GradientStop {
                    position: Math.max(0.01, Math.min(0.99, 1 - 0.2 * root.endRadius / root.circleRadius))
                    color: Qt.alpha(base.color, 1)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(base.color, root.clamp01((root.circleRadius / root.endRadius - 0.9) / 0.1))
                }
            }

            startX: root.clampRadius(base.topLeftRadius)
            startY: 0

            PathLine {
                x: root.width - root.clampRadius(base.topRightRadius)
                y: 0
            }
            PathArc {
                relativeX: root.clampRadius(base.topRightRadius)
                relativeY: root.clampRadius(base.topRightRadius)
                radiusX: root.clampRadius(base.topRightRadius)
                radiusY: root.clampRadius(base.topRightRadius)
            }
            PathLine {
                x: root.width
                y: root.height - root.clampRadius(base.bottomRightRadius)
            }
            PathArc {
                relativeX: -root.clampRadius(base.bottomRightRadius)
                relativeY: root.clampRadius(base.bottomRightRadius)
                radiusX: root.clampRadius(base.bottomRightRadius)
                radiusY: root.clampRadius(base.bottomRightRadius)
            }
            PathLine {
                x: root.clampRadius(base.bottomLeftRadius)
                y: root.height
            }
            PathArc {
                relativeX: -root.clampRadius(base.bottomLeftRadius)
                relativeY: -root.clampRadius(base.bottomLeftRadius)
                radiusX: root.clampRadius(base.bottomLeftRadius)
                radiusY: root.clampRadius(base.bottomLeftRadius)
            }
            PathLine {
                x: 0
                y: root.clampRadius(base.topLeftRadius)
            }
            PathArc {
                x: root.clampRadius(base.topLeftRadius)
                y: 0
                radiusX: root.clampRadius(base.topLeftRadius)
                radiusY: root.clampRadius(base.topLeftRadius)
            }
        }
    }

    Behavior on stateOpacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
