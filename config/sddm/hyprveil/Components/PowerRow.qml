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
            id: cell
            spacing: 10
            visible: modelData.enabled
            width: visible ? implicitWidth : 0

            property bool hovering: false

            Rectangle {
                id: btn
                anchors.horizontalCenter: parent.horizontalCenter
                width: 56
                height: 56
                radius: 28
                activeFocusOnTab: true
                // Hover lifts the neutral buttons to the accent too, so all
                // three read as one row of controls rather than "two inert
                // outlines and a live one".
                color: modelData.danger || cell.hovering || activeFocus ? colors.accentWashSoft : "transparent"
                border.width: activeFocus ? 2 : 1.5
                border.color: modelData.danger || cell.hovering || activeFocus ? colors.accent : colors.borderHair
                scale: cell.hovering || activeFocus ? 1.06 : 1.0
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label

                Keys.onReturnPressed: modelData.action()
                Keys.onSpacePressed: modelData.action()

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Image {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: Qt.resolvedUrl(root.iconDir + modelData.icon)
                    fillMode: Image.PreserveAspectFit
                    // wlogout ships these white; dimming the idle state keeps
                    // the row quiet until it is pointed at.
                    opacity: modelData.danger || cell.hovering ? 1.0 : 0.72
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: cell.hovering = true
                    onExited: cell.hovering = false
                    onClicked: modelData.action()
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.label
                font.family: geistRegular ? geistRegular.name : "sans-serif"
                font.pixelSize: 13
                color: modelData.danger || cell.hovering ? colors.accent : colors.textMuted
                Behavior on color { ColorAnimation { duration: 140 } }
            }
        }
    }
}
