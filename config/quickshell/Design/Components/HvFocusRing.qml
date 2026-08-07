import QtQuick
import "../.."
import "../../Services"

Rectangle {
    required property Item target
    anchors.fill: target
    anchors.margins: -Tokens.spacingHair
    radius: Math.max(("radius" in target) ? target.radius : Tokens.radiusSm,
        Tokens.radiusXs) + Tokens.spacingHair
    color: "transparent"
    border.width: target.activeFocus ? Math.max(2, Ui.outlineWidth) : 0
    border.color: Accent.accent
    visible: target.activeFocus
    z: 100
    Accessible.ignored: true
}
