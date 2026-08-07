// "Sistema > Integrações" — the capability doctor, made visible.
//
// Every fallback this shell already has (missing backlight, missing
// hyprsunset, missing ddcutil, …) used to fail silently: the control simply
// did not appear. This is the same information, but askable — available,
// degraded, or missing, with the one command that fixes it, exactly the
// "estado de saúde visível" gap the roadmap describes.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../Design/Components"
import "../Services"

Scope {
    id: root

    property bool open: false
    property var targetScreen: null

    onOpenChanged: if (open) Capabilities.refresh()

    PanelWindow {
        id: win
        screen: root.targetScreen ?? Quickshell.screens[0]
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "hyprveil-integrations"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            TapHandler { onTapped: root.open = false }
        }

        HvDialog {
            anchors.centerIn: parent
            elevation: 3
            presented: root.open
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

            implicitWidth: Math.min(460, parent.width - Tokens.spacing8 * 2)
            implicitHeight: Math.min(560, parent.height - Tokens.spacing8 * 2)

            focus: true
            Keys.onEscapePressed: root.open = false

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: Tokens.spacing4
                spacing: Tokens.spacing3

                HvHeader {
                    Layout.fillWidth: true
                    title: "Integrations"
                    subtitle: Capabilities.loading ? "Checking…"
                        : `${Capabilities.availableCount} available · ${Capabilities.missingCount} missing`
                    canClose: true
                    onClose: root.open = false
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(list.implicitHeight, 420)
                    contentWidth: width
                    contentHeight: list.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: list
                        width: parent.width
                        spacing: Tokens.spacing2

                        Repeater {
                            model: Capabilities.rows

                            ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: Tokens.spacingHair

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Tokens.spacing2

                                    Rectangle {
                                        implicitWidth: Tokens.spacing2
                                        implicitHeight: Tokens.spacing2
                                        radius: Tokens.radiusPill
                                        color: modelData.available ? Tokens.success
                                             : modelData.degraded ? Tokens.warning : Tokens.dim
                                    }

                                    Text {
                                        renderType: Text.NativeRendering
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        font.family: Tokens.fontUi
                                        font.pixelSize: Tokens.textSm
                                        font.weight: Tokens.weightMedium
                                        color: Tokens.text
                                    }

                                    Text {
                                        renderType: Text.NativeRendering
                                        text: modelData.available ? "Available"
                                            : modelData.degraded ? "Degraded" : "Missing"
                                        font.family: Tokens.fontUi
                                        font.pixelSize: Tokens.text2xs
                                        font.weight: Tokens.weightSemibold
                                        color: modelData.available ? Tokens.success
                                             : modelData.degraded ? Tokens.warning : Tokens.dim
                                    }
                                }

                                Text {
                                    renderType: Text.NativeRendering
                                    Layout.fillWidth: true
                                    Layout.leftMargin: Tokens.spacing4
                                    visible: modelData.hint !== ""
                                    text: modelData.hint
                                    font.family: Tokens.fontMono
                                    font.pixelSize: Tokens.text2xs
                                    color: Tokens.dim
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }

                HvActionRow {
                    Layout.fillWidth: true
                    text: "Refresh"
                    onClicked: Capabilities.refresh()
                }
            }
        }
    }

    IpcHandler {
        target: "integrations"

        function toggle(): string {
            root.open = !root.open;
            return root.open ? "open" : "closed";
        }
        function open(): string { root.open = true; return "open"; }
        function close(): string { root.open = false; return "closed"; }
    }
}
