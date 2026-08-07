pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth as QBluetooth
import "../Adapters"

Singleton {
    readonly property var adapter: QBluetooth.Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property var state: ({
        enabled: adapter?.enabled ?? false,
        connected: QBluetooth.Bluetooth.devices.values.filter(device => device.connected)
    })
    property bool busy: false
    property string error: ""
    property double lastUpdated: Date.now()

    function refresh(): void { lastUpdated = Date.now(); }
    function setEnabled(value: bool): void {
        if (adapter && adapter.enabled !== value) adapter.enabled = value;
        lastUpdated = Date.now();
    }
    function openManager(): void { SystemActions.openBluetoothControl(); }
}
