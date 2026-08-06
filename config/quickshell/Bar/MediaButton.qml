// Miniature transport control sized for the media chip's divider-height row —
// BarAction's own hit target (Tokens.iconHit, 40px) is too tall to sit inline
// there, so this is the small sibling: same hover/active colour rules, a
// fraction of the size.
import QtQuick
import ".."
import "../Services"

Item {
    id: root

    property string glyph: ""
    property string accessibleName: ""
    property bool active: false
    readonly property bool hovered: mouse.containsMouse

    signal clicked()

    implicitWidth: Tokens.spacing4
    implicitHeight: Tokens.spacing4
    opacity: enabled ? 1 : 0.35

    Accessible.role: Accessible.Button
    Accessible.name: accessibleName

    Glyph {
        anchors.centerIn: parent
        text: root.glyph
        size: Tokens.textSm
        color: root.hovered ? Tokens.text
            : root.active ? Accent.accentOnChrome : Tokens.muted

        Behavior on color {
            ColorAnimation {
                duration: Motion.duration(Tokens.dur1)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.easeStandard
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled) root.clicked()
    }
}
