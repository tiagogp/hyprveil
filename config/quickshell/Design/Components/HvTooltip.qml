import QtQuick
import "../.."

Rectangle {
    id: root
    required property Item target
    property string text: ""
    property bool shown: false
    parent: target
    visible: shown
    x: (target.width - width) / 2
    y: target.height + Tokens.spacing1
    implicitWidth: label.implicitWidth + Tokens.spacing2 * 2
    implicitHeight: label.implicitHeight + Tokens.spacing1 * 2
    radius: Tokens.radiusXs
    color: Tokens.elevated
    border.width: 1
    border.color: Tokens.hairline
    z: 200
    Accessible.role: Accessible.ToolTip
    Accessible.name: text
    Text { id: label; anchors.centerIn: parent; text: root.text; color: Tokens.text; font.family: Tokens.fontUi; font.pixelSize: Tokens.text2xs }
}
