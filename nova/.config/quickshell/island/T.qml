// Island text: UI font, theme text colour, centred in a Row by default.
// Nerd Font icons come via fontconfig fallback.
import QtQuick
import common

Text {
    color: Colors.fg
    font.family: "SF Pro Display"
    font.features: { "tnum": 1 } // fixed-width digits so the clock doesn't shift
    font.pixelSize: Tokens.fontSize.normal
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
}
