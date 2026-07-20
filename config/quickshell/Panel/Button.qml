// A push button for panel footers: one action, one click.
//
// `primary` is the confirming action of the surface it sits on — filled with
// the accent so the eye lands on it. Everything else is the quiet variant, a
// hairline that only fills on hover, because two competing filled buttons make
// neither of them the answer.
import QtQuick
import ".."

Rectangle {
    id: root

    property string text: ""
    property bool primary: false
    // `enabled` is Item's own and is deliberately not redeclared — setting it
    // false already stops this item and its MouseArea from taking events, so
    // the only thing left to do is look disabled.

    signal clicked()

    implicitWidth: label.implicitWidth + Tokens.spacing3 * 2
    implicitHeight: label.implicitHeight + Tokens.spacing2 * 2
    radius: Tokens.radiusSm

    // Disabled is drawn, not hidden: an Apply that vanishes until something is
    // picked leaves no clue that picking is what the dialog wants.
    opacity: root.enabled ? 1.0 : 0.4

    color: root.primary
         ? (mouse.containsMouse && root.enabled ? Accent.accent : Accent.accentSoft)
         : (mouse.containsMouse && root.enabled ? Qt.rgba(1, 1, 1, 0.10)
                                                : Qt.rgba(1, 1, 1, 0.06))

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textXs
        font.weight: root.primary ? Tokens.weightSemibold : Tokens.weightMedium
        color: root.primary
             ? (mouse.containsMouse && root.enabled ? Tokens.text : Accent.accent)
             : Tokens.muted
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
