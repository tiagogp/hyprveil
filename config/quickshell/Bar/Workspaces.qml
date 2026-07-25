// Workspace pills, 1-5 persistent.
//
// The Waybar module polled nothing and was fine, but it also could not show
// anything but the id. This reads Hyprland's workspace list in-process, so an
// occupied-but-inactive workspace can be dimmed rather than hidden.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import ".."
import "../Services"

RowLayout {
    spacing: Tokens.spacing1h

    Repeater {
        model: 5

        Rectangle {
            id: pill
            required property int index
            readonly property int wsId: index + 1
            readonly property var ws: Compositor.workspace(wsId)
            readonly property bool active: Compositor.focusedWorkspaceId === wsId
            // Counted from the workspace's own toplevel model. lastIpcObject is
            // empty on these objects, so reading .windows off it always gave 0
            // and every workspace rendered as unoccupied.
            readonly property bool occupied: (ws?.toplevels?.values?.length ?? 0) > 0

            implicitWidth: Tokens.spacing5
            implicitHeight: Tokens.spacing5
            radius: Tokens.radiusXs
            color: active ? Accent.accentSoft : "transparent"
            // Width stays 1 and the COLOUR carries the state, because
            // border.width is an int that snaps and would pop the outline in
            // while the fill was still fading. The pill is a fixed
            // spacing5 square and a Rectangle draws its border inside, so a
            // permanent 1px border costs no layout.
            border.width: 1
            border.color: active ? Accent.accentOnChrome : "transparent"

            Text {
                renderType: Text.NativeRendering
                anchors.centerIn: parent
                text: pill.wsId
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.text2xs
                font.weight: pill.active ? Tokens.weightBold : Tokens.weightSemibold
                color: pill.active ? Accent.accentOnChrome
                     : pill.occupied ? Tokens.muted
                     : Accent.dimOnChrome

                // The label crosses three colours (dim -> muted -> accent) as a
                // workspace fills and focuses. Left unanimated it was the one
                // part of the pill that snapped while the fill and border faded.
                Behavior on color {
                    ColorAnimation {
                        duration: Motion.duration(Tokens.dur1)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.easeStandard
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + pill.wsId)
            }

            Behavior on color {
                ColorAnimation {
                    duration: Motion.duration(Tokens.dur1)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.easeStandard
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: Motion.duration(Tokens.dur1)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.easeStandard
                }
            }
        }
    }
}
