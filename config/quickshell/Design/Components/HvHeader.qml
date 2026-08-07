import QtQuick
import QtQuick.Layouts
import "../.."
import "../../Services"

RowLayout {
    id: root
    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property bool compact: false
    property bool canGoBack: false
    property bool canClose: false
    default property alias trailing: trailingSlot.data
    signal back()
    signal close()
    implicitHeight: compact ? Ui.controlHeight : Ui.rowHeightWithSubtitle
    spacing: Tokens.spacing2
    Accessible.role: Accessible.Heading
    Accessible.name: title

    HvIconButton { visible: root.canGoBack; glyph: "‹"; accessibleName: "Back"; onClicked: root.back() }
    Glyph { visible: root.glyph.length > 0; text: root.glyph; size: Tokens.iconMd; color: Tokens.muted }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Text { text: root.title; color: Tokens.text; font.family: Tokens.fontUi; font.pixelSize: root.compact ? Tokens.textMd : Tokens.textLg; font.weight: Tokens.weightSemibold }
        Text { visible: root.subtitle.length > 0; text: root.subtitle; color: Tokens.muted; font.family: Tokens.fontUi; font.pixelSize: Tokens.text2xs }
    }
    RowLayout { id: trailingSlot; spacing: Tokens.spacing1 }
    HvIconButton { visible: root.canClose; glyph: "×"; accessibleName: "Close"; onClicked: root.close() }
}
