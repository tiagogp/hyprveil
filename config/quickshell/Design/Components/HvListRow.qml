import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../.."

Rectangle {
    id: root
    property string glyph: ""
    property string iconSource: ""
    property string title: ""
    property string subtitle: ""
    property string accessibleName: title
    property bool selected: false
    property bool hovered: hover.hovered
    default property alias trailing: trailingSlot.data

    implicitHeight: subtitle.length > 0 ? 56 : 44
    radius: Tokens.radiusSm
    color: selected || hovered || activeFocus ? Accent.accentSoft : "transparent"
    activeFocusOnTab: false
    Accessible.role: Accessible.ListItem
    Accessible.name: accessibleName

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacing3
        anchors.rightMargin: Tokens.spacing3
        spacing: Tokens.spacing2

        IconImage { visible: root.iconSource.length > 0; source: root.iconSource; implicitSize: Tokens.iconMd }
        Glyph { visible: root.iconSource.length === 0 && root.glyph.length > 0; text: root.glyph; size: Tokens.iconMd; color: root.selected ? Accent.accent : Tokens.muted }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text { Layout.fillWidth: true; text: root.title; color: Tokens.text; font.family: Tokens.fontUi; font.pixelSize: Tokens.textSm; elide: Text.ElideRight }
            Text { Layout.fillWidth: true; visible: root.subtitle.length > 0; text: root.subtitle; color: Tokens.muted; font.family: Tokens.fontUi; font.pixelSize: Tokens.text2xs; elide: Text.ElideRight }
        }
        RowLayout { id: trailingSlot; spacing: Tokens.spacing1 }
    }

    HoverHandler { id: hover }
    HvFocusRing { target: root }
}
