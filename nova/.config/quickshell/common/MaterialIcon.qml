// A single Material Symbols glyph. Set `text` to the icon name, e.g. "wifi".
//
// Ported from caelestia-shell components/MaterialIcon.qml. Upstream routes the
// variable axes through its C++ font builder; here they are set directly on
// font.variableAxes, which is all the builder was doing.
//
// Needs the ttf-material-symbols-variable package.
import QtQuick
import common

StyledText {
    id: root

    // 0 is the outlined glyph, 1 the filled one. Animate it for a fill-in effect.
    property real fill: 0
    // ponytail: upstream picks grade by palette lightness. Every theme in this
    // repo is dark, where -25 is the Material recommendation.
    property int grade: -25
    property font fontStyle: Tokens.font.icon.small

    // Built in one go: QML rejects assigning `font` and `font.variableAxes`
    // separately in the same type.
    font: Qt.font({
        family: root.fontStyle.family,
        pointSize: root.fontStyle.pointSize,
        weight: root.fontStyle.weight,
        variableAxes: {
            FILL: root.fill.toFixed(1),
            GRAD: root.grade,
            opsz: 24,
            wght: 400
        }
    })
}
