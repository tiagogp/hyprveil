// The quick-settings panel.
//
// The design file never drew this screen — it has desktop, launcher,
// notifications, lock, and power menu, and nothing else — so the layout follows
// the AGS panel it replaces rather than inventing a target. What changes is that
// every size now comes from the token scale, which is where the AGS version had
// drifted: 16px panel radius against an 18px ramp, 9px and 12px control radii
// that were on no scale at all, and a 0.82 surface alpha the contrast budget
// explicitly rules out.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."

Scope {
    id: root

    property bool open: false
    // Supplied by shell.qml so the history list and the popup stack read the
    // same notification server — two servers would mean two histories.
    property var notifications: null
    // The Wallpapers scope, passed down from shell.qml.
    property var wallpapers: null

    PanelWindow {
        visible: root.open
        anchors { top: true; right: true }
        margins { top: Tokens.spacing2h; right: Tokens.spacing2h }

        implicitWidth: 360
        implicitHeight: Math.min(column.implicitHeight + Tokens.spacing3 * 2, 900)
        color: "transparent"
        WlrLayershell.namespace: "hyprveil-quicksettings"
        WlrLayershell.layer: WlrLayer.Top
        // OnDemand rather than Exclusive: the panel needs Escape, but must not
        // steal the keyboard from the focused window while it is merely open.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Surface {
            anchors.fill: parent
            elevation: 0
            radius: Tokens.radiusLg

            focus: true
            Keys.onEscapePressed: root.open = false

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: Tokens.spacing3
                spacing: Tokens.spacing2

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Tokens.spacing1

                    Text {
                        Layout.fillWidth: true
                        text: "Quick Settings"
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textLg
                        font.weight: Tokens.weightBold
                        color: Tokens.text
                    }

                    Rectangle {
                        implicitWidth: Tokens.spacing6
                        implicitHeight: Tokens.spacing6
                        radius: Tokens.radiusPill
                        color: closeMouse.containsMouse
                            ? Accent.accentSoft : Qt.rgba(1, 1, 1, 0.08)

                        Glyph {
                            anchors.centerIn: parent
                            text: "\u{f0156}"
                            size: Tokens.iconSm
                            color: closeMouse.containsMouse ? Accent.accent : Tokens.muted
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.open = false
                        }
                    }
                }

                WifiSection { Layout.fillWidth: true }
                BluetoothSection { Layout.fillWidth: true }
                NotificationSection {
                    Layout.fillWidth: true
                    notifications: root.notifications
                }

                // Opens the shell's own picker.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Tokens.spacing8
                    radius: Tokens.radiusSm
                    color: wpMouse.containsMouse
                        ? Accent.accentSoft : Qt.rgba(1, 1, 1, 0.06)

                    Text {
                        anchors.centerIn: parent
                        text: "Wallpapers…"
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textXs
                        color: wpMouse.containsMouse ? Accent.accent : Tokens.muted
                    }

                    MouseArea {
                        id: wpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.open = false;
                            wallpapers.open = true;
                        }
                    }
                }
            }
        }
    }

    // notification-daemon.sh toggle routes here, the way it routed to
    // `ags request toggle-quicksettings` before. The SUPER+N keybind is
    // unchanged: it has always gone through the helper script.
    IpcHandler {
        target: "quicksettings"

        function toggle(): string {
            root.open = !root.open;
            return root.open ? "open" : "closed";
        }

        function open(): string { root.open = true; return "open"; }
        function close(): string { root.open = false; return "closed"; }
    }
}
