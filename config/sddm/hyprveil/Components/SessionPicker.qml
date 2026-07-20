import QtQuick
import QtQuick.Controls.Basic

// Session dropdown (Hyprland, plus whatever else is installed). Unlike
// hyprlock's Lock screen, the greeter needs this since no session is
// pre-selected yet.
//
// Width is driven by the widest entry in the model rather than fixed, because
// session names are not short: Fedora ships "GNOME Classic on Wayland" (23
// chars), which overflowed the old fixed 160px pill and spilled outside the
// border on both sides. Sizing to the model means the pill fits whatever is
// installed instead of whatever was installed when the theme was written.
//
// The stock ComboBox indicator is replaced for the same reason — Controls.Basic
// draws an unstyled arrow glyph, which rendered on TOP of the overflowing text.
ComboBox {
    id: root
    required property var colors
    property var geistRegular

    model: sessionModel
    textRole: "name"
    currentIndex: sessionModel.lastIndex

    readonly property int hPadding: 16
    readonly property int chevronBox: 22
    property bool hovering: false
    readonly property bool lit: hovering || popup.visible

    // Measures every entry off-screen so the pill can be sized to the widest
    // one. The visible label's implicitWidth only knows the CURRENT entry, so
    // binding to that would resize the pill each time the selection changes.
    //
    // Done with a real Repeater rather than by walking the model directly:
    // QAbstractListModel::rowCount is not Q_INVOKABLE, so a
    // `for (i < sessionModel.rowCount())` loop throws and silently leaves the
    // pill at its minimum width — which is exactly the overflow this sizing
    // exists to prevent. A Repeater goes through the role machinery instead.
    property int widestLabel: 0
    function noteWidth(w) {
        if (w > widestLabel)
            widestLabel = Math.ceil(w)
    }

    Item {
        visible: false
        Repeater {
            model: sessionModel
            delegate: Text {
                text: model.name
                font.family: geistRegular ? geistRegular.name : "sans-serif"
                font.pixelSize: 13
                // Re-measured on change as well as on creation: Geist loads
                // asynchronously, and a width measured against the fallback
                // sans-serif is the wrong width.
                onImplicitWidthChanged: root.noteWidth(implicitWidth)
                Component.onCompleted: root.noteWidth(implicitWidth)
            }
        }
    }

    // Capped so a pathologically long session name cannot stretch the pill
    // across the screen; the label elides past that point.
    implicitWidth: Math.min(360, Math.max(170, widestLabel + hPadding * 2 + chevronBox))
    implicitHeight: 34

    background: Rectangle {
        color: root.lit ? colors.inputBg : "transparent"
        border.width: 1
        border.color: root.lit ? colors.inputBorder : colors.borderHair
        radius: height / 2

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    // Hover only — the ComboBox's own click handling is left intact.
    HoverHandler {
        onHoveredChanged: root.hovering = hovered
        cursorShape: Qt.PointingHandCursor
    }

    contentItem: Text {
        id: labelText
        text: root.displayText
        color: root.lit ? colors.textPrimary : colors.textMuted
        font.family: geistRegular ? geistRegular.name : "sans-serif"
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        leftPadding: root.hPadding
        rightPadding: root.chevronBox

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // Hand-drawn so it matches the hairline weight of the borders and picks up
    // the accent on hover — the Controls.Basic default does neither.
    indicator: Canvas {
        id: chevron
        x: root.width - width - 12
        y: (root.height - height) / 2
        width: 12
        height: 12
        rotation: root.popup.visible ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        property color stroke: root.lit ? colors.accent : colors.textSubtle
        onStrokeChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = stroke
            ctx.lineWidth = 1.5
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.beginPath()
            ctx.moveTo(2.5, 4.5)
            ctx.lineTo(width / 2, 8.5)
            ctx.lineTo(width - 2.5, 4.5)
            ctx.stroke()
        }
    }

    popup: Popup {
        y: root.height + 8
        x: 0
        width: root.width
        // Capped so a machine with many desktops installed scrolls instead of
        // running off the top and bottom of the screen.
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 260)
        padding: 4

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 130; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
        }

        background: Rectangle {
            color: colors.surface
            border.width: 1
            border.color: colors.borderHair
            radius: 12
        }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }
    }

    delegate: ItemDelegate {
        id: item
        width: root.width - 8
        height: 32
        highlighted: root.highlightedIndex === index
        contentItem: Text {
            text: model.name
            color: item.highlighted ? colors.accent : colors.textPrimary
            font.family: geistRegular ? geistRegular.name : "sans-serif"
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            leftPadding: 12
            rightPadding: 12
        }
        background: Rectangle {
            color: item.highlighted ? colors.accentWashSoft : "transparent"
            radius: 8
        }
    }
}
