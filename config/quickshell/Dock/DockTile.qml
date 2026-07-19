// One dock tile.
//
// The Waybar version could not draw an icon and a label in the same button, so
// six apps got hardcoded `background-image` rules pointing at absolute Papirus
// paths and every other app fell back to a glyph from a 29-entry lookup table.
// IconImage resolves the desktop entry's icon through the icon theme, so both
// the table and the special cases are gone.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import ".."

Item {
    id: tile

    property var entry: null
    property string glyph: ""
    property string tooltip: ""
    property bool running: false
    // Running somewhere vs. running HERE. A pinned window on another workspace
    // stays reachable but must not read as present, or every tile looks active.
    property bool onscreen: false
    property bool active: false

    signal activated()
    signal closed()
    signal unpinned()

    implicitWidth: 44
    implicitHeight: 44

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radiusSm
        color: tile.active ? Accent.accentSoft
             : mouse.containsMouse ? "#23262e"
             : "#1c1f26"
        border.width: tile.active ? 1 : 0
        border.color: Accent.accent

        Behavior on color {
            ColorAnimation {
                duration: Tokens.dur1
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeStandard
            }
        }

        IconImage {
            anchors.centerIn: parent
            implicitSize: Tokens.iconLg
            visible: tile.entry !== null
            source: tile.entry?.icon ?? ""
            // Dim a pinned app that is running on another workspace, so the
            // dock distinguishes "open elsewhere" from "open here".
            opacity: !tile.running || tile.onscreen ? 1.0 : 0.55
        }

        Glyph {
            anchors.centerIn: parent
            visible: tile.entry === null
            text: tile.glyph
            size: Tokens.iconMd
            color: tile.active ? Accent.accent : Tokens.muted
        }
    }

    // The running indicator sits outside the tile, so it is not clipped by the
    // corner radius and does not shift the icon off centre.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: Tokens.spacingHair
        width: Tokens.spacing1
        height: Tokens.spacing1
        radius: Tokens.radiusPill
        color: Accent.accent
        visible: tile.running && tile.onscreen && !tile.active
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: function (event) {
            if (event.button === Qt.MiddleButton) tile.closed();
            else if (event.button === Qt.RightButton) tile.unpinned();
            else tile.activated();
        }
    }

    // See BarButton: tooltips wait on a PopupWindow-based implementation.
}
