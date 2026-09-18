// Material 3 text button. Ported from caelestia-shell
// components/controls/TextButton.qml with the palette roles pointed at this
// repo's generated Colors.qml.
import QtQuick
import common

ButtonBase {
    id: root

    property alias text: label.text
    readonly property alias label: label

    horizontalPadding: Tokens.padding.medium
    verticalPadding: Tokens.padding.small

    activeColour: type === ButtonBase.Filled ? Colors.m3primary : Colors.m3secondary
    inactiveColour: {
        if (!isToggle && type === ButtonBase.Filled)
            return Colors.m3primary;
        return type === ButtonBase.Filled ? Colors.m3surfaceContainer : Colors.m3secondaryContainer;
    }
    activeOnColour: {
        if (type === ButtonBase.Text)
            return Colors.m3primary;
        return type === ButtonBase.Filled ? Colors.m3onPrimary : Colors.m3onSecondary;
    }
    inactiveOnColour: {
        if (!isToggle && type === ButtonBase.Filled)
            return Colors.m3onPrimary;
        if (type === ButtonBase.Text)
            return Colors.m3primary;
        return type === ButtonBase.Filled ? Colors.m3onSurface : Colors.m3onSecondaryContainer;
    }

    implicitWidth: label.implicitWidth + horizontalPadding * 2
    implicitHeight: label.implicitHeight + verticalPadding * 2

    StyledText {
        id: label

        anchors.centerIn: parent
        color: root.onColour
        font: root.font
    }
}
