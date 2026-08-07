// Native session modal. Interactive controls come from Design/Components so
// pointer, keyboard focus, accessibility, hover, and reduced motion stay in
// sync with every other feature.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../Adapters"
import "../Design/Components"
import "../Services"

Scope {
    id: root

    property bool open: false
    property var targetScreen: null
    property int selected: 0
    property int confirming: -1

    readonly property var actions: [
        { id: "lock", label: "Lock", glyph: "\u{f033e}", confirm: false,
          run: () => SystemActions.lock() },
        { id: "suspend", label: "Suspend", glyph: "\u{f04b2}", confirm: false,
          run: () => SystemActions.suspend() },
        { id: "logout", label: "Log out", glyph: "\u{f0343}", confirm: true,
          run: () => SystemActions.logout() },
        { id: "reboot", label: "Restart", glyph: "\u{f0453}", confirm: true,
          run: () => SystemActions.reboot() },
        { id: "shutdown", label: "Shut down", glyph: "\u{f0425}", confirm: true,
          run: () => SystemActions.powerOff() }
    ]

    onOpenChanged: if (open) {
        selected = 0;
        confirming = -1;
    }

    function choose(index: int): void {
        const action = actions[index];
        if (!action) return;
        selected = index;
        if (action.confirm) confirming = index;
        else { action.run(); open = false; }
    }

    function confirm(): void {
        const action = actions[confirming];
        if (!action) return;
        action.run();
        open = false;
    }

    function back(): void {
        if (confirming >= 0) confirming = -1;
        else open = false;
    }

    PanelWindow {
        screen: root.targetScreen ?? Quickshell.screens[0]
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
            TapHandler { onTapped: root.back() }
        }

        HvDialog {
            id: dialog
            anchors.centerIn: parent
            accessibleName: confirming >= 0 ? "Confirm session action" : "Session"
            elevation: 3
            presented: root.open
            implicitWidth: Math.min(420, parent.width - Tokens.spacing8 * 2)
            implicitHeight: Math.min(440, parent.height - Tokens.spacing8 * 2)
            focus: true
            Keys.onEscapePressed: root.back()
            Keys.onUpPressed: if (confirming < 0) selected = Math.max(0, selected - 1)
            Keys.onDownPressed: if (confirming < 0) selected = Math.min(actions.length - 1, selected + 1)
            Keys.onReturnPressed: confirming < 0 ? choose(selected) : confirm()

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

            ColumnLayout {
                id: body
                anchors.fill: parent
                anchors.margins: Tokens.spacing4
                spacing: Tokens.spacing2

                HvHeader {
                    Layout.fillWidth: true
                    title: root.confirming >= 0 ? "Confirm action" : "Session"
                    subtitle: root.confirming >= 0 ? "This action can end your current work." : "Choose what happens next"
                    canGoBack: root.confirming >= 0
                    canClose: true
                    onBack: root.back()
                    onClose: root.open = false
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.confirming < 0
                    spacing: Tokens.spacing1

                    Repeater {
                        model: root.actions
                        HvActionRow {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            glyph: modelData.glyph
                            title: modelData.label
                            subtitle: modelData.confirm ? "Confirmation required" : ""
                            selected: root.selected === index
                            onActiveFocusChanged: if (activeFocus) root.selected = index
                            onClicked: root.choose(index)
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.confirming >= 0
                    spacing: Tokens.spacing3

                    HvEmptyState {
                        Layout.fillWidth: true
                        glyph: root.confirming >= 0 ? (root.actions[root.confirming]?.glyph ?? "") : ""
                        title: root.confirming >= 0 ? (root.actions[root.confirming]?.label ?? "") + " now?" : ""
                        detail: "Log out, restart, and shut down end the active session."
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Tokens.spacing2
                        HvButton { text: "Cancel"; onClicked: root.back() }
                        HvButton {
                            text: "Confirm"
                            primary: true
                            focus: root.confirming >= 0
                            accessibleName: "Confirm " + (root.actions[root.confirming]?.label ?? "action")
                            onClicked: root.confirm()
                        }
                    }
                }
            }
        }
    }

}
