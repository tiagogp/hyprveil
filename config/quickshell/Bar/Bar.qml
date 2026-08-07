// Single floating top bar.
//
// The full-width PanelWindow still reserves one predictable strip and handles
// every monitor, but only the glass bar accepts pointer input. Region keeps the
// outer margins true click-through space instead of invisible layer-shell hit
// targets.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import ".."
import "../App"
import "../Design/Components"
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
    readonly property bool showMediaLabel: displayMode !== "compact"

    // Rev 02's detached-chrome geometry: inset 12 on the sides, 10 off the top
    // — an asymmetric margin rather than the uniform 10 every edge used before,
    // so the bar reads as floating clear of the corner rather than centred in
    // a padding box.
    anchors { top: true; left: true; right: true }
    margins { top: Tokens.spacing2h; left: Tokens.spacing3; right: Tokens.spacing3 }

    implicitHeight: 44
    color: "transparent"
    WlrLayershell.namespace: "hyprveil-bar"
    WlrLayershell.layer: WlrLayer.Top

    mask: Region { item: barSurface }

    // Quick settings and the calendar grab pointer input to close on an
    // outside click; the bar registers itself so that grab doesn't swallow
    // clicks on its own buttons — including the one that opened the panel.
    Component.onCompleted: {
        quickSettings?.registerBar(bar);
        calendar?.registerBar(bar);
    }
    Component.onDestruction: {
        quickSettings?.unregisterBar(bar);
        calendar?.unregisterBar(bar);
    }

    HvChrome {
        id: barSurface
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: 44
        height: implicitHeight
        elevation: 1
        radius: Tokens.radiusMd

        Item {
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacing3
            anchors.rightMargin: Tokens.spacing3

            RowLayout {
                id: leftContent
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth,
                    Math.max(0, centerButton.x - Tokens.spacing3))
                height: implicitHeight
                clip: true
                spacing: Tokens.spacing2

                Workspaces { id: workspaces }

                BarDivider { visible: !bar.compact }

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

            Rectangle {
                id: centerButton
                readonly property bool active: bar.calendar?.open ?? false
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: centerRow.implicitWidth + Tokens.spacing5
                implicitHeight: Tokens.iconHit
                width: implicitWidth
                height: implicitHeight
                radius: Tokens.radiusMd
                color: active ? Accent.accentSoft : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Motion.duration(Tokens.dur1)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.easeStandard
                    }
                }

                RowLayout {
                    id: centerRow
                    anchors.centerIn: parent
                    spacing: Tokens.spacing1h

                    Glyph {
                        text: "\u{f00ed}"
                        size: Tokens.iconSm
                        color: centerButton.active ? Accent.accentOnChrome : Accent.dimOnChrome

                        // The glyph's ink sits a couple of px below the
                        // Nerd Font's own vertical center, so AlignVCenter
                        // reads as low next to the date text; nudge it up
                        // to match dateTime's optical center.
                        transform: Translate { y: -2 }

                        Behavior on color {
                            ColorAnimation {
                                duration: Motion.duration(Tokens.dur1)
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Tokens.easeStandard
                            }
                        }
                    }

                    Text {
                        id: dateTime
                        text: Qt.formatDateTime(Time.today,
                            bar.compact ? "ddd · hh:mm" : "ddd, MMM d · hh:mm")
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textSm
                        font.weight: Tokens.weightSemibold
                        color: centerButton.active
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

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SurfaceCoordinator.toggle("calendar", bar.screen, centerButton)
                }

                Accessible.role: Accessible.Button
                Accessible.name: "Open calendar, " + dateTime.text
            }

            RowLayout {
                id: rightContent
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: implicitWidth
                height: implicitHeight
                spacing: 0

                Media {
                    id: media
                    // Calm Mode collapses media to its icon-only form, same
                    // as the compact breakpoint already does — one code path
                    // for "less room" and "less noise wanted" rather than two.
                    displayMode: (bar.showMediaLabel && !CalmMode.collapseMedia) ? "full" : "icon"
                    labelMaximumWidth: bar.full
                        ? (bar.monitorWidth >= 2560 ? 180 : 100) : 84
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
                    // true center clock clear. Six-item trays are therefore safe.
                    // Calm Mode also collapses it regardless of width — "tray
                    // sob demanda" — since a visible tray is exactly the kind
                    // of ambient noise the mode exists to remove.
                    collapsed: !bar.full || count > (bar.monitorWidth >= 1920 ? 3 : 1)
                        || CalmMode.trayOnDemand
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
                    screen: bar.screen
                    displayMode: bar.displayMode
                }

                BarDivider {
                    Layout.leftMargin: Tokens.spacing1
                    Layout.rightMargin: Tokens.spacing1
                }

                BarAction {
                    id: wallpaperAction
                    visible: !bar.compact
                    glyph: "\u{f0976}"
                    tooltip: "Wallpaper"
                    active: bar.wallpapers?.open ?? false
                    onClicked: SurfaceCoordinator.toggle("wallpapers", bar.screen, wallpaperAction)
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
                    onClicked: {
                        if (bar.quickSettings) bar.quickSettings.view = "notifications";
                        SurfaceCoordinator.toggle("quick-settings", bar.screen, notificationAction);
                    }
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
                    id: powerAction
                    glyph: "\u{f0425}"
                    tooltip: "Power"
                    accentOnHover: true
                    onClicked: SurfaceCoordinator.toggle("session", bar.screen, powerAction)
                }
            }
        }
    }
}
