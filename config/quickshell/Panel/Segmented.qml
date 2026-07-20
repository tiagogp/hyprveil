// A segmented control: two or more mutually exclusive choices in one pill.
//
// `options` is what the user reads, `values` is what the caller acts on, kept
// separate so a monitor named HDMI-A-1 can display as itself while "All
// monitors" maps to the empty string wallpaper.sh expects.
import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    property var options: []
    property var values: []
    property string current: ""

    signal picked(string value)

    implicitWidth: row.implicitWidth + Tokens.spacing1
    implicitHeight: row.implicitHeight + Tokens.spacing1
    radius: Tokens.radiusSm
    color: Qt.rgba(1, 1, 1, 0.06)

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacingHair

        Repeater {
            model: root.options.length

            Rectangle {
                required property int index
                readonly property string value: root.values[index] ?? ""
                readonly property bool active: root.current === value

                implicitWidth: label.implicitWidth + Tokens.spacing2h * 2
                implicitHeight: label.implicitHeight + Tokens.spacing1h * 2
                radius: Tokens.radiusXs
                color: active ? Accent.accentSoft
                     : segMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06)
                     : "transparent"

                Text {
                    id: label
                    renderType: Text.NativeRendering
                    anchors.centerIn: parent
                    text: root.options[parent.index] ?? ""
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.textXs
                    font.weight: parent.active ? Tokens.weightSemibold : Tokens.weightRegular
                    color: parent.active ? Accent.accent : Tokens.muted
                }

                MouseArea {
                    id: segMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(parent.value)
                }
            }
        }
    }
}
