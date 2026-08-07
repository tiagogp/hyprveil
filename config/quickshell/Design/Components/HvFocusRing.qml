import QtQuick
import "../.."

Rectangle {
    required property Item target
    anchors.fill: target
    anchors.margins: -Tokens.spacingHair
    radius: Math.max(("radius" in target) ? target.radius : Tokens.radiusSm,
        Tokens.radiusXs) + Tokens.spacingHair
    color: "transparent"
    border.width: target.activeFocus ? 2 : 0
    border.color: Accent.accent
    visible: target.activeFocus
    z: 100
    Accessible.ignored: true
}
