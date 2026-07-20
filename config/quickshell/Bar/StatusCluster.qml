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
    id: cluster

    spacing: Tokens.spacing4

    // The settings pages the three glyphs below open. These were
    // blueman-manager, nm-connection-editor, and pavucontrol — three unrelated
    // GTK3 dialogs, so three adjacent bar icons opened three different-looking
    // windows. One GTK4 app with a panel argument makes them one window that
    // lands on the right page.
    //
    // Wrapped in `env` because gnome-control-center refuses to start at all
    // under anything it does not recognise ("only supported under GNOME and
    // Unity, exiting"), and Hyprland sets XDG_CURRENT_DESKTOP=Hyprland. The
    // override is scoped to this one process rather than the session, which
    // would change how every XDG portal and desktop-entry lookup resolves.
    function openSettings(panel: string): void {
        Quickshell.execDetached(
            ["env", "XDG_CURRENT_DESKTOP=GNOME", "gnome-control-center", panel]);
    }

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
        onClicked: cluster.openSettings("bluetooth")
    }

    // --- Network ---
    BarButton {
        glyph: "\u{f05a9}"
        tooltip: "Network"
        // `wifi`, not `network`: the wifi panel is the one with the network
        // list, which is what the glyph is about. `network` opens VPN and wired.
        onClicked: cluster.openSettings("wifi")
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
        onClicked: cluster.openSettings("sound")
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
            renderType: Text.NativeRendering
            text: Math.round((parent.bat?.percentage ?? 0) * 100) + "%"
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.textXs
            color: Tokens.muted
        }
    }
}
