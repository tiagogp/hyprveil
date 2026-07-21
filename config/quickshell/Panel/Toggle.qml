// A switch.
//
// The track and knob hold a fixed ratio so it reads as a switch, which is why
// these dimensions are deliberately off the spacing grid — see the same note in
// swaync/style.css.in. Sizes that describe a control's shape are not layout.
import QtQuick
import ".."

Rectangle {
    id: root

    property bool checked: false
    property string accessibleName: "Toggle"
    signal toggled(bool value)

    implicitWidth: 46
    implicitHeight: 26
    radius: Tokens.radiusPill
    activeFocusOnTab: true
    color: checked ? Accent.accent : Qt.rgba(1, 1, 1, 0.1)
    border.width: activeFocus ? 2 : 1
    border.color: activeFocus || checked ? Accent.accent : Qt.rgba(1, 1, 1, Tokens.elev0Border)
    Accessible.role: Accessible.CheckBox
    Accessible.name: accessibleName

    Keys.onReturnPressed: root.toggled(!root.checked)
    Keys.onSpacePressed: root.toggled(!root.checked)

    Behavior on color {
        ColorAnimation {
            duration: Tokens.dur2
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeStandard
        }
    }

    Rectangle {
        width: Tokens.spacing5
        height: Tokens.spacing5
        radius: Tokens.radiusPill
        color: root.checked ? Accent.accentFg : Tokens.muted
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 2 : 2

        Behavior on x {
            NumberAnimation {
                duration: Tokens.dur2
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeStandard
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
