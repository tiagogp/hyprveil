import QtQuick
import QtQuick.Window
import "Components" as Components

// hyprveil SDDM greeter — same clock/avatar/pill-input idiom as
// hypr/hyprlock.conf, plus a Suspend/Restart/Shutdown row styled after the
// design mockup's Power screen (wlogout implements the post-login version).
Item {
    id: root
    width: parent && parent.width > 0 ? parent.width : Screen.width
    height: parent && parent.height > 0 ? parent.height : Screen.height

    // SDDM injects `primaryScreen` for the real multi-monitor greeter, but
    // older/test invocations may not. Falling back to true keeps the preview
    // and single-surface greeter from hiding the only login controls.
    readonly property bool showGreeter: typeof primaryScreen === "undefined" ? true : primaryScreen

    Components.Palette { id: colors }

    FontLoader { id: geistLightLoader; source: "Fonts/Geist-Light.ttf" }
    FontLoader { id: geistRegularLoader; source: "Fonts/Geist-Regular.ttf" }
    readonly property var geistLight: geistLightLoader.status === FontLoader.Ready ? geistLightLoader : null
    readonly property var geistRegular: geistRegularLoader.status === FontLoader.Ready ? geistRegularLoader : null

    // Always painted, and always under the image: it is what shows on a fresh
    // install (no backdrop rendered yet), on a decode failure, and in the
    // letterbox if the image's aspect ratio does not match the panel.
    Rectangle {
        anchors.fill: parent
        color: colors.bg
    }

    // Blurred wallpaper, baked by hypr/scripts/sddm-backdrop.sh into the theme
    // directory. `sddm-backdrop.sh render` refreshes it after a wallpaper
    // change; absent, this stays invisible and the flat fill above shows
    // through. See docs/CONFIGURATION.md.
    Image {
        id: backdrop
        anchors.fill: parent
        source: "backgrounds/backdrop.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        // Already blurred on disk, so it can be decoded at panel size instead
        // of at the wallpaper's native 5K.
        sourceSize.width: root.width
        sourceSize.height: root.height
        visible: status === Image.Ready
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    }

    // The dim hyprlock bakes into its blur. Only over the image — dimming the
    // flat fallback would just make it blacker.
    Rectangle {
        anchors.fill: parent
        color: colors.scrim
        visible: backdrop.status === Image.Ready
    }

    // Only the primary screen gets the interactive greeter — secondary
    // monitors just show the background, same single-surface approach
    // hyprlock.conf takes for a one-monitor lock UI.
    Item {
        id: greeter
        anchors.fill: parent
        visible: root.showGreeter

        // Settles in rather than snapping on. The greeter is the first frame
        // of a boot, where an abrupt cut reads as a flicker.
        opacity: 0
        Component.onCompleted: greeter.opacity = 1
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

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
                // Wide enough to clear PasswordField's Caps Lock warning, which
                // hangs below the pill without taking layout height (so the
                // column does not jump when it appears).
                spacing: 28

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
        if (root.showGreeter) passwordField.focusInput()
    }
}
