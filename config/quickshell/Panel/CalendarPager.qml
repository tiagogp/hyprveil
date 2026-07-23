// A month-pager chevron for the calendar header.
//
// Small enough that BarButton's icon-size hit target is too big and its
// bar-tuned hover colours are the wrong ones (those lift against the measured
// chrome fill; this sits on a panel). A local disc that echoes the panel's close
// button keeps the two feeling like one control set.
import QtQuick
import ".."

Rectangle {
    id: root

    property string glyph
    signal clicked()

    implicitWidth: Tokens.spacing6
    implicitHeight: Tokens.spacing6
    radius: Tokens.radiusPill
    color: mouse.containsMouse ? Accent.accentSoft : Qt.rgba(1, 1, 1, 0.06)

    Glyph {
        anchors.centerIn: parent
        text: root.glyph
        size: Tokens.iconSm
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
