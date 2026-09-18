// Text preset onto the Material 3 body type scale, crossfading its colour so
// theme switches animate. Ported from caelestia-shell components/StyledText.qml;
// the palette role m3onSurface comes from this repo's generated Colors.qml.
import QtQuick
import common

Text {
    id: root

    property bool animate: false

    renderType: Text.NativeRendering
    textFormat: Text.PlainText
    color: Colors.m3onSurface
    font: Tokens.font.body.small

    Behavior on color {
        CAnim {}
    }

    // Opt-in: fades out, swaps the string, fades back in.
    Behavior on text {
        enabled: root.animate

        SequentialAnimation {
            Anim {
                target: root
                property: "opacity"
                to: 0
                type: Anim.FastEffects
            }
            PropertyAction {}
            Anim {
                target: root
                property: "opacity"
                to: 1
                type: Anim.DefaultEffects
            }
        }
    }
}
