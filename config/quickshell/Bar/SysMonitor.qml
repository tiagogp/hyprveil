// CPU, memory, and (where a sensor exists) temperature in the bar.
//
// Reads the SysInfo singleton, which is the only thing that touches procfs —
// this is pure presentation. It registers as a watcher so the poll loop runs
// only while the monitor is actually in the bar, and each metric warns in the
// shared warning colour once it crosses into the red rather than turning the
// whole cluster into an alarm.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Services"
import ".."

RowLayout {
    id: root

    spacing: Tokens.spacing3
    property bool watching: false
    property bool compact: false

    function syncWatch(): void {
        if (visible && !watching) {
            SysInfo.watch();
            watching = true;
        } else if (!visible && watching) {
            SysInfo.unwatch();
            watching = false;
        }
    }

    // Responsive layouts keep this component instantiated while hiding it, so
    // visibility — not object lifetime — owns the poll subscription.
    Component.onCompleted: syncWatch()
    onVisibleChanged: syncWatch()
    Component.onDestruction: if (watching) SysInfo.unwatch()

    // At the lower edge of the full breakpoint all three values remain visible,
    // but share one compact readout so the right island cannot cross the stable
    // center island.
    RowLayout {
        visible: root.compact
        spacing: Tokens.spacing1h

        Glyph {
            text: "\u{f035b}"
            size: Tokens.iconSm
            color: SysInfo.cpu > 0.9 || SysInfo.memory > 0.9
                ? Tokens.warning : Tokens.muted
        }

        Text {
            text: `${Math.round(SysInfo.cpu * 100)}% · `
                + `${Math.round(SysInfo.memory * 100)}%`
                + (SysInfo.hasTemperature
                    ? ` · ${Math.round(SysInfo.temperature)}°` : "")
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.textXs
            color: Tokens.muted
            renderType: Text.NativeRendering
        }
    }

    // CPU
    RowLayout {
        visible: !root.compact
        spacing: Tokens.spacing1

        Glyph {
            text: "\u{f0ee0}" // md-cpu-64-bit
            size: Tokens.iconSm
            color: SysInfo.cpu > 0.9 ? Tokens.warning : Tokens.muted
        }

        Text {
            renderType: Text.NativeRendering
            text: Math.round(SysInfo.cpu * 100) + "%"
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.textXs
            color: Tokens.muted
        }
    }

    // Memory
    RowLayout {
        visible: !root.compact
        spacing: Tokens.spacing1

        Glyph {
            text: "\u{f035b}" // md-memory
            size: Tokens.iconSm
            color: SysInfo.memory > 0.9 ? Tokens.warning : Tokens.muted
        }

        Text {
            renderType: Text.NativeRendering
            text: Math.round(SysInfo.memory * 100) + "%"
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.textXs
            color: Tokens.muted
        }
    }

    // Temperature — only when a CPU thermal zone was found, the same way the
    // battery group hides itself on a desktop rather than showing a dead 0.
    RowLayout {
        spacing: Tokens.spacing1
        visible: !root.compact && SysInfo.hasTemperature

        Glyph {
            text: "\u{f050f}" // md-thermometer
            size: Tokens.iconSm
            color: SysInfo.temperature >= 85 ? Tokens.error
                 : SysInfo.temperature >= 75 ? Tokens.warning
                 : Tokens.muted
        }

        Text {
            renderType: Text.NativeRendering
            text: Math.round(SysInfo.temperature) + "°"
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.textXs
            color: Tokens.muted
        }
    }
}
