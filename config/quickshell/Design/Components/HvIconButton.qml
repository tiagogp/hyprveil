import QtQuick
import "../.."
import "../../Services"

HvButton {
    id: root
    property string glyph: ""
    property int iconSize: Tokens.iconMd
    property string tooltip: accessibleName
    text: glyph
    implicitWidth: Ui.iconButtonSize
    labelFontFamily: Tokens.fontUiIcons
    labelPixelSize: iconSize

    HvTooltip {
        text: root.tooltip
        shown: root.hovered && root.tooltip.length > 0
        target: root
    }
}
