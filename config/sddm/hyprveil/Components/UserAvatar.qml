import QtQuick

// Accent avatar ring + username, same idiom as hyprlock.conf's "shape" +
// initial-letter labels. Bound to userModel so this still works with more
// than one local user (arrow keys cycle, mirroring the stock SDDM theme),
// but only ever shows one centered avatar — this is a single-user desktop.
Item {
    id: root
    required property var colors
    property var geistRegular
    property int currentIndex: userList.currentIndex
    readonly property string currentName: userList.currentItem ? userList.currentItem.userName
                                                                 : (userModel.lastUser || "")

    width: 140
    height: 130

    ListView {
        id: userList
        anchors.fill: parent
        model: userModel
        currentIndex: userModel.lastIndex
        interactive: false
        orientation: ListView.Horizontal
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: width

        delegate: Item {
            id: delegateRoot
            width: userList.width
            height: userList.height
            readonly property string userName: model.name

            Column {
                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 76
                    height: 76
                    radius: 38
                    color: colors.accentWash
                    border.width: 2
                    border.color: colors.accent

                    Text {
                        anchors.centerIn: parent
                        text: (model.realName || model.name || "?").substring(0, 1).toUpperCase()
                        color: colors.accent
                        font.family: geistRegular ? geistRegular.name : "sans-serif"
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: model.name
                    color: colors.textPrimary
                    font.family: geistRegular ? geistRegular.name : "sans-serif"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
            }
        }
    }
}
