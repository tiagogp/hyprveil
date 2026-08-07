import QtQuick
import "../.."
import "../../Services"

Rectangle {
    id: root
    property alias text: input.text
    property alias placeholderText: placeholder.text
    property string accessibleName: placeholderText
    property bool readOnly: false
    signal accepted()
    signal escaped()
    signal moveUp()
    signal moveDown()

    implicitHeight: Ui.controlHeight
    implicitWidth: 240
    radius: Tokens.radiusSm
    color: Qt.rgba(1, 1, 1, 0.06)
    border.width: input.activeFocus ? Ui.outlineWidth : (Ui.highContrast ? 1 : 0)
    border.color: Accent.accent
    Accessible.role: Accessible.EditableText
    Accessible.name: accessibleName

    function forceInputFocus(): void { input.forceActiveFocus(); }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.margins: Tokens.spacing3
        verticalAlignment: TextInput.AlignVCenter
        color: Tokens.text
        selectionColor: Accent.accentSoft
        selectedTextColor: Tokens.text
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textSm
        readOnly: root.readOnly
        clip: true
        onAccepted: root.accepted()
        Keys.onEscapePressed: event => { root.escaped(); event.accepted = true; }
        Keys.onUpPressed: event => { root.moveUp(); event.accepted = true; }
        Keys.onDownPressed: event => { root.moveDown(); event.accepted = true; }
    }
    Text {
        id: placeholder
        anchors.fill: input
        verticalAlignment: Text.AlignVCenter
        visible: input.text.length === 0 && !input.activeFocus
        color: Tokens.dim
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textSm
    }
    TapHandler { onTapped: input.forceActiveFocus() }
}
