import QtQuick
import "../.."

HvButton {
    id: root
    property string glyph: ""
    property int iconSize: Tokens.iconMd
    property string tooltip: accessibleName
    text: glyph
    implicitWidth: Tokens.iconHit
    labelFontFamily: Tokens.fontUiIcons
    labelPixelSize: iconSize

    HvTooltip {
        text: root.tooltip
        shown: root.hovered && root.tooltip.length > 0
        target: root
    }
}
