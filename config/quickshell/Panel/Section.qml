// Shared chrome for a quick-settings section: icon, title, optional trailing
// control, then arbitrary content.
//
// Extracted because the three sections were near-identical in the AGS panel and
// drifted anyway — one used a 9px header button radius, another 10px. Chrome
// that exists once cannot disagree with itself.
import QtQuick
import QtQuick.Layouts
import ".."

Surface {
    id: root

    property string glyph
    property string title
    // The panel titles itself when it is showing a single section, and the
    // section header then repeats that title verbatim.
    property bool showHeader: true
    default property alias content: body.data
    // Sections sit on the panel, so they are one elevation tier above it.
    elevation: 1
    radius: Tokens.radiusMd

    // A headerless section is not a visual section: nothing names it, the panel
    // header already does, and its chrome then reads as a stray box drawn
    // around content that carries its own border. Drop fill, hairline and
    // shadow together — Surface only tiers them as a set.
    color: showHeader ? Qt.rgba(tint.r, tint.g, tint.b, _alpha) : "transparent"
    border.width: showHeader ? 1 : 0
    layer.enabled: showHeader

    readonly property int _pad: showHeader ? Tokens.spacing3 : 0

    implicitHeight: layout.implicitHeight + _pad * 2

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: root._pad
        spacing: Tokens.spacing2

        RowLayout {
            Layout.fillWidth: true
            visible: root.showHeader
            spacing: Tokens.spacing2

            Glyph {
                text: root.glyph
                size: Tokens.iconSm
                color: Tokens.muted
            }

            Text {
                renderType: Text.NativeRendering
                Layout.fillWidth: true
                text: root.title
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.textMd
                font.weight: Tokens.weightSemibold
                color: Tokens.text
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: Tokens.spacing1
        }
    }
}
