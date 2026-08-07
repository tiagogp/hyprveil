import QtQuick
import "../.."
import "../../Services"

Rectangle {
    id: root
    property bool checked: false
    property bool busy: false
    property string accessibleName: "Toggle"
    signal toggled(bool value)

    implicitWidth: Ui.largeTargets ? 52 : 46
    implicitHeight: Ui.largeTargets ? 30 : 26
    radius: Tokens.radiusPill
    activeFocusOnTab: enabled && !busy
    opacity: enabled ? 1 : 0.42
    color: checked ? Accent.accent : Qt.rgba(1, 1, 1, 0.10)
    border.width: Ui.outlineWidth
    border.color: checked ? Accent.accent : Qt.rgba(1, 1, 1, Tokens.elev0Border)
    Accessible.role: Accessible.CheckBox
    Accessible.name: accessibleName
    Accessible.checked: checked
    Accessible.focusable: activeFocusOnTab

    function activate(): void { if (enabled && !busy) toggled(!checked); }
    Keys.onReturnPressed: activate()
    Keys.onEnterPressed: activate()
    Keys.onSpacePressed: activate()

    Behavior on color { ColorAnimation { duration: Motion.duration(Tokens.dur2) } }

    Rectangle {
        width: Tokens.spacing5
        height: Tokens.spacing5
        radius: Tokens.radiusPill
        color: root.checked ? Accent.accentFg : Tokens.muted
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3
        Behavior on x { NumberAnimation { duration: Motion.duration(Tokens.dur2); easing.type: Easing.OutCubic } }
    }

    TapHandler { enabled: root.enabled && !root.busy; onTapped: root.activate() }
    HvFocusRing { target: root }
}
