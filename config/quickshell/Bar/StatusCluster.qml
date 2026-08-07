// Connectivity, audio and battery controls for the right side of the bar.
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import ".."
import "../App"

RowLayout {
    id: root

    property var quickSettings: null
    property var screen: null
    property string displayMode: "full" // full | standard | compact
    readonly property bool compact: displayMode === "compact"

    spacing: 0

    function toggleSection(section: string, origin: var): void {
        if (root.quickSettings) root.quickSettings.view = section;
        SurfaceCoordinator.toggle("quick-settings", root.screen, origin);
    }

    BarAction {
        id: bluetoothAction
        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property var connected:
            Bluetooth.devices.values.filter(d => d.connected)

        visible: adapter !== null && (!root.compact || connected.length > 0)
        glyph: !adapter?.enabled ? "\u{f00b2}"
            : connected.length > 0 ? "\u{f00b1}" : "\u{f00af}"
        glyphColor: connected.length > 0 ? Accent.accentOnChrome : Tokens.muted
        active: root.quickSettings?.open
            && root.quickSettings?.view === "bluetooth"
        tooltip: {
            if (!adapter?.enabled) return "Bluetooth off";
            if (connected.length === 0) return "Bluetooth on";
            return connected.map(d => d.battery > 0
                ? `${d.name} (${Math.round(d.battery * 100)}%)`
                : d.name).join("\n");
        }
        accessibleName: tooltip
        onClicked: root.toggleSection("bluetooth", bluetoothAction)
    }

    BarAction {
        id: wifiAction
        readonly property var wifiDevice:
            Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null

        glyph: wifiDevice !== null && !Networking.wifiEnabled
            ? "\u{f092f}" : "\u{f05a9}"
        tooltip: wifiDevice === null ? "Network" :
            Networking.wifiEnabled ? "Wi-Fi" : "Wi-Fi off"
        active: root.quickSettings?.open && root.quickSettings?.view === "wifi"
        onClicked: root.toggleSection("wifi", wifiAction)
    }

    BarAction {
        id: audioAction
        readonly property var sink: Pipewire.defaultAudioSink
        readonly property real volume: sink?.audio?.volume ?? 0

        glyph: (sink?.audio?.muted ?? false) ? "\u{f075f}"
            : volume > 0.5 ? "\u{f057e}"
            : volume > 0 ? "\u{f0580}" : "\u{f0581}"
        tooltip: sink
            ? `${sink.description}: ${Math.round(volume * 100)}%`
            : "No audio sink"
        active: root.quickSettings?.open && root.quickSettings?.view === "audio"
        onClicked: root.toggleSection("audio", audioAction)
        onMiddleClicked: if (sink?.audio) sink.audio.muted = !sink.audio.muted
    }

    BarAction {
        readonly property var source: Pipewire.defaultAudioSource
        readonly property bool muted: source?.audio?.muted ?? false

        visible: source !== null && !root.compact
        glyph: muted ? "\u{f036d}" : "\u{f036c}"
        glyphColor: muted ? Tokens.warning : Tokens.muted
        tooltip: source
            ? `${source.description}: ${muted ? "Muted" : "Unmuted"}`
            : "No audio source"
        onClicked: if (source?.audio) source.audio.muted = !source.audio.muted
        onMiddleClicked: root.toggleSection("audio", audioAction)
    }

    Item {
        readonly property var battery: UPower.displayDevice
        readonly property real percentage: battery?.percentage ?? 0
        readonly property bool charging:
            battery?.state === UPowerDeviceState.Charging

        visible: battery?.isLaptopBattery ?? false
        implicitWidth: batteryAction.implicitWidth
        implicitHeight: batteryAction.implicitHeight

        BarAction {
            id: batteryAction
            anchors.fill: parent
            glyph: parent.charging ? "\u{f0084}"
                : parent.percentage > 0.85 ? "\u{f0079}"
                : parent.percentage > 0.60 ? "\u{f0082}"
                : parent.percentage > 0.30 ? "\u{f007f}"
                : parent.percentage > 0.10 ? "\u{f007b}" : "\u{f007a}"
            glyphColor: parent.percentage <= 0.10 ? Tokens.error
                : parent.percentage <= 0.20 ? Tokens.warning : Tokens.muted
            label: Math.round(parent.percentage * 100) + "%"
            showLabel: !root.compact
            labelMaximumWidth: 44
            tooltip: `${Math.round(parent.percentage * 100)}% battery`
            onClicked: root.toggleSection("all", batteryAction)
        }
    }
}
