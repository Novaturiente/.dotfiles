// Material 3 radio button: a ring that fills with a dot when selected, with the
// label to its right. Ported from caelestia-shell
// components/controls/StyledRadioButton.qml.
import QtQuick
import QtQuick.Templates
import common

RadioButton {
    id: root

    font: Tokens.font.body.small

    implicitWidth: implicitIndicatorWidth + implicitContentWidth + contentItem.anchors.leftMargin
    implicitHeight: Math.max(implicitIndicatorHeight, implicitContentHeight)

    indicator: Rectangle {
        id: outerCircle

        implicitWidth: 20
        implicitHeight: 20
        radius: Tokens.rounding.full
        color: "transparent"
        border.color: root.checked ? Colors.m3primary : Colors.m3onSurfaceVariant
        border.width: 2
        anchors.verticalCenter: parent.verticalCenter

        // Sits behind the ring and extends past it, so the ripple is bigger than
        // the 20px circle.
        StateLayer {
            anchors.margins: -Tokens.padding.small
            color: root.checked ? Colors.m3onSurface : Colors.m3primary
            z: -1
            onClicked: root.click()
        }

        // The inner dot fades in via its alpha rather than its opacity, so the
        // colour animation handles it.
        StyledRect {
            anchors.centerIn: parent
            implicitWidth: 8
            implicitHeight: 8

            radius: Tokens.rounding.full
            color: Qt.alpha(Colors.m3primary, root.checked ? 1 : 0)
        }

        Behavior on border.color {
            CAnim {}
        }
    }

    contentItem: StyledText {
        text: root.text
        font: root.font
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: outerCircle.right
        anchors.right: parent.right
        anchors.leftMargin: Tokens.spacing.medium
        elide: Text.ElideRight
    }
}
