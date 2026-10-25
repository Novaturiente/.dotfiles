// One island page: sizes itself to its content. On open it fades in and grows
// from 94% while the pill springs to its size, so the island reads as one
// surface turning into the page.
import QtQuick
import common

Item {
    property bool active
    // Emitted by the shell each time this page is shown: focus a field, reload data.
    signal opened
    // A page asks the shell to go back to the idle pill.
    signal closeRequested

    anchors.centerIn: parent
    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
    opacity: active ? 1 : 0
    scale: active ? 1 : 0.94
    visible: opacity > 0
    Behavior on opacity {
        Anim {
            type: Anim.FastEffects
        }
    }
    Behavior on scale {
        Anim {
            type: Anim.FastSpatial
        }
    }
}
