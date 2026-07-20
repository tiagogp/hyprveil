// A clickable glyph in the bar.
//
// Waybar needed one module per click target, which is why the media player was
// four separate modules polling playerctl four times over. Here a click target
// is a MouseArea, so a control with three actions is one item.
import QtQuick
import ".."

Item {
    id: root

    property string glyph
    property string tooltip
    property color glyphColor: Tokens.muted
    // Power and destructive controls tint accent on hover; ordinary status
    // glyphs just brighten, so hover does not read as a warning everywhere.
    property bool accentOnHover: false

    signal clicked()
    signal rightClicked()
    signal middleClicked()

    implicitWidth: Tokens.iconLg
    implicitHeight: Tokens.iconLg

    Glyph {
        id: label
        anchors.centerIn: parent
        text: root.glyph
        size: Tokens.iconSm
        color: mouse.containsMouse
            ? (root.accentOnHover ? Accent.accent : Tokens.text)
            : root.glyphColor

        // No hover scale here, unlike the dock: bar glyphs sit in a dense row at
        // icon size, and growing one of them nudges the optical rhythm of the
        // whole row for a control that is already answering with a colour
        // change. The press dip is the exception — it is the only feedback that
        // a click on a bare glyph registered at all.
        scale: mouse.pressed ? 0.88 : 1.0

        Behavior on color {
            ColorAnimation {
                duration: Tokens.dur1
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeStandard
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.dur1
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeOut
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function (event) {
            if (event.button === Qt.RightButton) root.rightClicked();
            else if (event.button === Qt.MiddleButton) root.middleClicked();
            else root.clicked();
        }
    }

    // `tooltip` is carried but not yet drawn. QtQuick.Controls' ToolTip creates
    // an ordinary window, which a layer-shell surface cannot parent — it needs
    // Quickshell's PopupWindow instead. The property stays so call sites do not
    // have to be revisited when that lands.
}
