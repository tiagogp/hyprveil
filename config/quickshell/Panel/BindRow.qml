// One row of the cheatsheet: what it does, and what to press.
//
// The action is on the left and fills, the keys sit right and size to their
// content. The reverse — keys left, action right — leaves the action column
// starting at a different x on every row, because a combo is one cap wide or
// four, and the eye scans the action text far more than the keys.
import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    id: root

    property var keys: []
    property string action: ""

    spacing: Tokens.spacing2

    // A cheatsheet row reads as two separate text runs on screen — the action
    // and the key caps — but a screen reader should hear one sentence, so the
    // row names itself "<action>, <keys joined>" and the caps below are left
    // silent rather than spelled out one Rectangle at a time.
    Accessible.role: Accessible.StaticText
    Accessible.name: root.action + (root.keys.length > 0 ? ", " + root.keys.join(" ") : "")

    Text {
        renderType: Text.NativeRendering
        Layout.fillWidth: true
        text: root.action
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textXs
        color: Tokens.muted
        // Elided, not wrapped: an exec row carries a whole shell pipeline, and
        // one bind wrapping to three lines breaks the scan down the column.
        elide: Text.ElideRight
    }

    Row {
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        spacing: Tokens.spacing1

        Repeater {
            model: root.keys

            Rectangle {
                required property string modelData

                implicitWidth: cap.implicitWidth + Tokens.spacing1h * 2
                implicitHeight: cap.implicitHeight + Tokens.spacing1 * 2
                radius: Tokens.radiusXs
                color: Qt.rgba(1, 1, 1, 0.07)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)

                Text {
                    id: cap
                    renderType: Text.NativeRendering
                    anchors.centerIn: parent
                    text: modelData
                    font.family: Tokens.fontMono
                    font.pixelSize: Tokens.text2xs
                    color: Tokens.text
                }
            }
        }
    }
}
