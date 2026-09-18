// Search input with an animated caret: the cursor slides to its new column
// instead of jumping, and pauses its blink for half a second after every move so
// it stays readable while you type.
//
// Ported from caelestia-shell components/controls/TextFieldBase.qml. It derives
// from QtQuick.Templates.TextField, which ships no visuals of its own, so the
// caller supplies `background` exactly as with a plain TextField.
import QtQuick
import QtQuick.Templates as T
import common

T.TextField {
    id: root

    // Sizing and padding copied from QtQuick.Controls.Basic's TextField, so
    // swapping a plain TextField for this one does not move the layout.
    implicitWidth: Math.max(contentWidth, placeholder.implicitWidth) + leftPadding + rightPadding
    implicitHeight: Math.max(contentHeight, placeholder.implicitHeight) + topPadding + bottomPadding

    padding: 6
    leftPadding: padding + 4

    color: Colors.fg
    placeholderTextColor: Colors.subtext
    selectionColor: Qt.alpha(Colors.accent, 0.4)
    selectedTextColor: color

    renderType: echoMode === TextInput.Password ? Text.QtRendering : Text.NativeRendering
    cursorVisible: !readOnly
    verticalAlignment: TextInput.AlignVCenter

    // The real caret is replaced by the animated rectangle below.
    cursorDelegate: Item {}

    // QtQuick.Templates holds placeholderText but draws nothing for it, so the
    // placeholder is drawn here.
    // ponytail: a plain show/hide, not upstream's floating label that shrinks to
    // the top edge on focus — these are flat search inputs with no field outline
    // for a label to sit in.
    Text {
        id: placeholder

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.leftPadding
        anchors.rightMargin: root.rightPadding

        horizontalAlignment: root.horizontalAlignment

        text: root.placeholderText
        font: root.font
        color: root.placeholderTextColor
        renderType: Text.NativeRendering
        elide: Text.ElideRight
        visible: !root.length && !root.preeditText
    }

    Behavior on color {
        CAnim {}
    }

    Behavior on selectionColor {
        CAnim {}
    }

    StyledRect {
        id: cursor

        property bool disableBlink

        x: root.cursorRectangle.x
        y: root.cursorRectangle.y
        implicitWidth: 1.5
        implicitHeight: root.cursorRectangle.height

        color: Colors.accent
        radius: Tokens.rounding.large

        Connections {
            function onCursorPositionChanged(): void {
                if (root.activeFocus && root.cursorVisible) {
                    cursor.opacity = 1;
                    cursor.disableBlink = true;
                    enableBlink.restart();
                }
            }

            target: root
        }

        // Half a second of solid caret after the last keystroke, then blink again.
        Timer {
            id: enableBlink

            interval: 500
            onTriggered: cursor.disableBlink = false
        }

        Timer {
            running: root.activeFocus && root.cursorVisible && !cursor.disableBlink
            repeat: true
            triggeredOnStart: true
            interval: 500
            onTriggered: parent.opacity = parent.opacity === 1 ? 0 : 1
        }

        Binding {
            when: !root.activeFocus || !root.cursorVisible
            cursor.opacity: 0
        }

        Behavior on x {
            Anim {
                // Damped variant of the fast spatial curve: the caret should settle
                // rather than overshoot the character it landed on.
                curve: [0.2, 1, 0.21, 1, 1, 1]
                duration: Tokens.anim.durations.expressiveFastEffects
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.StandardSmall
            }
        }
    }
}
