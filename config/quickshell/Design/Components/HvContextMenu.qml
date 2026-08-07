import QtQuick
import QtQuick.Layouts
import "../.."

Surface {
    id: root
    property bool open: false
    property var actions: []
    signal triggered(string actionId)
    visible: open
    elevation: 3
    implicitWidth: 180
    implicitHeight: menu.implicitHeight + Tokens.spacing2 * 2
    Accessible.role: Accessible.PopupMenu

    ColumnLayout {
        id: menu
        anchors.fill: parent
        anchors.margins: Tokens.spacing2
        Repeater {
            model: root.actions
            HvActionRow {
                required property var modelData
                Layout.fillWidth: true
                title: modelData.label ?? ""
                glyph: modelData.glyph ?? ""
                onClicked: { root.triggered(modelData.id); root.open = false; }
            }
        }
    }
    Keys.onEscapePressed: root.open = false
}
