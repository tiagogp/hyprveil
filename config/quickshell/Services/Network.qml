pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import "../Adapters"

Singleton {
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool available: wifiDevice !== null
    readonly property var state: ({ enabled: Networking.wifiEnabled })
    property bool busy: false
    property string error: ""
    property double lastUpdated: Date.now()

    function refresh(): void { lastUpdated = Date.now(); }
    function setEnabled(value: bool): void {
        if (available && Networking.wifiEnabled !== value) Networking.wifiEnabled = value;
        lastUpdated = Date.now();
    }
    function openEditor(): void { SystemActions.openNetworkEditor(); }
    function connectWifi(name: string): void { if (available) SystemActions.connectWifi(name); }
}
