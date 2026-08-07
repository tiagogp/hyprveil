import QtQuick
import QtQuick.Layouts
import ".."
import "../Design/Components"
import "../Services"

HvSection {
    glyph: "\u{f0599}"
    title: "Night Light"
    HvToggle {
        Layout.alignment: Qt.AlignRight
        visible: NightLight.available
        accessibleName: "Night Light"
        checked: NightLight.state === "on"
        busy: NightLight.busy
        onToggled: value => NightLight.setEnabled(value)
    }
    Text {
        Layout.fillWidth: true
        visible: !NightLight.available
        text: "hyprsunset is not installed"
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textXs
        color: Tokens.dim
    }
}
