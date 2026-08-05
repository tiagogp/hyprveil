// StatusNotifier host with an inline wide mode and an anchored compact drawer.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import ".."

RowLayout {
    id: root

    property var hostWindow: null
    property bool collapsed: false
    property bool drawerOpen: false
    readonly property int count: SystemTray.items.values.length

    spacing: Tokens.spacing3
    visible: count > 0

    RowLayout {
        visible: !root.collapsed
        spacing: Tokens.spacing3

        Repeater {
            model: SystemTray.items

            TrayItem {
                required property var modelData
                item: modelData
                hostWindow: root.hostWindow
            }
        }
    }

    BarAction {
        id: drawerAction
        visible: root.collapsed
        glyph: "\u{f0417}"
        tooltip: root.count === 1 ? "1 tray item" : `${root.count} tray items`
        active: root.drawerOpen
        onClicked: root.drawerOpen = !root.drawerOpen
    }

    PopupWindow {
        id: drawer
        anchor.item: drawerAction
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.adjustment: PopupAdjustment.All
        anchor.margins.bottom: Tokens.spacing2
        implicitWidth: drawerRow.implicitWidth + Tokens.spacing3 * 2
        implicitHeight: 44 + Tokens.spacing2 * 2
        color: "transparent"
        grabFocus: true
        visible: root.collapsed && root.drawerOpen && root.count > 0
        onVisibleChanged: if (!visible) root.drawerOpen = false

        Surface {
            anchors.fill: parent
            elevation: 2
            radius: Tokens.radiusMd

            RowLayout {
                id: drawerRow
                anchors.centerIn: parent
                spacing: Tokens.spacing2

                Repeater {
                    model: SystemTray.items

                    TrayItem {
                        required property var modelData
                        item: modelData
                        hostWindow: drawer
                    }
                }
            }
        }
    }
}
