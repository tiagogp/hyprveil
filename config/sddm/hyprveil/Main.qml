import QtQuick
import QtQuick.Window
import "Components" as Components

// hyprveil SDDM greeter — same clock/avatar/pill-input idiom as
// hypr/hyprlock.conf, plus a Suspend/Restart/Shutdown row styled after the
// design mockup's Power screen (wlogout implements the post-login version).
Item {
    id: root
    width: Screen.width
    height: Screen.height

    Components.Palette { id: colors }

    FontLoader { id: geistLightLoader; source: "Fonts/Geist-Light.ttf" }
    FontLoader { id: geistRegularLoader; source: "Fonts/Geist-Regular.ttf" }
    readonly property var geistLight: geistLightLoader.status === FontLoader.Ready ? geistLightLoader : null
    readonly property var geistRegular: geistRegularLoader.status === FontLoader.Ready ? geistRegularLoader : null

    Rectangle {
        anchors.fill: parent
        color: colors.bg
    }

    // Only the primary screen gets the interactive greeter — secondary
    // monitors just show the flat background, same single-surface approach
    // hyprlock.conf takes for a one-monitor lock UI.
    Item {
        anchors.fill: parent
        visible: primaryScreen

        Column {
            anchors.centerIn: parent
            spacing: 44

            Components.Clock {
                anchors.horizontalCenter: parent.horizontalCenter
                colors: colors
                geistLight: root.geistLight
                geistRegular: root.geistRegular
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 22

                Components.UserAvatar {
                    id: userAvatar
                    anchors.horizontalCenter: parent.horizontalCenter
                    colors: colors
                    geistRegular: root.geistRegular
                }

                Components.PasswordField {
                    id: passwordField
                    anchors.horizontalCenter: parent.horizontalCenter
                    colors: colors
                    geistRegular: root.geistRegular
                    userName: userAvatar.currentName
                    sessionIndex: sessionPicker.currentIndex
                }

                Components.SessionPicker {
                    id: sessionPicker
                    anchors.horizontalCenter: parent.horizontalCenter
                    colors: colors
                    geistRegular: root.geistRegular
                }
            }
        }

        Components.PowerRow {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            colors: colors
            geistRegular: root.geistRegular
        }
    }

    Component.onCompleted: {
        if (primaryScreen) passwordField.focusInput()
    }
}
