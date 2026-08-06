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
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import ".."

Scope {
    id: root

    property bool open: false
    // Which sections the panel shows. The bar routes status controls straight
    // to their matching section while the IPC target continues to open the full
    // stack. One window owns every view so close/focus/layer-shell behavior
    // cannot drift between separate panels.
    property string view: "all"
    readonly property bool notificationsOnly: view === "notifications"
    readonly property bool contextual: view !== "all"
    readonly property string viewTitle: {
        switch (view) {
        case "wifi": return "Wi-Fi";
        case "bluetooth": return "Bluetooth";
        case "audio": return "Audio";
        case "notifications": return "Notifications";
        default: return "Quick Settings";
        }
    }

    function toggleSection(section: string): void {
        const valid = ["all", "notifications", "wifi", "bluetooth", "audio"];
        const next = valid.includes(section) ? section : "all";
        if (root.open && root.view === next) {
            root.open = false;
            return;
        }
        root.view = next;
        root.open = true;
    }

    // Supplied by shell.qml so the history list and the popup stack read the
    // same notification server — two servers would mean two histories.
    property var notifications: null
    // The Wallpapers scope, passed down from shell.qml.
    property var wallpapers: null
    // The Cheatsheet scope, likewise. SUPER+slash opens it directly; this row
    // is the discoverable route for anyone who does not know that yet, which is
    // exactly the audience a cheatsheet has.
    property var cheatsheet: null

    // Bar windows, one per monitor, registered by Bar.qml itself. They are
    // exempt from the outside-click dismissal below — without that, the
    // first click on any bar button while the panel was open would only
    // close the panel instead of also doing what the button does, since the
    // panel's focus grab would swallow it.
    property var barWindows: []

    function registerBar(bar): void {
        if (root.barWindows.indexOf(bar) === -1)
            root.barWindows = root.barWindows.concat([bar]);
    }
    function unregisterBar(bar): void {
        root.barWindows = root.barWindows.filter(w => w !== bar);
    }

    PanelWindow {
        id: win
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

        // Grabs pointer/keyboard input at the compositor so a click anywhere
        // outside the panel — and outside the bar it was opened from — closes
        // it, the way any other popover does. Layer-shell has no such
        // primitive of its own; this is the Hyprland-specific stand-in for it.
        HyprlandFocusGrab {
            id: focusGrab
            windows: [win].concat(root.barWindows)
            onCleared: root.open = false
        }
        onVisibleChanged: focusGrab.active = visible

        Surface {
            anchors.fill: parent
            // Rev 02 draws quick settings with the same shadow as every other
            // floating widget (frame 2g) rather than sitting flat.
            elevation: 2
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
                        text: root.viewTitle
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
                    visible: root.view === "all" || root.view === "wifi"
                    // The panel header already reads "Wi-Fi" in this mode;
                    // showing both stacked the same word twice.
                    showHeader: root.view !== "wifi"
                }
                BluetoothSection {
                    Layout.fillWidth: true
                    visible: root.view === "all" || root.view === "bluetooth"
                    // Same reasoning: contextual view titles itself already.
                    showHeader: root.view !== "bluetooth"
                }
                AudioSection {
                    Layout.fillWidth: true
                    visible: root.view === "all" || root.view === "audio"
                    // Same reasoning: contextual view titles itself already.
                    showHeader: root.view !== "audio"
                }
                NightLightSection {
                    Layout.fillWidth: true
                    visible: root.view === "all"
                }
                PowerProfileSection {
                    Layout.fillWidth: true
                    visible: root.view === "all"
                }
                ClipboardSection {
                    Layout.fillWidth: true
                    visible: root.view === "all"
                }
                NotificationSection {
                    Layout.fillWidth: true
                    notifications: root.notifications
                    visible: root.view === "all" || root.view === "notifications"
                    // The panel header already reads "Notifications" in this
                    // mode; showing both stacked the same word twice.
                    showHeader: !root.notificationsOnly
                }
                AccentSection {
                    Layout.fillWidth: true
                    visible: root.view === "all"
                }

                // Opens the shell's own picker.
                LinkRow {
                    Layout.fillWidth: true
                    visible: root.view === "all"
                    text: "Wallpapers…"
                    onClicked: {
                        root.open = false;
                        wallpapers.open = true;
                    }
                }

                LinkRow {
                    Layout.fillWidth: true
                    visible: root.view === "all"
                    text: "Keyboard shortcuts…"
                    onClicked: {
                        root.open = false;
                        cheatsheet.open = true;
                    }
                }

                LinkRow {
                    Layout.fillWidth: true
                    visible: root.contextual
                    text: "All settings…"
                    onClicked: root.view = "all"
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
