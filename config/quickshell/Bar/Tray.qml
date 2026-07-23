// The system tray.
//
// The one thing StatusCluster could never be: it shows fixed glyphs for four
// known services, but a tray is whatever happens to be running — Telegram,
// nm-applet, a sync client — so it has to be a list driven by the model, not a
// hand-placed row. Waybar could not render this at all, which is why apps that
// only surface through a tray icon were simply invisible under the old bar.
//
// SystemTray.items is a StatusNotifierItem host; nothing here polls. The row
// disappears when nothing is registered rather than holding an empty gap, the
// same way the battery group in StatusCluster hides on a desktop.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import ".."

RowLayout {
    id: root

    // The bar window, so each item's context menu can anchor to the bar's own
    // geometry rather than a measured offset — passed down from Bar.qml the same
    // way Media receives it.
    property var barWindow: null

    spacing: Tokens.spacing3
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        TrayItem {
            required property var modelData
            item: modelData
            barWindow: root.barWindow
        }
    }
}
