// The notification daemon and its popup stack.
//
// Owning the D-Bus notification server is what makes this shell a selectable
// backend in notification-daemon.sh, and it is also why the shell must not be
// restarted to apply a theme change: restarting drops the session's history.
// That constraint is why Accent.qml is a watched file rather than a push.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Notifications
import ".."

Scope {
    id: root

    // Persists for the session and survives a wallpaper/accent change. The panel
    // reads this same list for history.
    property alias notifications: server.trackedNotifications
    property bool dontDisturb: false

    // Quickshell's Notification carries no timestamp of its own, so the server
    // records arrival times here, keyed by notification id. Reading a `time`
    // property off the notification returned undefined, and every card rendered
    // that as "NaNd".
    property var _received: ({})

    // Undefined for anything that predates this scope — a config reload keeps
    // the notifications but not the map, and a card with no timestamp reads
    // better than a wrong one.
    function receivedAt(notif) {
        return notif ? _received[notif.id] : undefined;
    }

    NotificationServer {
        id: server
        keepOnReload: true

        // Advertised capabilities must match what the card actually renders, or
        // apps degrade to plain text for features we do have.
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: function (notif) {
            notif.tracked = true;
            // Stamped before the do-not-disturb bail: a suppressed notification
            // still lands in history and still needs its time.
            root._received[notif.id] = new Date();
            if (root.dontDisturb) return;

            // A replacement reuses an existing id, so it must NOT restart the
            // timer — otherwise a progress notification that updates every
            // second can never expire and sits on screen forever.
            const existing = popupModel.find(n => n.id === notif.id);
            if (existing) return;
            popupModel.push(notif);
            popupModel = popupModel.slice();
        }
    }

    property var popupModel: []

    Connections {
        target: server
        function onTrackedNotificationsChanged() {
            // Drop popups whose notification the app itself resolved.
            const live = server.trackedNotifications.values;
            root.popupModel = root.popupModel.filter(n => live.includes(n));

            // Arrival times outlive nothing: drop them with their notification,
            // or the map grows for as long as the session runs.
            const ids = new Set(live.map(n => n.id));
            for (const id of Object.keys(root._received))
                if (!ids.has(Number(id))) delete root._received[id];
        }
    }

    PanelWindow {
        anchors { top: true; right: true }
        margins { top: Tokens.spacing6; right: Tokens.spacing6 }

        implicitWidth: 340
        implicitHeight: Math.max(1, stack.implicitHeight)
        color: "transparent"
        visible: root.popupModel.length > 0
        // Overlay, not Top: a toast has to be visible over a fullscreen window,
        // which is the one case where it matters most.
        WlrLayershell.namespace: "hyprveil-notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusiveZone: 0

        ColumnLayout {
            id: stack
            width: parent.width
            spacing: Tokens.spacing3

            Repeater {
                model: root.popupModel

                NotificationCard {
                    required property var modelData
                    notif: modelData
                    received: root.receivedAt(modelData)
                    popup: true
                    Layout.fillWidth: true

                    onDismissed: {
                        modelData.dismiss();
                        root._drop(modelData);
                    }

                    // Critical notifications do not auto-expire. mako's config
                    // makes the same call (default-timeout=0 for critical): if
                    // it was worth interrupting for, it is worth acknowledging.
                    Timer {
                        running: !critical
                        interval: 5000
                        onTriggered: root._drop(modelData)
                    }

                    MouseArea {
                        anchors.fill: parent
                        // Behind the card's own content: without this, this
                        // area — declared after RowLayout and so stacked on
                        // top by default — swallows every click before it
                        // reaches the action buttons or the close button.
                        z: -1
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        // Middle dismisses outright; any other click only hides
                        // the popup and leaves the notification in history. That
                        // asymmetry is deliberate — a misclick should not
                        // destroy something you had not read yet.
                        onClicked: function (event) {
                            if (event.button === Qt.MiddleButton) modelData.dismiss();
                            root._drop(modelData);
                        }
                    }
                }
            }
        }
    }

    function _drop(notif) {
        popupModel = popupModel.filter(n => n !== notif);
    }

    function clearAll() {
        // Snapshot first. dismiss() removes the notification from
        // trackedNotifications synchronously, so iterating the live list shifts
        // it underneath the loop and every second entry gets skipped — clearing
        // six left three.
        const all = server.trackedNotifications.values.slice();
        for (const n of all) n.dismiss();
        popupModel = [];
    }

    // notification-daemon.sh toggle/dnd route here, the way they routed to
    // `ags request` before. The keybinds themselves never change: they have
    // always gone through the helper script.
    IpcHandler {
        target: "notifications"

        function dnd(): string {
            root.dontDisturb = !root.dontDisturb;
            if (root.dontDisturb) root.popupModel = [];
            return root.dontDisturb ? "on" : "off";
        }

        function clear(): string {
            root.clearAll();
            return "cleared";
        }

        function count(): string {
            return String(server.trackedNotifications.values.length);
        }
    }
}
