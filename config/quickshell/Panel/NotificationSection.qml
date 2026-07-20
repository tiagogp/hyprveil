// Notification history, plus do-not-disturb and clear-all.
//
// Reuses NotificationCard at popup: false, so a notification looks the same
// whether you caught it live or are reading it back — the two surfaces drifting
// apart is how the same message ends up looking like two different products.
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../Notif"

Section {
    id: root
    glyph: "\u{f009a}"
    title: "Notifications"

    // The Popups scope, passed down from shell.qml. One server, one history.
    property var notifications: null

    readonly property var items:
        notifications?.notifications?.values?.slice()?.reverse() ?? []

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing1
        spacing: Tokens.spacing2

        Item { Layout.fillWidth: true }

        Rectangle {
            implicitWidth: Tokens.spacing6 + Tokens.spacingHair
            implicitHeight: Tokens.spacing6 + Tokens.spacingHair
            radius: Tokens.radiusSm
            color: dndMouse.containsMouse || (root.notifications?.dontDisturb ?? false)
                ? Accent.accentSoft : Qt.rgba(1, 1, 1, 0.07)

            Glyph {
                anchors.centerIn: parent
                text: (root.notifications?.dontDisturb ?? false)
                    ? "\u{f009b}" : "\u{f009a}"
                size: Tokens.iconSm
                color: (root.notifications?.dontDisturb ?? false)
                    ? Accent.accent : Tokens.muted
            }

            MouseArea {
                id: dndMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.notifications)
                    root.notifications.dontDisturb = !root.notifications.dontDisturb
            }
        }

        Rectangle {
            implicitWidth: Tokens.spacing6 + Tokens.spacingHair
            implicitHeight: Tokens.spacing6 + Tokens.spacingHair
            radius: Tokens.radiusSm
            color: clearMouse.containsMouse ? Accent.accentSoft : Qt.rgba(1, 1, 1, 0.07)

            Glyph {
                anchors.centerIn: parent
                text: "\u{f00e2}"
                size: Tokens.iconSm
                color: clearMouse.containsMouse ? Accent.accent : Tokens.muted
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.notifications?.clearAll()
            }
        }
    }

    Text {
        renderType: Text.NativeRendering
        Layout.fillWidth: true
        visible: root.items.length === 0
        text: "No notifications"
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textXs
        color: Tokens.dim
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing2
        visible: root.items.length > 0

        Repeater {
            // Capped rather than scrolled: the panel is already the full height
            // of a section stack, and an unbounded history would push the
            // wallpaper entry off screen.
            model: root.items.slice(0, 6)

            NotificationCard {
                required property var modelData
                Layout.fillWidth: true
                notif: modelData
                received: root.notifications?.receivedAt(modelData)
                popup: false
                onDismissed: modelData.dismiss()
            }
        }
    }
}
