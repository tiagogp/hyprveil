// Workspace pills, 1-5 persistent.
//
// The Waybar module polled nothing and was fine, but it also could not show
// anything but the id. This reads Hyprland's workspace list in-process, so an
// occupied-but-inactive workspace can be dimmed rather than hidden.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import ".."
import "../Design/Components"
import "../Services"

RowLayout {
    id: root
    property string mode: "dynamic"
    spacing: Tokens.spacing1h

    // Occupied workspaces plus the focused one's immediate neighbours, not a
    // fixed 1-5 — see Compositor.visibleWorkspaceIds for why. A workspace
    // above 5, or an empty one nobody switched to yet, no longer disappears
    // from the bar just because it is outside a hardcoded range. Preferences
    // can opt back into the fixed range (Settings.bar.workspacesMode).
    Repeater {
        model: root.mode === "fixed"
            ? Compositor.fixedWorkspaceIds() : Compositor.visibleWorkspaceIds()

        Rectangle {
            id: pill
            required property int modelData
            readonly property int wsId: modelData
            readonly property var ws: Compositor.workspace(wsId)
            readonly property bool active: Compositor.focusedWorkspaceId === wsId
            // Counted from the workspace's own toplevel model. lastIpcObject is
            // empty on these objects, so reading .windows off it always gave 0
            // and every workspace rendered as unoccupied.
            readonly property bool occupied: (ws?.toplevels?.values?.length ?? 0) > 0
            readonly property string iconSource:
                Compositor.iconSourceForWorkspace(wsId)
            readonly property bool showIcon: iconSource !== ""
            readonly property int iconSize: Tokens.iconSm

            implicitWidth: active ? 36 : 28
            implicitHeight: showIcon ? 34 : 28
            radius: Tokens.radiusPill
            // Three states, not two: active carries the amber wash, an
            // occupied-but-inactive workspace gets a faint white fill so it
            // reads as "something is here" without competing with the active
            // pill, and a genuinely empty one carries no fill at all.
            color: active ? Accent.accentSoft
                 : occupied ? Qt.rgba(1, 1, 1, 0.03) : "transparent"
            // Width stays 1 and the COLOUR carries the state, because
            // border.width is an int that snaps and would pop the outline in
            // while the fill and the active pill's width were still moving.
            // Rectangle draws the permanent border inside, so it costs no
            // layout when the pill expands from 28 to 36px.
            border.width: 1
            border.color: active ? Accent.accentOnChrome : "transparent"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: -Tokens.spacingHair

                IconImage {
                    visible: pill.showIcon
                    source: pill.iconSource
                    implicitSize: pill.iconSize
                    opacity: pill.active ? 1.0 : 0.34
                    Layout.alignment: Qt.AlignHCenter

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.duration(Tokens.dur1)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.easeStandard
                        }
                    }
                }

                Text {
                    renderType: Text.NativeRendering
                    Layout.alignment: Qt.AlignHCenter
                    text: pill.wsId
                    font.family: Tokens.fontUi
                    font.pixelSize: pill.showIcon ? 10 : Tokens.text2xs
                    font.weight: pill.active ? Tokens.weightBold : Tokens.weightSemibold
                    color: pill.active ? Accent.accentOnChrome
                         : pill.occupied ? Tokens.muted
                         : Accent.dimOnChrome

                    // The label crosses three colours (dim -> muted -> accent)
                    // as a workspace fills and focuses. Left unanimated it was
                    // the one part of the pill that snapped while the fill and
                    // border faded.
                    Behavior on color {
                        ColorAnimation {
                            duration: Motion.duration(Tokens.dur1)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.easeStandard
                        }
                    }
                }
            }

            HvPointerArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + pill.wsId)
            }

            Accessible.role: Accessible.Button
            Accessible.name: `Workspace ${wsId}${active ? ", active" : ""}`

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Motion.duration(Tokens.dur2h)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.easeOut
                }
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
