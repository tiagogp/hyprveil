// One of the three top-bar surfaces.
//
// WrapperItem owns the padding and implicit-size propagation. Keeping that
// plumbing here means every island follows the same spacing and adaptive glass
// contract without each call site rebuilding it with anchors and arithmetic.
import QtQuick
import Quickshell.Widgets
import ".."
import "../Services"

Surface {
    id: root

    default property alias content: wrapper.child
    property bool active: false
    property bool interactive: false
    property string accessibleName: ""

    signal clicked()

    implicitWidth: wrapper.implicitWidth
    implicitHeight: 44
    elevation: 0
    alphaOverride: Accent.chromeAlpha
    tint: Tokens.chromeTint
    radius: Tokens.radiusMd

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.active ? Accent.accentSoft : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Motion.duration(Tokens.dur1)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.easeStandard
            }
        }
    }

    WrapperItem {
        id: wrapper
        anchors.centerIn: parent
        leftMargin: Tokens.spacing3
        rightMargin: Tokens.spacing3
    }

    // Optional whole-island interaction is used by the clock. Keeping the hit
    // layer here makes the standard glass padding clickable too; a MouseArea in
    // the wrapped content would cover only the text's implicit rectangle.
    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        visible: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Accessible.role: interactive ? Accessible.Button : Accessible.NoRole
    Accessible.name: accessibleName
}
