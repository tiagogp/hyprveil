import QtQuick

// Oversized thin clock + muted date line — same idiom as hypr/hyprlock.conf.
Column {
    required property var colors
    property var geistLight
    property var geistRegular

    spacing: 10
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(clockTimer.now, "hh:mm")
        font.family: geistLight ? geistLight.name : "sans-serif"
        font.weight: Font.Light
        font.pixelSize: 104
        color: colors.textPrimary
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDate(clockTimer.now, "dddd, MMMM d")
        font.family: geistRegular ? geistRegular.name : "sans-serif"
        font.pixelSize: 17
        color: colors.textMuted
    }

    QtObject {
        id: clockTimer
        property date now: new Date()
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockTimer.now = new Date()
    }
}
