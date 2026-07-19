// Bluetooth, network, volume, and battery.
//
// Three of these were shell scripts on a timer: bluetooth.sh spawned
// `bluetoothctl info` once PER DEVICE every 5 seconds, battery.sh re-read sysfs
// every 30, and both duplicated data the AGS panel was already reading over
// D-Bus. One service singleton now feeds both the bar glyph and the panel row.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import ".."

RowLayout {
    spacing: Tokens.spacing4

    // --- Bluetooth ---
    BarButton {
        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property var connected:
            Bluetooth.devices.values.filter(d => d.connected)

        visible: adapter !== null
        glyph: !adapter?.enabled ? "\u{f00b2}"
             : connected.length > 0 ? "\u{f00b1}"
             : "\u{f00af}"
        glyphColor: connected.length > 0 ? Accent.accent : Tokens.muted
        tooltip: {
            if (!adapter?.enabled) return "Bluetooth off";
            if (connected.length === 0) return "Bluetooth on";
            // Battery only when the device reports it — most do not.
            return connected.map(d => d.battery > 0
                ? `${d.name} (${Math.round(d.battery * 100)}%)`
                : d.name).join("\n");
        }
        onClicked: Quickshell.execDetached(["blueman-manager"])
    }

    // --- Network ---
    BarButton {
        glyph: "\u{f05a9}"
        tooltip: "Network"
        onClicked: Quickshell.execDetached(["nm-connection-editor"])
    }

    // --- Volume ---
    BarButton {
        readonly property var sink: Pipewire.defaultAudioSink
        readonly property real vol: sink?.audio?.volume ?? 0

        glyph: (sink?.audio?.muted ?? false) ? "\u{f075f}"
             : vol > 0.5 ? "\u{f057e}"
             : vol > 0 ? "\u{f0580}"
             : "\u{f0581}"
        tooltip: sink
            ? `${sink.description}: ${Math.round(vol * 100)}%`
            : "No audio sink"
        onClicked: Quickshell.execDetached(["pavucontrol"])
        // Scrolling the glyph is the one thing the Waybar module could not do
        // without a second module.
        onMiddleClicked: if (sink?.audio) sink.audio.muted = !sink.audio.muted
    }

    // --- Battery ---
    RowLayout {
        readonly property var bat: UPower.displayDevice
        // Desktops report no battery; the whole group disappears rather than
        // showing a permanent 0%, which is what battery.sh's `absent` class did.
        visible: bat?.isLaptopBattery ?? false
        spacing: Tokens.spacing1

        Glyph {
            readonly property real pct: parent.bat?.percentage ?? 0
            readonly property bool charging: parent.bat?.state === UPowerDeviceState.Charging

            text: charging ? "\u{f0084}"
                : pct > 0.85 ? "\u{f0079}"
                : pct > 0.60 ? "\u{f0082}"
                : pct > 0.30 ? "\u{f007f}"
                : pct > 0.10 ? "\u{f007b}"
                : "\u{f007a}"
            color: parent.bat?.percentage <= 0.10 ? Tokens.error
                 : parent.bat?.percentage <= 0.20 ? Tokens.warning
                 : Tokens.muted
        }

        Text {
            text: Math.round((parent.bat?.percentage ?? 0) * 100) + "%"
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.textXs
            color: Tokens.muted
        }
    }
}
