// Three-island floating top bar.
//
// The full-width PanelWindow still reserves one predictable strip and handles
// every monitor, but only the three glass islands accept pointer input. Region
// makes the transparent gaps true click-through space instead of invisible
// layer-shell hit targets.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import ".."
import "../Services"

PanelWindow {
    id: bar

    property var notifications: null
    property var quickSettings: null
    property var wallpapers: null
    property var calendar: null

    readonly property real monitorWidth: screen?.width ?? width
    readonly property string displayMode:
        monitorWidth >= 1600 ? "full"
        : monitorWidth >= 1280 ? "standard" : "compact"
    readonly property bool full: displayMode === "full"
    readonly property bool compact: displayMode === "compact"

    anchors { top: true; left: true; right: true }
    margins { top: Tokens.spacing2h; left: Tokens.spacing2h; right: Tokens.spacing2h }

    implicitHeight: 44
    color: "transparent"
    WlrLayershell.namespace: "hyprveil-bar"
    WlrLayershell.layer: WlrLayer.Top

    mask: Region {
        item: leftIsland
        Region { item: centerIsland }
        Region { item: rightIsland }
    }

    BarIsland {
        id: leftIsland
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        RowLayout {
            spacing: Tokens.spacing2

            Workspaces { id: workspaces }

            BarDivider { visible: !bar.compact }

            IconImage {
                visible: !bar.compact && Compositor.activeIconSource !== ""
                source: Compositor.activeIconSource
                implicitSize: Tokens.iconSm
            }

            Text {
                Layout.maximumWidth: bar.full ? 240 : 140
                visible: !bar.compact
                text: Compositor.activeTitle
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.textXs
                font.weight: Tokens.weightMedium
                color: Tokens.muted
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }
    }

    BarIsland {
        id: centerIsland
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        active: bar.calendar?.open ?? false
        interactive: true
        accessibleName: "Open calendar, " + dateTime.text
        onClicked: if (bar.calendar)
            bar.calendar.open = !bar.calendar.open

        Item {
            implicitWidth: dateTime.implicitWidth
            implicitHeight: Tokens.iconHit

            Text {
                id: dateTime
                anchors.centerIn: parent
                text: Qt.formatDateTime(Time.today,
                    bar.compact ? "ddd · hh:mm" : "ddd, MMM d · hh:mm")
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.textSm
                font.weight: Tokens.weightSemibold
                color: (bar.calendar?.open ?? false)
                    ? Accent.accentOnChrome : Tokens.text
                renderType: Text.NativeRendering

                Behavior on color {
                    ColorAnimation {
                        duration: Motion.duration(Tokens.dur1)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.easeStandard
                    }
                }
            }

        }
    }

    BarIsland {
        id: rightIsland
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        RowLayout {
            spacing: 0

            Media {
                id: media
                displayMode: bar.full ? "full" : "icon"
                labelMaximumWidth: bar.monitorWidth >= 2560 ? 180 : 100
            }

            BarDivider {
                visible: media.visible
                Layout.leftMargin: Tokens.spacing1
                Layout.rightMargin: Tokens.spacing1
            }

            Tray {
                id: tray
                hostWindow: bar
                // At 1600px one icon costs the same width as the drawer action;
                // larger trays collapse until there is enough room to keep the
                // true center island clear. Six-item trays are therefore safe.
                collapsed: !bar.full || count > (bar.monitorWidth >= 1920 ? 3 : 1)
            }

            BarDivider {
                visible: tray.visible
                Layout.leftMargin: Tokens.spacing1
                Layout.rightMargin: Tokens.spacing1
            }

            SysMonitor {
                visible: bar.full
                compact: bar.monitorWidth < 1920
            }

            BarDivider {
                visible: bar.full
                Layout.leftMargin: Tokens.spacing1
                Layout.rightMargin: Tokens.spacing1
            }

            StatusCluster {
                quickSettings: bar.quickSettings
                displayMode: bar.displayMode
            }

            BarDivider {
                Layout.leftMargin: Tokens.spacing1
                Layout.rightMargin: Tokens.spacing1
            }

            BarAction {
                visible: !bar.compact
                glyph: "\u{f0976}"
                tooltip: "Wallpaper"
                active: bar.wallpapers?.open ?? false
                onClicked: if (bar.wallpapers)
                    bar.wallpapers.open = !bar.wallpapers.open
            }

            BarAction {
                id: notificationAction

                readonly property int count:
                    bar.notifications?.notifications?.values?.length ?? 0
                readonly property bool dnd:
                    bar.notifications?.dontDisturb ?? false

                glyph: dnd ? "\u{f009b}" : "\u{f009a}"
                tooltip: dnd ? "Do not disturb"
                    : count > 0 ? `${count} notifications` : "Notifications"
                glyphColor: dnd ? Accent.dimOnChrome
                    : count > 0 ? Accent.accentOnChrome : Tokens.muted
                active: bar.quickSettings?.open
                    && bar.quickSettings?.view === "notifications"
                onClicked: bar.quickSettings?.toggleSection("notifications")
                onRightClicked: if (bar.notifications)
                    bar.notifications.dontDisturb = !bar.notifications.dontDisturb

                Rectangle {
                    readonly property string countLabel:
                        notificationAction.count > 9 ? "9+"
                        : String(notificationAction.count)

                    visible: notificationAction.count > 0 && !notificationAction.dnd
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: Tokens.spacingHair
                    anchors.rightMargin: Tokens.spacingHair
                    implicitHeight: Tokens.spacing3
                    implicitWidth: Math.max(implicitHeight,
                        badgeText.implicitWidth + Tokens.spacing1)
                    radius: Tokens.radiusPill
                    color: Accent.accentOnChrome
                    border.width: 1
                    border.color: Tokens.chromeTint

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: parent.countLabel
                        font.family: Tokens.fontUi
                        font.pixelSize: 9
                        font.weight: Tokens.weightSemibold
                        color: Accent.accentFg
                        renderType: Text.NativeRendering
                    }
                }
            }

            BarAction {
                glyph: "\u{f0425}"
                tooltip: "Power"
                accentOnHover: true
                onClicked: Quickshell.execDetached([
                    "sh", "-c",
                    Quickshell.env("HOME") + "/.config/wlogout/power-menu.sh"
                ])
            }
        }
    }
}
