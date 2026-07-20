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
    default property alias content: body.data
    // Sections sit on the panel, so they are one elevation tier above it.
    elevation: 1
    radius: Tokens.radiusMd

    implicitHeight: layout.implicitHeight + Tokens.spacing3 * 2

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Tokens.spacing3
        spacing: Tokens.spacing2

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing2

            Glyph {
                text: root.glyph
                size: Tokens.iconSm
                color: Tokens.muted
            }

            Text {
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
