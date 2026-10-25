// The Mod+S menu shape every island list page shares: a search field with an
// icon and a count, then two-line rows (title, dim subtitle) with an icon.
//
// The page owns the data: it filters on `text` and hands back `model`, an
// array of rows { title, sub, icon (image url), glyph (Nerd Font text),
// thumb (large image url, makes the row tall), dim (bool) }.
//
// Keys: Up/Down or Ctrl+P/N move (wrapping), Enter emits accepted(), Esc emits
// escaped(). A page sees every key first through keyPressed(e) and can take it
// by setting e.accepted.
import QtQuick
import QtQuick.Controls
import common

Column {
    id: sl

    property alias text: field.text
    property alias field: field
    property string glyph
    property string placeholder
    property var model: []
    property int currentIndex: 0
    property string countText: model.length + ""
    property string emptyText: "Nothing here"
    property int listWidth: 720
    property int rowHeight: 56
    property int maxRows: 8

    readonly property var current: model[currentIndex]
    property point lastPointer

    signal accepted(int index, var row)
    signal escaped
    signal keyPressed(var e)

    function focusField(): void {
        field.forceActiveFocus();
    }
    function reset(): void {
        field.text = "";
        currentIndex = 0;
    }
    function move(d: int): void {
        if (model.length)
            currentIndex = (currentIndex + d + model.length) % model.length;
    }

    spacing: Tokens.spacing.small

    onModelChanged: if (currentIndex >= model.length) currentIndex = 0

    Rectangle {
        width: sl.listWidth
        height: 50
        radius: Tokens.rounding.large
        color: Colors.inputBg
        border.color: field.activeFocus ? Qt.alpha(Colors.accent, 0.6) : Colors.outline
        border.width: 1

        T {
            id: icon
            x: Tokens.padding.large
            text: sl.glyph
            color: Colors.accent
            font.pixelSize: Tokens.fontSize.large
        }
        StyledTextField {
            id: field
            anchors.left: icon.right
            anchors.leftMargin: Tokens.spacing.small
            anchors.right: countLabel.left
            anchors.rightMargin: Tokens.spacing.small
            anchors.verticalCenter: parent.verticalCenter
            font.family: "SF Pro Display"
            font.pixelSize: Tokens.fontSize.larger
            background: null
            placeholderText: sl.placeholder
            onTextChanged: sl.currentIndex = 0
            Keys.onPressed: e => {
                sl.keyPressed(e);
                if (e.accepted)
                    return;
                const ctrl = e.modifiers & Qt.ControlModifier;
                if (e.key === Qt.Key_Escape)
                    sl.escaped();
                else if (e.key === Qt.Key_Down || (ctrl && e.key === Qt.Key_N))
                    sl.move(1);
                else if (e.key === Qt.Key_Up || (ctrl && e.key === Qt.Key_P))
                    sl.move(-1);
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                    sl.accepted(sl.currentIndex, sl.current);
                else
                    return;
                e.accepted = true;
            }
        }
        T {
            id: countLabel
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.large
            text: sl.countText
            color: Colors.subtext
            font.pixelSize: Tokens.fontSize.smaller
        }
    }

    T {
        visible: sl.model.length === 0
        anchors.verticalCenter: undefined
        width: sl.listWidth
        topPadding: Tokens.padding.medium
        bottomPadding: Tokens.padding.medium
        horizontalAlignment: Text.AlignHCenter
        text: sl.emptyText
        color: Colors.subtext
    }

    ListView {
        id: list
        visible: sl.model.length > 0
        width: sl.listWidth
        // From the model, not contentHeight: a 0-high ListView builds no rows.
        height: Math.min(sl.model.reduce((h, r) => h + (r.thumb ? 2 : 1), 0), sl.maxRows) * sl.rowHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: sl.model
        currentIndex: sl.currentIndex
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        ScrollBar.vertical: StyledScrollBar {
            flickable: list
        }
        delegate: Rectangle {
            id: row
            required property int index
            required property var modelData
            readonly property bool sel: index === sl.currentIndex
            width: ListView.view.width
            height: modelData.thumb ? sl.rowHeight * 2 : sl.rowHeight
            radius: Tokens.rounding.medium
            color: sel ? Colors.surface2 : hover.containsMouse ? Colors.surface0 : "transparent"

            Row {
                x: Tokens.padding.medium
                width: parent.width - 2 * Tokens.padding.medium
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.spacing.medium

                // Leading icon: thumbnail, image icon, or glyph.
                Item {
                    width: row.modelData.thumb ? 200 : 32
                    height: row.modelData.thumb ? row.height - Tokens.padding.small * 2 : 32
                    anchors.verticalCenter: parent.verticalCenter
                    Image {
                        anchors.fill: parent
                        visible: !!(row.modelData.thumb || row.modelData.icon)
                        source: row.modelData.thumb || row.modelData.icon || ""
                        sourceSize: Qt.size(width * 2, height * 2)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    T {
                        anchors.centerIn: parent
                        visible: !row.modelData.thumb && !row.modelData.icon
                        text: row.modelData.glyph || ""
                        color: row.sel ? Colors.accent : Colors.subtext0
                        font.pixelSize: Tokens.fontSize.large
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - parent.children[0].width - parent.spacing
                    spacing: 2
                    T {
                        anchors.verticalCenter: undefined
                        width: parent.width
                        text: row.modelData.title || ""
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.weight: Font.Medium
                        color: row.modelData.dim ? Colors.subtext0 : Colors.fg
                    }
                    T {
                        anchors.verticalCenter: undefined
                        visible: text !== ""
                        width: parent.width
                        text: row.modelData.sub || ""
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pixelSize: Tokens.fontSize.smaller
                        color: Colors.subtext
                    }
                }
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                // Select on real pointer movement only: a row that slides under a
                // resting cursor while the island grows must not steal the selection.
                onPositionChanged: m => {
                    const p = mapToGlobal(m.x, m.y);
                    if (p.x === sl.lastPointer.x && p.y === sl.lastPointer.y)
                        return;
                    sl.lastPointer = p;
                    sl.currentIndex = row.index;
                }
                onClicked: {
                    sl.currentIndex = row.index;
                    sl.accepted(row.index, row.modelData);
                }
            }
        }
    }
}
