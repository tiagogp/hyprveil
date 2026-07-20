// The top bar.
//
// One process draws this on every monitor (see shell.qml), where Waybar needed a
// second bar definition and a separate module set.
//
// Still a deviation from the mockup, which fills the bar at 0.5 alpha: at that
// fill the window title below is illegible over a bright wallpaper. But the bar
// does not sit at tier 0 either. Tier 0's 0.88 is pinned by the 4.5:1 body-text
// floor, and the bar has no body text — the title is the widest string it ever
// draws — so it takes $chrome-alpha (0.76), where muted still clears the 3.0:1
// AA floor for UI text. See the contrast budget in docs/TOKENS.md.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../Services"

PanelWindow {
    id: bar

    // The panel scopes, supplied by shell.qml. Left null-safe throughout: a bar
    // that loses its panel should drop a click, not tear down the whole shell.
    property var notifications: null
    property var quickSettings: null
    property var wallpapers: null

    anchors { top: true; left: true; right: true }
    margins { top: Tokens.spacing2h; left: Tokens.spacing2h; right: Tokens.spacing2h }

    implicitHeight: 44
    color: "transparent"
    WlrLayershell.namespace: "hyprveil-bar"
    WlrLayershell.layer: WlrLayer.Top

    Surface {
        anchors.fill: parent
        elevation: 0
        alphaOverride: Tokens.chromeAlpha
        tint: "#14161a"
        radius: Tokens.radiusMd

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacing3
            anchors.rightMargin: Tokens.spacing3
            spacing: 0

            Workspaces { Layout.alignment: Qt.AlignVCenter }

            Item { Layout.fillWidth: true }

            // The focused window's title. Elided rather than wrapped or
            // truncated at a character count, so a long path degrades instead of
            // pushing the right cluster off the bar.
            Text {
                Layout.maximumWidth: bar.width * 0.35
                Layout.alignment: Qt.AlignVCenter
                text: Compositor.activeTitle
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.textSm
                font.weight: Tokens.weightMedium
                color: Tokens.muted
                elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Tokens.spacing4

                Media {}
                StatusCluster {}

                // The wallpaper picker was reachable only from inside quick
                // settings, which buried the one control that changes how the
                // whole desktop looks two clicks deep.
                BarButton {
                    glyph: "\u{f0976}"
                    tooltip: "Wallpaper"
                    glyphColor: (bar.wallpapers?.open ?? false)
                        ? Accent.accent : Tokens.muted
                    onClicked: if (bar.wallpapers)
                        bar.wallpapers.open = !bar.wallpapers.open
                }

                // Notifications. The badge counts HISTORY, not live popups — a
                // toast that timed out unread is precisely what this button
                // exists to surface, and counting popups would show zero in the
                // one case that matters.
                BarButton {
                    id: notifButton

                    readonly property int count:
                        bar.notifications?.notifications?.values?.length ?? 0
                    readonly property bool dnd:
                        bar.notifications?.dontDisturb ?? false

                    glyph: dnd ? "\u{f009b}" : "\u{f009a}"
                    tooltip: dnd ? "Do not disturb"
                        : count > 0 ? `${count} notifications` : "Notifications"
                    glyphColor: dnd ? Tokens.dim
                        : count > 0 ? Accent.accent : Tokens.muted
                    onClicked: if (bar.quickSettings)
                        bar.quickSettings.open = !bar.quickSettings.open
                    // Right-click silences without opening the panel. Muting is
                    // the thing you want at the moment a toast interrupts you,
                    // and routing it through the panel costs three clicks.
                    onRightClicked: if (bar.notifications)
                        bar.notifications.dontDisturb = !bar.notifications.dontDisturb

                    // Suppressed under DND: the bell-off glyph already says the
                    // count is not being shown to you, and a live badge next to
                    // it reads as a contradiction.
                    Rectangle {
                        visible: notifButton.count > 0 && !notifButton.dnd
                        anchors {
                            top: parent.top
                            right: parent.right
                            topMargin: -Tokens.spacingHair
                            rightMargin: -Tokens.spacingHair
                        }

                        implicitWidth: Tokens.spacing4
                        implicitHeight: Tokens.spacing4
                        radius: Tokens.radiusPill
                        color: Accent.accent

                        Text {
                            anchors.centerIn: parent
                            // Capped at one digit. The badge is a fixed circle
                            // on a 24px button, and "12" at this size is a smear
                            // — past a few unread the exact number stops being
                            // the information anyway.
                            text: notifButton.count > 9
                                ? "9+" : String(notifButton.count)
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.text2xs
                            font.weight: Tokens.weightSemibold
                            color: Accent.accentFg
                        }
                    }
                }

                Text {
                    text: Time.clock
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.textSm
                    font.weight: Tokens.weightSemibold
                    color: Tokens.text
                }

                BarButton {
                    glyph: "\u{f0425}"
                    tooltip: "Power"
                    accentOnHover: true
                    onClicked: Quickshell.execDetached(
                        ["sh", "-c", Quickshell.env("HOME") + "/.config/wlogout/power-menu.sh"])
                }
            }
        }
    }
}
