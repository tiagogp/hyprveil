import QtQuick
import QtQuick.Layouts
import "../.."

ColumnLayout {
    id: root
    property string glyph: ""
    property string title: "Nothing here"
    property string detail: ""
    property string actionText: ""
    signal action()
    spacing: Tokens.spacing2
    Accessible.role: Accessible.StaticText
    Accessible.name: title + (detail.length ? ". " + detail : "")

    Glyph { Layout.alignment: Qt.AlignHCenter; visible: root.glyph.length > 0; text: root.glyph; size: Tokens.iconXl; color: Tokens.dim }
    Text { Layout.fillWidth: true; text: root.title; horizontalAlignment: Text.AlignHCenter; color: Tokens.text; font.family: Tokens.fontUi; font.pixelSize: Tokens.textMd; font.weight: Tokens.weightSemibold }
    Text { Layout.fillWidth: true; visible: root.detail.length > 0; text: root.detail; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; color: Tokens.muted; font.family: Tokens.fontUi; font.pixelSize: Tokens.textSm }
    HvButton { Layout.alignment: Qt.AlignHCenter; visible: root.actionText.length > 0; text: root.actionText; onClicked: root.action() }
}
