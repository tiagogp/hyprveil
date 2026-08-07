import QtQuick
import "../.."
import "../../Services"

Surface {
    property bool presented: true
    elevation: 2
    radius: Tokens.radiusLg
    opacity: presented ? 1 : 0
    scale: presented ? 1 : 0.96
    Accessible.role: Accessible.Pane

    Behavior on opacity { NumberAnimation { duration: Motion.duration(Tokens.dur2h); easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Motion.duration(Tokens.durModal); easing.type: Easing.OutCubic } }
}
