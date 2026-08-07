// Calm Mode as a contract, not a preset — see the competitive analysis'
// "Diferenciais possíveis": DND for non-urgent popups, collapsed media, a
// tray that waits to be asked, and paused animation, all reversible and all
// stacking on top of (never replacing) the controls that already exist.
//
// Two ways in, one combined `active`: a manual switch in Preferences
// (Settings.modules.calmMode, sticky until turned off) and an automatic one
// — unplugged and under a low battery threshold, the same "quiet unless it
// matters" reasoning Silere's default already validated. Either can be
// undone at any moment: turning the manual switch off, or plugging in,
// clears `active` immediately.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    property bool available: true
    readonly property var state: ({ active: root.active, reason: root.reason })
    property bool busy: false
    property string error: ""
    property double lastUpdated: 0

    // Below this percentage AND discharging, calm mode engages on its own.
    // Desktops report no battery at all (UPower.displayDevice.isLaptopBattery
    // is false), so this branch never fires there — no surprise behaviour on
    // hardware that has nothing to save power on.
    readonly property int batteryThreshold: 20

    readonly property bool manualOn: Settings.modules.calmMode ?? false

    readonly property var battery: UPower.displayDevice
    readonly property bool onBattery:
        (battery?.isLaptopBattery ?? false)
        && battery?.state === UPowerDeviceState.Discharging
    readonly property bool batteryLow:
        onBattery && (battery?.percentage ?? 1) * 100 <= root.batteryThreshold

    readonly property bool active: root.manualOn || root.batteryLow
    // Surfaced so a status row can say WHY it is active rather than just
    // that it is — an unexplained state change reads as a bug, not a feature.
    readonly property string reason:
        root.manualOn ? "manual" : (root.batteryLow ? "battery" : "")

    // What "active" asks of the shell. Each is its own property, not a single
    // opaque flag, so a consumer only takes the one behaviour it owns instead
    // of a component reaching into a mode it does not otherwise know about.
    readonly property bool collapseMedia: root.active
    readonly property bool trayOnDemand: root.active
    readonly property bool pauseAnimations: root.active

    // Popups.qml calls this instead of hardcoding urgency logic itself. The
    // manual per-session DND toggle (Popups.dontDisturb) still blocks
    // everything, unchanged — this only adds a SECOND, narrower suppression
    // that calm mode owns: non-urgent popups are held back, but a Critical
    // notification (a battery warning, a calendar alarm) always reaches the
    // screen. That is the "exceções urgentes" half of the contract; the
    // "nenhuma perda de notificação" half is already true regardless, since
    // every popup is persisted to history before this is ever consulted.
    function suppressPopup(urgencyIsCritical: bool): bool {
        return root.active && !urgencyIsCritical;
    }

    function toggleManual(): void {
        Settings.set({ modules: Object.assign({}, Settings.modules, { calmMode: !root.manualOn }) });
        root.lastUpdated = Date.now();
    }
    function refresh(): void { root.lastUpdated = Date.now(); }
}
