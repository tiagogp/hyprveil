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

    // The poll loop idles unless something is watching; the monitor is that
    // something for as long as it exists in the bar.
    Component.onCompleted: SysInfo.watch()
    Component.onDestruction: SysInfo.unwatch()

    // CPU
    RowLayout {
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
        visible: SysInfo.hasTemperature

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
