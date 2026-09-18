// Material 3 button with a leading Material Symbols glyph. Ported from
// caelestia-shell components/controls/IconTextButton.qml.
import QtQuick
import QtQuick.Layouts
import common

ButtonBase {
    id: root

    property alias icon: iconLabel.text
    property alias text: label.text
    property alias spacing: row.spacing

    readonly property alias iconLabel: iconLabel
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

    implicitWidth: row.implicitWidth + horizontalPadding * 2
    implicitHeight: row.implicitHeight + verticalPadding * 2

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        MaterialIcon {
            id: iconLabel

            Layout.alignment: Qt.AlignVCenter
            color: root.onColour
            fill: root.internalChecked ? 1 : 0
            // The glyph reads small next to text at the same point size.
            fontStyle: Tokens.font.icon.size(Math.round(root.font.pointSize * 1.2)).build()

            Behavior on fill {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        StyledText {
            id: label

            Layout.alignment: Qt.AlignVCenter
            Layout.topMargin: 1
            color: root.onColour
            font: root.font
        }
    }
}
