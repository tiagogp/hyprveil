// One notification, used by both the popup stack and the panel history.
//
// It was one shared component in AGS too — worth keeping that way, because the
// two surfaces drifting apart is how a notification ends up looking like a
// different product depending on whether you caught it in time.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import ".."
import "../Adapters"

Surface {
    id: card

    required property var notif
    // Supplied by whoever owns the notification server, because the
    // notification itself has no timestamp — see Popups.receivedAt.
    property var received: undefined
    // Popups are transient and sit above everything; history sits inside a
    // panel that already has its own elevation.
    property bool popup: true

    readonly property int urgency: notif?.urgency ?? NotificationUrgency.Normal
    readonly property bool critical: urgency === NotificationUrgency.Critical
    readonly property bool low: urgency === NotificationUrgency.Low

    signal dismissed()

    implicitWidth: 340
    implicitHeight: layout.implicitHeight + Tokens.spacing4 * 2

    // Rev 02 groups every floating widget on one shadow tier — see
    // MediaCard.qml. History cards stay at tier 1: they sit inside a panel
    // that already carries its own elevation.
    elevation: popup ? 2 : 1
    radius: Tokens.radiusMd
    // Critical borrows the accent border rather than inventing a red: the
    // palette has exactly one attention color and two would compete.
    border.color: critical ? Accent.accent : Qt.rgba(1, 1, 1, _border)
    color: critical
        ? Qt.rgba(Accent.accent.r, Accent.accent.g, Accent.accent.b, 0.12)
        : Qt.rgba(tint.r, tint.g, tint.b, low ? _alpha * 0.8 : _alpha)

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Tokens.spacing4
        spacing: Tokens.spacing3

        // The tinted circle behind the app icon. mako cannot draw this at all,
        // which is one of the two things its config file documents as
        // unreproducible.
        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 36
            implicitHeight: 36
            radius: Tokens.radiusSm
            color: card.critical || card.popup ? Accent.accentSoft : Tokens.elevated
            border.width: card.critical || card.popup ? 1 : 0
            border.color: Accent.accent

            IconImage {
                anchors.centerIn: parent
                implicitSize: Tokens.iconMd
                // Same as the dock: an app icon arrives as a theme name, and an
                // unresolvable one has to fall through to the glyph below rather
                // than warn on every repaint.
                source: Quickshell.iconPath(card.notif?.appIcon ?? "", true)
                visible: source !== ""
            }

            Glyph {
                anchors.centerIn: parent
                visible: (card.notif?.appIcon ?? "") === ""
                text: "\u{f009a}"
                size: Tokens.iconSm
                color: Accent.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing1

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing2

                Text {
                    renderType: Text.NativeRendering
                    Layout.fillWidth: true
                    text: card.notif?.summary ?? ""
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.textSm
                    font.weight: Tokens.weightSemibold
                    color: card.critical ? Accent.accent : Tokens.text
                    elide: Text.ElideRight
                }

                Text {
                    renderType: Text.NativeRendering
                    text: Time.ago(card.received)
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.text2xs
                    color: Tokens.dim
                }
            }

            // Notification bodies carry Pango markup by spec. StyledText is the
            // closest Qt equivalent — deliberately not RichText, which would
            // accept full HTML including remote <img> from any app on the bus.
            Text {
                renderType: Text.NativeRendering
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notif?.body ?? ""
                textFormat: Text.StyledText
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.textXs
                color: Tokens.muted
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
                lineHeight: 1.3
                onLinkActivated: link => SystemActions.openUri(link)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing1
                visible: (card.notif?.actions?.length ?? 0) > 0
                spacing: Tokens.spacing2

                Repeater {
                    model: card.notif?.actions ?? []

                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: Tokens.spacing6 + Tokens.spacing1
                        radius: Tokens.radiusSm
                        activeFocusOnTab: true
                        color: actionMouse.containsMouse
                            ? Accent.accentSoft
                            : Qt.rgba(Accent.accent.r, Accent.accent.g, Accent.accent.b, 0.12)
                        border.width: activeFocus ? 1 : 0
                        border.color: Accent.accent
                        Accessible.role: Accessible.Button
                        Accessible.name: "Notification action " + modelData.text

                        Keys.onReturnPressed: modelData.invoke()
                        Keys.onSpacePressed: modelData.invoke()

                        Text {
                            renderType: Text.NativeRendering
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.spacing2
                            anchors.rightMargin: Tokens.spacing2
                            text: modelData.text
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.textXs
                            color: Accent.accent
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.invoke()
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: Tokens.spacing6
            implicitHeight: Tokens.spacing6
            radius: Tokens.radiusPill
            activeFocusOnTab: true
            color: closeMouse.containsMouse
                ? Accent.accentSoft
                : Qt.rgba(1, 1, 1, 0.08)
            border.width: activeFocus ? 1 : 0
            border.color: Accent.accent
            Accessible.role: Accessible.Button
            Accessible.name: "Dismiss notification"

            Keys.onReturnPressed: card.dismissed()
            Keys.onSpacePressed: card.dismissed()

            Glyph {
                anchors.centerIn: parent
                text: "\u{f0156}"
                size: Tokens.iconSm
                color: closeMouse.containsMouse ? Accent.accent : Tokens.muted
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.dismissed()
            }
        }
    }
}
