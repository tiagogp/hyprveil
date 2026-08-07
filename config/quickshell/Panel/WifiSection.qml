// Wi-Fi networks.
//
// UNVERIFIED ON THE DEVELOPMENT MACHINE: it has no Wi-Fi adapter (ethernet
// only), so only the "no adapter" branch below has actually been exercised. The
// API shapes come from Quickshell.Networking's qmltypes, not from guesswork, but
// the populated path needs a real run on wireless hardware.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import ".."
import "../Design/Components"
import "../Services"

HvSection {
    id: root
    glyph: "\u{f05a9}"
    title: "Wi-Fi"

    readonly property var device:
        Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var networks: {
        if (!device?.networks) return [];
        // Strongest first, unnamed hidden APs dropped — the same ordering and
        // filter the AGS list used, because signal order is the only ranking a
        // person can act on.
        return device.networks.values
            .filter(n => n.name && n.name.length > 0)
            .sort((a, b) => b.signalStrength - a.signalStrength);
    }

    HvToggle {
        Layout.alignment: Qt.AlignRight
        visible: root.device !== null
        accessibleName: "Wi-Fi"
        checked: Networking.wifiEnabled
        onToggled: value => Networking.wifiEnabled = value
    }

    Text {
        renderType: Text.NativeRendering
        Layout.fillWidth: true
        visible: root.device === null || !Networking.wifiEnabled
        text: root.device === null ? "No Wi-Fi adapter" : "Wi-Fi is off"
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textXs
        color: Tokens.dim
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.maximumHeight: 220
        visible: root.device !== null && Networking.wifiEnabled
        spacing: Tokens.spacing1

        Repeater {
            model: root.networks.slice(0, 8)

            Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: Tokens.spacing8
                radius: Tokens.radiusSm
                activeFocusOnTab: true
                color: rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                border.width: activeFocus ? 1 : 0
                border.color: Accent.accent
                Accessible.role: Accessible.Button
                Accessible.name: "Connect to Wi-Fi network " + modelData.name

                function activate() {
                    if (modelData.known || modelData.security === WifiSecurityType.Open)
                        modelData.connect(null);
                    else
                        Network.connectWifi(modelData.name);
                }

                Keys.onReturnPressed: activate()
                Keys.onSpacePressed: activate()

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.spacing2
                    anchors.rightMargin: Tokens.spacing2
                    spacing: Tokens.spacing2

                    Glyph {
                        // Five buckets, matching the glyph ramp the AGS list used.
                        text: {
                            const s = modelData.signalStrength;
                            if (s >= 0.8) return "\u{f0928}";
                            if (s >= 0.6) return "\u{f0925}";
                            if (s >= 0.4) return "\u{f0922}";
                            if (s >= 0.2) return "\u{f091f}";
                            return "\u{f092f}";
                        }
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

                    Glyph {
                        visible: modelData.security !== WifiSecurityType.Open
                        text: "\u{f033e}"
                        size: Tokens.iconSm
                        color: Tokens.dim
                    }

                    Glyph {
                        visible: modelData.connected
                        text: "\u{f012c}"
                        size: Tokens.iconSm
                        color: Accent.accent
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // A known network connects in-process. An unknown secured one
                    // needs a passphrase, and rather than build a password field
                    // that has to be as careful as the system's, this hands off to
                    // nmcli — which triggers NetworkManager's own secret agent.
                    // The AGS panel shelled out for exactly this reason.
                    onClicked: parent.activate()
                }
            }
        }
    }

    Text {
        renderType: Text.NativeRendering
        Layout.fillWidth: true
        visible: root.device !== null && Networking.wifiEnabled && root.networks.length === 0
        text: "No networks found"
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textXs
        color: Tokens.dim
    }
}
