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

RowLayout {
    spacing: Tokens.spacing1h

    Repeater {
        model: 5

        Rectangle {
            id: pill
            required property int index
            readonly property int wsId: index + 1
            readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
            readonly property bool active: Hyprland.focusedWorkspace?.id === wsId
            // Hyprland reports windows per workspace; an empty persistent
            // workspace stays visible but reads as unoccupied.
            readonly property bool occupied: (ws?.lastIpcObject?.windows ?? 0) > 0

            implicitWidth: Tokens.spacing5
            implicitHeight: Tokens.spacing5
            radius: Tokens.radiusXs
            color: active ? Accent.accentSoft : "transparent"
            border.width: active ? 1 : 0
            border.color: Accent.accent

            Text {
                anchors.centerIn: parent
                text: pill.wsId
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.text2xs
                font.weight: pill.active ? Tokens.weightBold : Tokens.weightSemibold
                color: pill.active ? Accent.accent
                     : pill.occupied ? Tokens.muted
                     : Tokens.dim
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + pill.wsId)
            }

            Behavior on color {
                ColorAnimation {
                    duration: Tokens.dur1
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.easeStandard
                }
            }
        }
    }
}
