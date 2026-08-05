// Layer-shell-safe tooltip anchored to a bar action.
//
// QtQuick.Controls.ToolTip creates a regular transient window and cannot be
// parented reliably to a layer-shell surface. PopupWindow is Quickshell's
// supported anchored primitive and can slide at monitor edges.
import QtQuick
import Quickshell
import ".."
import "../Services"

Scope {
    id: root

    property Item target: null
    property string text: ""
    property bool requested: false

    onRequestedChanged: {
        if (requested && text !== "") showDelay.restart();
        else {
            showDelay.stop();
            popup.visible = false;
        }
    }

    Timer {
        id: showDelay
        interval: Motion.duration(400)
        onTriggered: popup.visible = root.requested && root.text !== ""
    }

    TextMetrics {
        id: metrics
        text: root.text
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.text2xs
        font.weight: Tokens.weightMedium
    }

    PopupWindow {
        id: popup

        anchor.item: root.target
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.adjustment: PopupAdjustment.SlideX
        anchor.margins.bottom: Tokens.spacing2
        implicitWidth: Math.min(320, metrics.width + Tokens.spacing2 * 2)
        implicitHeight: Math.max(Tokens.spacing8,
            label.contentHeight + Tokens.spacing2 * 2)
        color: "transparent"
        grabFocus: false
        visible: false

        Surface {
            anchors.fill: parent
            elevation: 2
            radius: Tokens.radiusSm

            Text {
                id: label
                anchors.fill: parent
                anchors.margins: Tokens.spacing2
                text: root.text
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.text2xs
                font.weight: Tokens.weightMedium
                color: Tokens.text
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                renderType: Text.NativeRendering
            }
        }
    }
}
