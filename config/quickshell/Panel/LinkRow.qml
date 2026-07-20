// A full-width row in the panel that opens something else.
//
// Distinct from Button.qml, which is a footer control sized to its label and
// answers a question the surface is already asking. This one spans the panel
// and hands off to another surface — the panel closes behind it.
import QtQuick
import ".."

Rectangle {
    id: root

    property string text: ""

    signal clicked()

    implicitHeight: Tokens.spacing8
    radius: Tokens.radiusSm
    color: mouse.containsMouse ? Accent.accentSoft : Qt.rgba(1, 1, 1, 0.06)

    Text {
        renderType: Text.NativeRendering
        anchors.centerIn: parent
        text: root.text
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textXs
        color: mouse.containsMouse ? Accent.accent : Tokens.muted
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
