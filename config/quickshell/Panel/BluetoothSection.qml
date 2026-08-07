// Bluetooth devices.
//
// UNVERIFIED ON THE DEVELOPMENT MACHINE: it has no Bluetooth adapter at all
// (/sys/class/bluetooth does not exist), so only the "no adapter" branch has
// been exercised. Property names come from Quickshell.Bluetooth's introspected
// surface — defaultAdapter, adapters, devices — not from guesswork.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import ".."
import "../Adapters"
import "../Design/Components"

HvSection {
    id: root
    glyph: "\u{f00af}"
    title: "Bluetooth"

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: {
        if (!adapter) return [];
        // Connected first, then paired. An unnamed device is an address the user
        // cannot identify, so it is dropped rather than shown as a MAC.
        return Bluetooth.devices.values
            .filter(d => d.name && d.name.length > 0)
            .sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0));
    }

    HvToggle {
        Layout.alignment: Qt.AlignRight
        visible: root.adapter !== null
        accessibleName: "Bluetooth"
        checked: root.adapter?.enabled ?? false
        onToggled: value => root.adapter.enabled = value
    }

    Text {
        renderType: Text.NativeRendering
        Layout.fillWidth: true
        visible: root.adapter === null || !(root.adapter?.enabled ?? false)
        text: root.adapter === null ? "No Bluetooth adapter" : "Bluetooth is off"
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textXs
        color: Tokens.dim
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.adapter !== null && (root.adapter?.enabled ?? false)
        spacing: Tokens.spacing1

        Repeater {
            model: root.devices.slice(0, 8)

            Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: Tokens.spacing8
                radius: Tokens.radiusSm
                activeFocusOnTab: true
                color: btMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                border.width: activeFocus ? 1 : 0
                border.color: Accent.accent
                Accessible.role: Accessible.Button
                Accessible.name: (modelData.connected ? "Disconnect " : "Connect ") + modelData.name

                function activate() {
                    modelData.connected ? modelData.disconnect() : modelData.connect();
                }

                Keys.onReturnPressed: activate()
                Keys.onSpacePressed: activate()

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.spacing2
                    anchors.rightMargin: Tokens.spacing2
                    spacing: Tokens.spacing2

                    Glyph {
                        text: "\u{f00af}"
                        size: Tokens.iconSm
                        color: modelData.connected ? Accent.accent : Tokens.muted
                    }

                    Text {
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                        text: modelData.name
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textXs
                        color: modelData.connected ? Tokens.text : Tokens.muted
                        elide: Text.ElideRight
                    }

                    // Most devices never report battery; showing 0% for those
                    // would read as a flat headset rather than as no data.
                    Text {
                        renderType: Text.NativeRendering
                        visible: (modelData.battery ?? 0) > 0
                        text: Math.round((modelData.battery ?? 0) * 100) + "%"
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textXs
                        color: Tokens.dim
                    }

                    Glyph {
                        visible: modelData.connected
                        text: "\u{f012c}"
                        size: Tokens.iconSm
                        color: Accent.accent
                    }
                }

                HvPointerArea {
                    id: btMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.activate()
                }
            }
        }
    }

    HvButton {
        Layout.alignment: Qt.AlignRight
        visible: root.adapter !== null && (root.adapter?.enabled ?? false)
        text: "Pair device"
        accessibleName: "Pair Bluetooth device"
        onClicked: SystemActions.openBluetoothControl()
    }
}
