import QtQuick

// Mirrors hypr/colors.conf + hyprlock.conf. SDDM can't read Hyprland
// variables (runs as the `sddm` system user, no access to ~/.config) —
// hardcoded here, same convention as hyprlock.conf/wlogout/gtk/qt.
// Keep in sync manually when hypr/colors.conf changes.
QtObject {
    readonly property color bg: "#0d0e11"
    readonly property color textPrimary: "#F5F5F7"
    readonly property color textMuted: "#9A9CA5"
    readonly property color textSubtle: "#6b6e78"
    readonly property color accent: "#E14658"
    readonly property color accentHover: "#E86A79"
    readonly property color accentWash: "#26E14658"   // rgba(225,70,88,0.15) avatar fill
    readonly property color accentWashSoft: "#1FE14658" // rgba(225,70,88,0.12) power-button fill
    readonly property color borderHair: "#2A2D35"
    readonly property color warning: "#E1A346"
    readonly property color error: "#E5484D"
    readonly property color success: "#4CAE80"
    readonly property color inputBg: "#0FFFFFFF"       // rgba(255,255,255,0.06)
    readonly property color inputBorder: "#1FFFFFFF"   // rgba(255,255,255,0.12)
    readonly property color inputFocus: "#3DFFFFFF"    // rgba(255,255,255,0.24) focused pill border

    // Popup/menu fill. Opaque rather than a translucent wash of `bg`, because
    // it floats over the backdrop image and has to stay readable on a bright
    // wallpaper — the one surface here that cannot be glass.
    readonly property color surface: "#15171b"

    // Scrim over the backdrop image. hyprlock bakes its dimming into the
    // blur (brightness 0.45); the greeter renders a real image, so the
    // equivalent dim is a wash on top. Kept in step with sddm-backdrop.sh.
    readonly property color scrim: "#A60d0e11"         // rgba(13,14,17,0.65)
}
