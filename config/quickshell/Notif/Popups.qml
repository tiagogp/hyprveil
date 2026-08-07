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
import "../Services"

Scope {
    id: root

    // Persists for the session and survives a wallpaper/accent change. The panel
    // reads this same list for history.
    property alias notifications: server.trackedNotifications
    property bool dontDisturb: false
    onDontDisturbChanged: root.statusCapsule?.show(
        root.dontDisturb ? "\u{f0392}" : "\u{f0391}",
        "Do Not Disturb " + (root.dontDisturb ? "on" : "off"));

    // The transient status capsule, handed down from shell.qml — see
    // Osd/StatusCapsule.qml. DND is toggled from two places (the bar and the
    // notification section), so this watches the ONE property both of them
    // already write to rather than needing a capsule call added at each site.
    property var statusCapsule: null

    // Bounds the "Earlier" list in the panel to notifications from a PREVIOUS
    // session: everything from this one is already in `notifications` above,
    // and persisting also writes those, so without this cutoff every live
    // notification would double up as its own history entry.
    readonly property double sessionStartTs: Date.now() / 1000

    // Notifications from a session that ended — appName/summary/image/urgency
    // only, never the body; see notification-store.sh for why. Rendered by
    // NotificationSection as read-only rows beneath the live/tracked ones.
    // Each entry is already shaped like the subset of a Quickshell Notification
    // that NotificationCard reads (summary/body/appIcon/urgency/actions), so
    // the same card renders both without a second code path.
    readonly property var persistedHistory: NotificationStore.state.map(r => ({
        sid: r.sid,
        app: r.app ?? "",
        summary: r.summary ?? "",
        body: "",
        appIcon: r.image ?? "",
        urgency: r.urgency === "critical" ? NotificationUrgency.Critical
               : r.urgency === "low" ? NotificationUrgency.Low
               : NotificationUrgency.Normal,
        actions: [],
        ts: r.ts ?? 0
    }))

    function removePersisted(sid) {
        NotificationStore.remove(sid);
    }

    function clearPersisted() {
        NotificationStore.clear();
    }

    Component.onCompleted: NotificationStore.refresh()

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

            // Persisted regardless of DND, same as the in-memory history —
            // only metadata, per notification-store.sh's privacy scope.
            const urgencyName = notif.urgency === NotificationUrgency.Critical ? "critical"
                : notif.urgency === NotificationUrgency.Low ? "low" : "normal";
            NotificationStore.append(notif.appName ?? "", notif.summary ?? "",
                notif.appIcon ?? "", urgencyName);

            if (root.dontDisturb) return;
            // Calm Mode's narrower suppression: non-urgent popups are held
            // back while a Critical one always reaches the screen — see
            // CalmMode.suppressPopup. History already has the entry either
            // way, from the append above.
            if (CalmMode.suppressPopup(notif.urgency === NotificationUrgency.Critical)) return;

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
        root.clearPersisted();
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
