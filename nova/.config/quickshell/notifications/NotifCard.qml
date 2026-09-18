// One notification card.
//
// Named NotifCard rather than Notification because Quickshell.Services.Notifications
// already exports a type called Notification, which this file imports.
//
// Ported from caelestia-shell modules/notifications/Notification.qml, with its
// Material palette mapped onto common/Colors.qml and its Material Symbols icons
// swapped for the Nerd Font glyphs the other menus already use.
//
// Gestures, all from upstream:
//   drag sideways   past 30% of the width dismisses; short of that it snaps back
//   drag up / down  collapses or expands the card
//   middle click    closes immediately
//   hover           holds the expiry timer open
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import common

StyledRect {
    id: root

    required property var modelData   // a Quickshell Notification
    // Set by the exit animation; the stack drops the card once it finishes.
    signal dismissed

    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
    readonly property bool low: modelData.urgency === NotificationUrgency.Low
    readonly property string imageSource: {
        const i = modelData.image ?? "";
        if (!i)
            return "";
        // A bare absolute path needs a scheme.
        if (i.startsWith("/"))
            return "file://" + i;
        // notify-send's -i argument arrives here as image://icon/<name>, and when the
        // theme has no such icon the provider draws a chequerboard rather than
        // failing. iconPath's check form returns an empty string for a name the theme
        // does not have, which lets the lettered badge take over instead.
        if (i.startsWith("image://icon/")) {
            const name = i.slice("image://icon/".length).split("?")[0];
            return Quickshell.iconPath(name, true);
        }
        return i;
    }
    // If the image still will not load, drop the slot and let the lettered badge
    // take over rather than leave a broken picture on screen.
    property bool imageFailed: false
    readonly property bool hasImage: imageSource.length > 0 && !imageFailed
    // Same existence check for the badge icon: an unknown name must not reach the
    // image provider.
    readonly property string appIconSource: {
        const n = modelData.appIcon ?? "";
        if (!n)
            return "";
        return n.startsWith("/") ? "file://" + n : Quickshell.iconPath(n, true);
    }
    readonly property bool hasAppIcon: appIconSource.length > 0
    // Only pay for the Markdown parser when the body actually looks like markup.
    readonly property int bodyTextFormat: /[<*_`#\[\]]/.test(modelData.body) ? Text.MarkdownText : Text.PlainText

    property bool expanded: false
    property bool closing: false

    // Some notifications (volume, copy progress) carry a 0-100 value hint, which
    // upstream draws as a ring around the app icon.
    readonly property real progress: modelData.hints?.value ?? -1
    readonly property bool hasProgress: progress >= 0

    readonly property int imageSize: 42
    readonly property int badgeSize: 20

    // The height the card wants right now. Kept separate from implicitHeight so the
    // expand/collapse can animate towards it.
    readonly property int targetHeight: inner.anchors.margins * 2 + summary.implicitHeight + (expanded
        ? Tokens.spacing.extraSmall * 2 + appName.implicitHeight + body.implicitHeight + actions.implicitHeight + Tokens.spacing.small
        : bodyPreview.implicitHeight)

    function close(): void {
        if (closing)
            return;
        closing = true;
        exitAnim.restart();
    }

    color: critical ? Qt.tint(Colors.bg, Qt.alpha(Colors.red, 0.28)) : Colors.bg
    border.color: critical ? Colors.red : Colors.outline
    border.width: 1
    radius: Tokens.rounding.large

    // implicitWidth is set by the stack in shell.qml. The entry slide reads it at
    // construction time, so it has to be a real number by then, not a later binding.
    implicitHeight: Math.max(imageSize + inner.anchors.margins * 2, targetHeight)

    // Slide in from off the right edge on the decelerating emphasized curve.
    x: implicitWidth
    Component.onCompleted: x = 0

    Behavior on x {
        enabled: !dragArea.drag.active && !root.closing

        Anim {
            curve: Tokens.anim.curves.emphasizedDecel
        }
    }

    Behavior on implicitHeight {
        enabled: !root.closing

        Anim {}
    }

    // Expire on its own unless the pointer is on it. Critical notifications with no
    // timeout of their own stay until dismissed, as the spec asks.
    Timer {
        id: expiry

        running: interval > 0 && !dragArea.containsMouse && !dragArea.pressed && !root.closing
        interval: {
            const t = root.modelData.expireTimeout;
            if (t > 0)
                return t;
            return root.critical ? 0 : root.low ? 10000 : 5000;
        }
        onTriggered: root.close()
    }

    // Exit: throw the card off whichever side it was last dragged toward, then
    // collapse the gap it leaves behind.
    SequentialAnimation {
        id: exitAnim

        Anim {
            target: root
            property: "x"
            to: root.x >= 0 ? root.implicitWidth * 1.2 : -root.implicitWidth * 1.2
            duration: Tokens.anim.durations.normal
            curve: Tokens.anim.curves.emphasized
        }
        ParallelAnimation {
            Anim {
                target: root
                property: "implicitHeight"
                to: 0
                type: Anim.FastEffects
            }
            Anim {
                target: root
                property: "opacity"
                to: 0
                type: Anim.FastEffects
            }
        }
        ScriptAction {
            script: root.dismissed()
        }
    }

    MouseArea {
        id: dragArea

        property int startY

        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: pressed ? Qt.ClosedHandCursor : undefined

        drag.target: root
        drag.axis: Drag.XAxis

        onPressed: e => {
            startY = e.y;
            if (e.button === Qt.MiddleButton)
                root.close();
        }

        onReleased: {
            // Upstream's clearThreshold: a third of the way across commits the swipe.
            if (Math.abs(root.x) < root.implicitWidth * 0.3)
                root.x = 0;
            else
                root.close();
        }

        // Upstream's expandThreshold: 20px of vertical travel flips the card open
        // or shut, whichever way you dragged.
        onPositionChanged: e => {
            if (pressed && Math.abs(e.y - startY) > 20)
                root.expanded = e.y > startY;
        }

        Item {
            id: inner

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium

            implicitHeight: root.targetHeight

            // Image, when the notification carries one, with the app icon as a badge
            // on its corner. With no image the app icon takes the whole slot.
            Loader {
                id: image

                asynchronous: true
                active: root.hasImage

                anchors.left: parent.left
                anchors.top: parent.top
                width: root.imageSize
                height: root.imageSize

                sourceComponent: Rectangle {
                    radius: width / 2
                    color: Colors.surface1
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.imageSource
                        fillMode: Image.PreserveAspectCrop
                        // Themed icons come out of the icon provider, which only
                        // renders at sizes the theme actually ships and refuses 48 or
                        // 84; a real image file has no such limit.
                        sourceSize: root.imageSource.startsWith("image://icon/") ? Qt.size(32, 32) : Qt.size(84, 84)
                        cache: false
                        asynchronous: true

                        onStatusChanged: if (status === Image.Error) root.imageFailed = true
                    }
                }
            }

            Loader {
                id: appIcon

                asynchronous: true
                active: root.hasAppIcon || !root.hasImage

                anchors.horizontalCenter: root.hasImage ? undefined : image.horizontalCenter
                anchors.verticalCenter: root.hasImage ? undefined : image.verticalCenter
                anchors.right: root.hasImage ? image.right : undefined
                anchors.bottom: root.hasImage ? image.bottom : undefined

                sourceComponent: StyledRect {
                    implicitWidth: root.hasImage ? root.badgeSize : root.imageSize
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: root.critical ? Colors.red : root.low ? Colors.surface0 : Colors.surface1

                    Image {
                        id: iconImage

                        anchors.centerIn: parent
                        width: Math.round(parent.width * 0.6)
                        height: width
                        // Only shown once it has actually loaded; a themed name the
                        // icon theme lacks falls through to the glyph below.
                        visible: root.hasAppIcon && status === Image.Ready
                        source: root.appIconSource
                        // The icon image provider renders at sourceSize and hands back
                        // nothing when it is 0, so this is a fixed number rather than a
                        // binding on width, which is still 0 while the card is built.
                        sourceSize.width: 32
                        sourceSize.height: 32
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    // The ring for notifications that report a percentage. It lives
                    // inside the badge so it stays centred on it no matter what the
                    // badge itself is anchored to.
                    Shape {
                        id: progressRing

                        anchors.fill: parent
                        anchors.margins: -3
                        visible: root.hasProgress
                        preferredRendererType: Shape.CurveRenderer
                        asynchronous: true

                        ShapePath {
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            strokeWidth: 2
                            strokeColor: Colors.accent

                            PathAngleArc {
                                centerX: progressRing.width / 2
                                centerY: progressRing.height / 2
                                radiusX: progressRing.width / 2 - 1
                                radiusY: progressRing.height / 2 - 1
                                startAngle: -90
                                sweepAngle: (root.progress / 100) * 360

                                Behavior on sweepAngle {
                                    Anim {
                                        curve: Tokens.anim.curves.emphasizedDecel
                                    }
                                }
                            }
                        }
                    }

                    // Shown when the notification carries no usable icon. The app's
                    // initial beats a generic glyph: it always renders, whatever the
                    // font, and it tells you who sent the thing.
                    Text {
                        anchors.centerIn: parent
                        visible: !iconImage.visible
                        text: (root.modelData.appName || "?").charAt(0).toUpperCase()
                        color: root.critical ? Colors.base : Colors.fg
                        font.family: root.uiFont
                        font.pixelSize: parent.width * 0.42
                        font.bold: true
                    }
                }
            }

            // ── header ───────────────────────────────────────────────────────
            // Collapsed: summary • age. Expanded: app name • age on top, summary below.
            Text {
                id: appName

                anchors.top: parent.top
                anchors.left: image.right
                anchors.leftMargin: Tokens.spacing.medium

                text: root.modelData.appName
                color: Colors.subtext
                font.family: root.uiFont
                font.pixelSize: 12
                elide: Text.ElideRight
                width: expandBtn.x - x - Tokens.spacing.small
                opacity: root.expanded ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            Text {
                id: summary

                anchors.top: root.expanded ? appName.bottom : parent.top
                anchors.topMargin: root.expanded ? Tokens.spacing.extraSmall : 0
                anchors.left: image.right
                anchors.leftMargin: Tokens.spacing.medium
                anchors.right: expandBtn.left
                anchors.rightMargin: Tokens.spacing.small

                text: root.modelData.summary
                color: Colors.fg
                font.family: root.uiFont
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: root.expanded ? 3 : 1
                wrapMode: root.expanded ? Text.WrapAtWordBoundaryOrAnywhere : Text.NoWrap
            }

            Item {
                id: expandBtn

                anchors.right: parent.right
                anchors.top: parent.top
                implicitWidth: 20
                implicitHeight: 20

                Text {
                    anchors.centerIn: parent
                    text: "▾"
                    color: Colors.subtext
                    font.family: root.uiFont
                    font.pixelSize: 12
                    rotation: root.expanded ? 180 : 0

                    Behavior on rotation {
                        Anim {}
                    }
                }

                StateLayer {
                    radius: Tokens.rounding.full
                    onClicked: root.expanded = !root.expanded
                }
            }

            // ── body ─────────────────────────────────────────────────────────
            // One elided line while collapsed, the whole thing once expanded. Both
            // exist at once and cross-fade, which is how the height animates cleanly.
            Text {
                id: bodyPreview

                anchors.left: summary.left
                anchors.right: parent.right
                anchors.top: summary.bottom

                text: root.modelData.body
                color: Colors.subtext
                font.family: root.uiFont
                font.pixelSize: 12
                elide: Text.ElideRight
                maximumLineCount: 1
                opacity: root.expanded ? 0 : 1

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            Text {
                id: body

                anchors.left: summary.left
                anchors.right: parent.right
                anchors.top: summary.bottom
                anchors.topMargin: Tokens.spacing.extraSmall

                textFormat: root.bodyTextFormat
                text: root.modelData.body
                color: Colors.subtext
                font.family: root.uiFont
                font.pixelSize: 12
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                onLinkActivated: link => {
                    Qt.openUrlExternally(link);
                    root.close();
                }
                opacity: root.expanded ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            // ── actions ──────────────────────────────────────────────────────
            RowLayout {
                id: actions

                anchors.left: summary.left
                anchors.right: parent.right
                anchors.top: body.bottom
                anchors.topMargin: Tokens.spacing.small

                spacing: Tokens.spacing.extraSmall
                opacity: root.expanded ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                PillButton {
                    label: "✕"
                    onActivated: root.close()
                }

                Repeater {
                    model: root.modelData.actions

                    PillButton {
                        required property var modelData

                        Layout.fillWidth: true
                        label: modelData.text
                        onActivated: {
                            modelData.invoke();
                            root.close();
                        }
                    }
                }

                PillButton {
                    label: copyTimer.running ? "Copied" : "Copy"
                    onActivated: {
                        Quickshell.clipboardText = root.modelData.body;
                        copyTimer.restart();
                    }

                    Timer {
                        id: copyTimer

                        interval: 2000
                    }
                }
            }
        }
    }

    readonly property string uiFont: "JetBrainsMono Nerd Font"

    // Small rounded button used for close, copy and each notification action.
    component PillButton: StyledRect {
        id: btn

        property string label
        signal activated

        implicitWidth: Math.max(implicitHeight, btnLabel.implicitWidth + Tokens.padding.medium * 2)
        implicitHeight: btnLabel.implicitHeight + Tokens.padding.small
        radius: Tokens.rounding.full
        color: root.critical ? Qt.alpha(Colors.red, 0.35) : Colors.surface1

        Text {
            id: btnLabel

            anchors.centerIn: parent
            width: Math.min(implicitWidth, btn.width - Tokens.padding.medium)
            text: btn.label
            color: Colors.fg
            font.family: root.uiFont
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        StateLayer {
            radius: btn.radius
            onClicked: btn.activated()
        }
    }
}
