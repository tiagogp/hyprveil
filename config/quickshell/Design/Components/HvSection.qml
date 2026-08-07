import QtQuick
import QtQuick.Layouts
import "../.."

Surface {
    id: root
    property string title: ""
    property string glyph: ""
    property bool showHeader: true
    default property alias content: body.data
    elevation: 1
    color: showHeader ? Qt.rgba(tint.r, tint.g, tint.b, _alpha) : "transparent"
    border.width: showHeader ? 1 : 0
    layer.enabled: showHeader
    implicitHeight: layout.implicitHeight + Tokens.spacing3 * 2
    Accessible.role: Accessible.Grouping
    Accessible.name: title

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: root.showHeader ? Tokens.spacing3 : 0
        spacing: Tokens.spacing2
        HvHeader { Layout.fillWidth: true; visible: root.showHeader; title: root.title; glyph: root.glyph; compact: true }
        ColumnLayout { id: body; Layout.fillWidth: true; spacing: Tokens.spacing1 }
    }
}
