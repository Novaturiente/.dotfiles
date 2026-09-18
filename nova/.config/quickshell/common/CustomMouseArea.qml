// MouseArea that batches wheel events into whole notches, so a high-resolution
// touchpad does not fire one volume step per pixel of scroll.
// Ported verbatim from caelestia-shell components/controls/CustomMouseArea.qml.
import QtQuick

MouseArea {
    property int scrollAccumulatedY: 0

    function onWheel(event: WheelEvent): void {
    }

    onWheel: event => {
        // Reverse of direction cancels whatever was accumulated.
        if (Math.sign(event.angleDelta.y) !== Math.sign(scrollAccumulatedY))
            scrollAccumulatedY = 0;
        scrollAccumulatedY += event.angleDelta.y;

        // 120 is one notch on a conventional wheel.
        if (Math.abs(scrollAccumulatedY) >= 120) {
            onWheel(event);
            scrollAccumulatedY = 0;
        }
    }
}
