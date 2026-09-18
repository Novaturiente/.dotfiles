// Colour animation on the slow-effects curve, so every palette change across the
// menus crossfades identically. Ported from caelestia-shell components/CAnim.qml.
import QtQuick
import common

ColorAnimation {
    duration: Tokens.anim.durations.expressiveSlowEffects
    easing.type: Easing.Bezier
    easing.bezierCurve: Tokens.anim.curves.expressiveSlowEffects
}
