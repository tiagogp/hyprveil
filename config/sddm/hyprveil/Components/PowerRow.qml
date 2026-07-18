import QtQuick

// Suspend/Restart/Shutdown — same 56px circle-button idiom as the design
// mockup's Power screen (wlogout implements the post-login version of this
// row). Reuses the icons the wlogout package already installs system-wide
// so the greeter's power row matches wlogout pixel-for-pixel instead of
// vendoring a second copy of the same icons.
Row {
    id: root
    required property var colors
    property var geistRegular
    spacing: 22

    readonly property string iconDir: "file:///usr/share/wlogout/icons/"

    Repeater {
        model: [
            { label: qsTr("Suspend"), icon: "suspend.png", danger: false, enabled: sddm.canSuspend, action: function() { sddm.suspend() } },
            { label: qsTr("Restart"), icon: "reboot.png", danger: false, enabled: sddm.canReboot, action: function() { sddm.reboot() } },
            { label: qsTr("Shutdown"), icon: "shutdown.png", danger: true, enabled: sddm.canPowerOff, action: function() { sddm.powerOff() } },
        ]

        delegate: Column {
            spacing: 10
            visible: modelData.enabled
            width: visible ? implicitWidth : 0

            Rectangle {
                id: btn
                anchors.horizontalCenter: parent.horizontalCenter
                width: 56
                height: 56
                radius: 28
                color: modelData.danger ? colors.accentWashSoft : "transparent"
                border.width: modelData.danger ? 1.5 : 1.5
                border.color: modelData.danger ? colors.accent : colors.borderHair

                Image {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: Qt.resolvedUrl(root.iconDir + modelData.icon)
                    fillMode: Image.PreserveAspectFit
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.action()
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.label
                font.family: geistRegular ? geistRegular.name : "sans-serif"
                font.pixelSize: 12.5
                color: modelData.danger ? colors.accent : colors.textMuted
            }
        }
    }
}
