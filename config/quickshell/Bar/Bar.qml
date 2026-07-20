// The top bar.
//
// One process draws this on every monitor (see shell.qml), where Waybar needed a
// second bar definition and a separate module set.
//
// Deliberate deviation from the mockup: the design fills the bar at 0.5 alpha,
// and the Waybar implementation copied that. The contrast budget in
// docs/TOKENS.md rules it out — muted text at #9a9ca5 over a bright wallpaper
// already lands at 4.05:1 at 0.82 alpha, under the 4.5:1 floor, and 0.5 is far
// worse. Tier 0 (0.88) is the glassiest fill that stays legible, so the bar uses
// it and the mockup's number is treated as pre-token art direction.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../Services"

PanelWindow {
    id: bar

    anchors { top: true; left: true; right: true }
    margins { top: Tokens.spacing2h; left: Tokens.spacing2h; right: Tokens.spacing2h }

    implicitHeight: 44
    color: "transparent"
    WlrLayershell.namespace: "hyprveil-bar"
    WlrLayershell.layer: WlrLayer.Top

    Surface {
        anchors.fill: parent
        elevation: 0
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
