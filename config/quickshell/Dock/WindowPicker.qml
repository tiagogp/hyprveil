// The multi-window popover for a grouped dock tile.
//
// The dock tile used to resolve a running class to its FIRST toplevel only —
// fine for one window, silently wrong for two. This lists every toplevel of
// the class the tile represents so a second/third window is reachable at all,
// closing the "múltiplas janelas" half of the roadmap's dock gap.
//
// MVP scope: dismissed by Escape, by picking a row, or by clicking the tile
// again — not yet by an outside click, which would need the same focus-grab
// machinery as Quick Settings. Small enough a miss that it did not block this
// pass; worth revisiting if it turns out to surprise people in practice.
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../Design/Components"
import "../Services"

PopupWindow {
    id: popup

    property Item target: null
    property var toplevels: []
    signal picked(var toplevel)

    anchor.item: target
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.adjustment: PopupAdjustment.SlideX
    anchor.margins.top: -Tokens.spacing2
    implicitWidth: Math.max(160, Math.min(280, list.implicitWidth + Tokens.spacing3 * 2))
    implicitHeight: list.implicitHeight + Tokens.spacing2 * 2
    color: "transparent"
    grabFocus: true
    visible: false

    Surface {
        anchors.fill: parent
        elevation: 2
        radius: Tokens.radiusSm

        focus: true
        Keys.onEscapePressed: popup.visible = false

        ColumnLayout {
            id: list
            anchors.fill: parent
            anchors.margins: Tokens.spacing2
            spacing: Tokens.spacingHair

            Repeater {
                model: popup.toplevels

                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Tokens.spacing7
                    radius: Tokens.radiusXs
                    color: rowMouse.containsMouse ? Accent.accentSoft : "transparent"

                    Accessible.role: Accessible.ListItem
                    Accessible.name: modelData.title || "Untitled window"

                    Text {
                        renderType: Text.NativeRendering
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.spacing2
                        anchors.rightMargin: Tokens.spacing2
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.title || "Untitled window"
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textXs
                        color: Tokens.text
                        elide: Text.ElideRight
                    }

                    HvPointerArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            popup.picked(modelData);
                            popup.visible = false;
                        }
                    }
                }
            }
        }
    }
}
