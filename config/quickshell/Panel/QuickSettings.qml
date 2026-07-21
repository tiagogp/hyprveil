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
    // Which sections the panel shows. "all" is the full stack the SUPER+N
    // keybind and the IPC target open; "notifications" is what the bar's bell
    // opens, because a bell that answers with wifi and bluetooth is not the
    // control the glyph promised. Same window either way — a second panel would
    // be a second copy of the close button, the Escape handler, and the
    // layershell setup, all of which already drifted once between AGS sections.
    property string view: "all"
    readonly property bool notificationsOnly: view === "notifications"

    // Supplied by shell.qml so the history list and the popup stack read the
    // same notification server — two servers would mean two histories.
    property var notifications: null
    // The Wallpapers scope, passed down from shell.qml.
    property var wallpapers: null
    // The Cheatsheet scope, likewise. SUPER+slash opens it directly; this row
    // is the discoverable route for anyone who does not know that yet, which is
    // exactly the audience a cheatsheet has.
    property var cheatsheet: null

    PanelWindow {
        visible: root.open
        anchors { top: true; right: true }
        margins { top: Tokens.spacing2h; right: Tokens.spacing2h }

        implicitWidth: Math.max(0, Math.min(360, (screen?.width ?? 360) - Tokens.spacing2h * 2))
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
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                        text: root.notificationsOnly ? "Notifications" : "Quick Settings"
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textLg
                        font.weight: Tokens.weightBold
                        color: Tokens.text
                    }

                    Rectangle {
                        implicitWidth: Tokens.spacing6
                        implicitHeight: Tokens.spacing6
                        radius: Tokens.radiusPill
                        activeFocusOnTab: true
                        color: closeMouse.containsMouse
                            ? Accent.accentSoft : Qt.rgba(1, 1, 1, 0.08)
                        border.width: activeFocus ? 1 : 0
                        border.color: Accent.accent
                        Accessible.role: Accessible.Button
                        Accessible.name: "Close Quick Settings"

                        Keys.onReturnPressed: root.open = false
                        Keys.onSpacePressed: root.open = false

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

                WifiSection {
                    Layout.fillWidth: true
                    visible: !root.notificationsOnly
                }
                BluetoothSection {
                    Layout.fillWidth: true
                    visible: !root.notificationsOnly
                }
                AudioSection {
                    Layout.fillWidth: true
                    visible: !root.notificationsOnly
                }
                PowerProfileSection {
                    Layout.fillWidth: true
                    visible: !root.notificationsOnly
                }
                ClipboardSection {
                    Layout.fillWidth: true
                    visible: !root.notificationsOnly
                }
                NotificationSection {
                    Layout.fillWidth: true
                    notifications: root.notifications
                    // The panel header already reads "Notifications" in this
                    // mode; showing both stacked the same word twice.
                    showHeader: !root.notificationsOnly
                }

                // Opens the shell's own picker.
                LinkRow {
                    Layout.fillWidth: true
                    visible: !root.notificationsOnly
                    text: "Wallpapers…"
                    onClicked: {
                        root.open = false;
                        wallpapers.open = true;
                    }
                }

                LinkRow {
                    Layout.fillWidth: true
                    visible: !root.notificationsOnly
                    text: "Keyboard shortcuts…"
                    onClicked: {
                        root.open = false;
                        cheatsheet.open = true;
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

        // The IPC target is the full panel. A toggle that inherited whatever
        // view the bar's bell left behind would make SUPER+N's result depend on
        // what was clicked last.
        function toggle(): string {
            root.open = !root.open;
            root.view = "all";
            return root.open ? "open" : "closed";
        }

        function open(): string { root.view = "all"; root.open = true; return "open"; }
        function close(): string { root.open = false; return "closed"; }
    }
}
