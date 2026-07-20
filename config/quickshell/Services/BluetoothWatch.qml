// Turns Bluetooth state changes into desktop notifications.
//
// UNVERIFIED: the development machine has no Bluetooth adapter at all
// (/sys/class/bluetooth does not exist), so none of the notification paths below
// have been observed firing. The property names come from Quickshell.Bluetooth's
// introspected surface, and the delegate never fires before it is primed, but
// the debounce timings in particular are reasoned rather than measured.
//
// Notifications are sent with notify-send rather than injected internally,
// because Quickshell's NotificationServer receives — it has no API to originate.
// Going out over D-Bus and back in is not a workaround: it means these behave
// exactly like any other notification, so they land in history and respect
// do-not-disturb without a second code path.
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Item {
    id: root

    // Below this, warn once. Below the second, warn again — a headset that dies
    // mid-call should have said something twice, not once at 20%.
    readonly property var batteryThresholds: [0.20, 0.10]

    // Injectable so the debounce and latch logic can be exercised without a
    // Bluetooth adapter — this machine has none, and the alternative is shipping
    // the timing rules with nothing having ever run them.
    property var devicesModel: Bluetooth.devices
    property bool sendExternally: true

    // Emitted for every notification, whether or not it is actually sent.
    signal notified(string summary, string body, string urgency)

    function notify(summary: string, body: string, icon: string, urgency: string) {
        notified(summary, body, urgency);
        if (!sendExternally) return;
        Quickshell.execDetached([
            "notify-send",
            "--app-name=Bluetooth",
            "--icon=" + (icon && icon.length > 0 ? icon : "bluetooth"),
            "--urgency=" + urgency,
            summary, body
        ]);
    }

    Instantiator {
        model: root.devicesModel

        delegate: QtObject {
            id: watcher
            required property var modelData

            readonly property string label: modelData.name ?? modelData.address ?? "Device"
            readonly property bool connected: modelData.connected
            readonly property real battery: modelData.battery ?? 0

            // Suppresses the initial binding evaluation. Without it, every
            // already-connected device announces itself at login, which is the
            // fastest way to make someone disable the feature.
            property bool primed: false
            // Last state actually announced, so a flap that settles back where
            // it started stays silent.
            property bool announced: false
            // Index of the lowest threshold already warned about; reset when the
            // battery recovers, so one charge cycle produces one warning per
            // level rather than one per poll.
            property int batteryStage: -1

            readonly property Timer settle: Timer {
                // BlueZ toggles `connected` several times while pairing and
                // during a reconnect. Announcing each edge produces a burst of
                // contradictory toasts, so the value has to hold still first.
                interval: 1500
                onTriggered: {
                    if (!watcher.primed) return;
                    if (watcher.connected === watcher.announced) return;
                    watcher.announced = watcher.connected;
                    if (watcher.connected) {
                        watcher.batteryStage = -1;
                        root.notify(watcher.label, "Connected",
                                    watcher.modelData.icon ?? "", "low");
                    } else {
                        root.notify(watcher.label, "Disconnected",
                                    watcher.modelData.icon ?? "", "low");
                    }
                }
            }

            onConnectedChanged: settle.restart()

            onBatteryChanged: {
                if (!primed || !connected) return;
                // Zero means "does not report", not "flat" — most devices never
                // report at all, and warning about them would be constant.
                if (battery <= 0) return;

                if (batteryStage >= 0
                    && battery > root.batteryThresholds[0] + 0.05) {
                    batteryStage = -1;   // recovered; re-arm
                    return;
                }

                for (let i = root.batteryThresholds.length - 1; i >= 0; i--) {
                    if (battery <= root.batteryThresholds[i] && batteryStage < i) {
                        batteryStage = i;
                        root.notify(
                            watcher.label,
                            "Battery low — " + Math.round(battery * 100) + "%",
                            watcher.modelData.icon ?? "",
                            i === root.batteryThresholds.length - 1 ? "critical" : "normal");
                        return;
                    }
                }
            }

            Component.onCompleted: {
                announced = connected;
                primed = true;
            }
        }
    }
}
