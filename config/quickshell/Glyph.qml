// A Nerd Font glyph.
//
// Icon sizes come from $icon-*, never from $text-*: a 16px icon and 16px text
// are different optical systems, and coupling them means fixing one breaks the
// other. That separation is the whole reason the two ramps exist.
import QtQuick

Text {
    property int size: Tokens.iconSm

    font.family: Tokens.fontUiIcons
    font.pixelSize: size
    color: Tokens.muted
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.NativeRendering
}
