// Rectangle that crossfades its colour instead of snapping, so theme switches and
// selection changes animate. Ported from caelestia-shell components/StyledRect.qml.
import QtQuick

Rectangle {
    color: "transparent"

    Behavior on color {
        CAnim {}
    }
}
