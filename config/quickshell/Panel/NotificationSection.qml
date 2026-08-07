// Notification history, plus do-not-disturb and clear-all.
//
// Reuses NotificationCard at popup: false, so a notification looks the same
// whether you caught it live or are reading it back — the two surfaces drifting
// apart is how the same message ends up looking like two different products.
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../Design/Components"
import "../Notif"

HvSection {
    id: root
    glyph: "\u{f009a}"
    title: "Notifications"

    // The Popups scope, passed down from shell.qml. One server, one history.
    property var notifications: null

    readonly property var items:
        notifications?.notifications?.values?.slice()?.reverse() ?? []

    // Persisted entries from a session before this one — see Popups.sessionStartTs
    // — grouped by app so a dozen notifications from one chat client collapse
    // into one row instead of burying everything else in the panel. Newest
    // group first, and within a group, newest entry first.
    readonly property var earlierGroups: {
        const cutoff = notifications?.sessionStartTs ?? 0;
        const earlier = (notifications?.persistedHistory ?? []).filter(n => n.ts < cutoff);
        const order = [];
        const byApp = {};
        for (const n of earlier) {
            const key = n.app || "Unknown";
            if (!byApp[key]) { byApp[key] = []; order.push(key); }
            byApp[key].push(n);
        }
        return order.map(key => ({
            app: key,
            entries: byApp[key],
            latest: byApp[key][0],
            sids: byApp[key].map(n => n.sid)
        }));
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing1
        spacing: Tokens.spacing2

        Item { Layout.fillWidth: true }

        Rectangle {
            implicitWidth: Tokens.spacing6 + Tokens.spacingHair
            implicitHeight: Tokens.spacing6 + Tokens.spacingHair
            radius: Tokens.radiusSm
            activeFocusOnTab: true
            color: dndMouse.containsMouse || (root.notifications?.dontDisturb ?? false)
                ? Accent.accentSoft : Qt.rgba(1, 1, 1, 0.07)
            border.width: activeFocus ? 1 : 0
            border.color: Accent.accent
            Accessible.role: Accessible.CheckBox
            Accessible.name: "Do not disturb"

            function activate() {
                if (root.notifications)
                    root.notifications.dontDisturb = !root.notifications.dontDisturb;
            }

            Keys.onReturnPressed: activate()
            Keys.onSpacePressed: activate()

            Glyph {
                anchors.centerIn: parent
                text: (root.notifications?.dontDisturb ?? false)
                    ? "\u{f009b}" : "\u{f009a}"
                size: Tokens.iconSm
                color: (root.notifications?.dontDisturb ?? false)
                    ? Accent.accent : Tokens.muted
            }

            HvPointerArea {
                id: dndMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.activate()
            }
        }

        Rectangle {
            implicitWidth: Tokens.spacing6 + Tokens.spacingHair
            implicitHeight: Tokens.spacing6 + Tokens.spacingHair
            radius: Tokens.radiusSm
            activeFocusOnTab: true
            color: clearMouse.containsMouse ? Accent.accentSoft : Qt.rgba(1, 1, 1, 0.07)
            border.width: activeFocus ? 1 : 0
            border.color: Accent.accent
            Accessible.role: Accessible.Button
            Accessible.name: "Clear notifications"

            Keys.onReturnPressed: root.notifications?.clearAll()
            Keys.onSpacePressed: root.notifications?.clearAll()

            Glyph {
                anchors.centerIn: parent
                text: "\u{f00e2}"
                size: Tokens.iconSm
                color: clearMouse.containsMouse ? Accent.accent : Tokens.muted
            }

            HvPointerArea {
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
        spacing: Tokens.spacing3
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

    // Grouped history from before this session — see earlierGroups above.
    // One row per app, not per notification: expanding every message from a
    // chat client individually is exactly the inbox-complexity the roadmap
    // calls out as unwanted.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: root.items.length > 0 ? Tokens.spacing2 : 0
        spacing: Tokens.spacingHair
        visible: root.earlierGroups.length > 0

        Text {
            renderType: Text.NativeRendering
            Layout.fillWidth: true
            text: "Earlier"
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.text2xs
            font.weight: Tokens.weightSemibold
            color: Tokens.dim
        }

        Repeater {
            // Groups, not raw entries — capped generously since each row is
            // one line regardless of how many notifications it represents.
            model: root.earlierGroups.slice(0, 8)

            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Tokens.spacing2

                Text {
                    renderType: Text.NativeRendering
                    Layout.preferredWidth: 96
                    text: modelData.app
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.textXs
                    font.weight: Tokens.weightMedium
                    color: Tokens.muted
                    elide: Text.ElideRight
                }

                Text {
                    renderType: Text.NativeRendering
                    Layout.fillWidth: true
                    text: modelData.entries.length > 1
                        ? modelData.latest.summary + " (+" + (modelData.entries.length - 1) + ")"
                        : modelData.latest.summary
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.textXs
                    color: Tokens.dim
                    elide: Text.ElideRight
                }

                Rectangle {
                    implicitWidth: Tokens.spacing5
                    implicitHeight: Tokens.spacing5
                    radius: Tokens.radiusSm
                    activeFocusOnTab: true
                    color: earlierDismiss.containsMouse ? Accent.accentSoft : "transparent"
                    Accessible.role: Accessible.Button
                    Accessible.name: "Clear " + modelData.app + " history"

                    function clear() {
                        for (const sid of modelData.sids)
                            root.notifications?.removePersisted(sid);
                    }
                    Keys.onReturnPressed: clear()
                    Keys.onSpacePressed: clear()

                    Glyph {
                        anchors.centerIn: parent
                        text: "\u{f0156}"
                        size: Tokens.iconSm
                        color: earlierDismiss.containsMouse ? Accent.accent : Tokens.dim
                    }

                    HvPointerArea {
                        id: earlierDismiss
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.clear()
                    }
                }
            }
        }
    }
}
