import QtQuick
import QtQuick.Controls.Basic

// Small muted session dropdown (Hyprland, plus whatever else is installed).
// Unlike hyprlock's Lock screen, the greeter needs this since no session is
// pre-selected yet.
ComboBox {
    id: root
    required property var colors
    property var geistRegular

    model: sessionModel
    textRole: "name"
    currentIndex: sessionModel.lastIndex

    implicitWidth: 160
    implicitHeight: 30

    background: Rectangle {
        color: "transparent"
        border.width: 1
        border.color: colors.borderHair
        radius: 15
    }

    contentItem: Text {
        text: root.displayText
        color: colors.textMuted
        font.family: geistRegular ? geistRegular.name : "sans-serif"
        font.pixelSize: 12.5
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        leftPadding: 10
        rightPadding: 10
    }

    popup: Popup {
        y: root.height + 6
        width: root.width
        implicitHeight: contentItem.implicitHeight
        padding: 4

        background: Rectangle {
            color: colors.bg
            border.width: 1
            border.color: colors.borderHair
            radius: 10
        }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
        }
    }

    delegate: ItemDelegate {
        width: root.width
        contentItem: Text {
            text: model.name
            color: colors.textPrimary
            font.family: geistRegular ? geistRegular.name : "sans-serif"
            font.pixelSize: 12.5
            leftPadding: 10
        }
        highlighted: root.highlightedIndex === index
        background: Rectangle {
            color: highlighted ? colors.accentWashSoft : "transparent"
            radius: 8
        }
    }
}
