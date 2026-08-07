// Native session/power modal — the roadmap's "Power/session nativo".
//
// wlogout drew a themed grid but, like Rofi before the launcher got one,
// shared no state, motion, or keyboard convention with the rest of the
// shell. This is that convention applied to the same five actions
// Launcher.qml's system-action rows already expose — the difference here is
// that THIS is the deliberate, always-confirmed entry point (SUPER+Escape,
// Ctrl+Alt+Delete): every action is a two-step press, Escape at either step
// backs out one level rather than exiting blind, and nothing destructive
// fires on a single Enter. wlogout remains bound as an explicit fallback
// (`$mod SHIFT, Escape` — see keybindings.conf) for the same reason Rofi
// stayed bound after the launcher shipped.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../Services"

Scope {
    id: root

    property bool open: false
    property int selected: 0
    // -1 = choosing an action; >= 0 = confirming the action at that index.
    property int confirming: -1

    readonly property var actions: [
        { id: "lock", label: "Lock", glyph: "\u{f033e}", confirm: false,
          run: () => Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/lock.sh"]) },
        { id: "suspend", label: "Suspend", glyph: "\u{f04b2}", confirm: false,
          run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        { id: "logout", label: "Log out", glyph: "\u{f0343}", confirm: true,
          run: () => Hyprland.dispatch("exit") },
        { id: "reboot", label: "Restart", glyph: "\u{f0453}", confirm: true,
          run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { id: "shutdown", label: "Shut down", glyph: "\u{f0425}", confirm: true,
          run: () => Quickshell.execDetached(["systemctl", "poweroff"]) }
    ]

    onOpenChanged: {
        if (open) {
            root.selected = 0;
            root.confirming = -1;
        }
    }

    function choose(index) {
        const action = root.actions[index];
        if (!action) return;
        if (action.confirm) {
            root.confirming = index;
        } else {
            action.run();
            root.open = false;
        }
    }

    function confirm() {
        const action = root.actions[root.confirming];
        if (!action) return;
        action.run();
        root.open = false;
    }

    // Escape backs out one level: from a confirmation to the picker, from
    // the picker closed entirely — never a silent no-op on the key that
    // exists specifically to let someone bail.
    function back() {
        if (root.confirming >= 0) root.confirming = -1;
        else root.open = false;
    }

    PanelWindow {
        id: win
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "hyprveil-session"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            MouseArea { anchors.fill: parent; onClicked: root.back() }
        }

        Surface {
            anchors.centerIn: parent
            elevation: 3
            radius: Tokens.radiusLg

            transform: Translate {
                y: root.open ? 0 : -Tokens.spacing6
                Behavior on y {
                    NumberAnimation {
                        duration: Motion.duration(Tokens.durModal)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.easeModal
                    }
                }
            }

            implicitWidth: Math.min(420, parent.width - Tokens.spacing8 * 2)
            implicitHeight: column.implicitHeight + Tokens.spacing4 * 2

            focus: true
            Keys.onEscapePressed: root.back()
            Keys.onLeftPressed: if (root.confirming < 0)
                root.selected = Math.max(0, root.selected - 1)
            Keys.onRightPressed: if (root.confirming < 0)
                root.selected = Math.min(root.actions.length - 1, root.selected + 1)
            Keys.onReturnPressed: root.confirming < 0 ? root.choose(root.selected) : root.confirm()
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: Tokens.spacing4
                spacing: Tokens.spacing3

                // --- Picker --------------------------------------------
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing3
                    visible: root.confirming < 0

                    Text {
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                        text: "Session"
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textLg
                        font.weight: Tokens.weightBold
                        color: Tokens.text
                        horizontalAlignment: Text.AlignHCenter
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Tokens.spacing2

                        Repeater {
                            model: root.actions

                            Rectangle {
                                required property var modelData
                                required property int index
                                implicitWidth: 72
                                implicitHeight: 72
                                radius: Tokens.radiusMd
                                color: root.selected === index
                                    ? Accent.accentSoft : Qt.rgba(1, 1, 1, 0.06)
                                border.width: root.selected === index ? 1 : 0
                                border.color: Accent.accent

                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.label

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing1

                                    Glyph {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.glyph
                                        size: Tokens.iconMd
                                        color: root.selected === index ? Accent.accent : Tokens.muted
                                    }
                                    Text {
                                        renderType: Text.NativeRendering
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.label
                                        font.family: Tokens.fontUi
                                        font.pixelSize: Tokens.text2xs
                                        font.weight: Tokens.weightMedium
                                        color: Tokens.text
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.selected = index
                                    onClicked: root.choose(index)
                                }
                            }
                        }
                    }

                    Text {
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                        text: "← → to choose, Enter to select, Escape to cancel"
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.text2xs
                        color: Tokens.dim
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // --- Confirmation ----------------------------------------
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing3
                    visible: root.confirming >= 0

                    Text {
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                        text: root.confirming >= 0
                            ? "Log out, restart, and shut down end your session — "
                              + (root.actions[root.confirming]?.label ?? "") + " now?"
                            : ""
                        wrapMode: Text.WordWrap
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textSm
                        color: Tokens.text
                        horizontalAlignment: Text.AlignHCenter
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Tokens.spacing2

                        Rectangle {
                            implicitWidth: 96
                            implicitHeight: Tokens.spacing8
                            radius: Tokens.radiusSm
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Accessible.role: Accessible.Button
                            Accessible.name: "Cancel"
                            activeFocusOnTab: true
                            Keys.onReturnPressed: root.back()
                            Keys.onSpacePressed: root.back()

                            Text {
                                renderType: Text.NativeRendering
                                anchors.centerIn: parent
                                text: "Cancel"
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.textSm
                                color: Tokens.muted
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.back()
                            }
                        }

                        Rectangle {
                            implicitWidth: 96
                            implicitHeight: Tokens.spacing8
                            radius: Tokens.radiusSm
                            color: Accent.accentSoft
                            border.width: 1
                            border.color: Accent.accent
                            Accessible.role: Accessible.Button
                            Accessible.name: "Confirm " + (root.actions[root.confirming]?.label ?? "")
                            activeFocusOnTab: true
                            focus: root.confirming >= 0
                            Keys.onReturnPressed: root.confirm()
                            Keys.onSpacePressed: root.confirm()

                            Text {
                                renderType: Text.NativeRendering
                                anchors.centerIn: parent
                                text: "Confirm"
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.textSm
                                font.weight: Tokens.weightSemibold
                                color: Accent.accent
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.confirm()
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "session"

        function toggle(): string {
            root.open = !root.open;
            return root.open ? "open" : "closed";
        }
        function open(): string { root.open = true; return "open"; }
        function close(): string { root.open = false; return "closed"; }
    }
}
