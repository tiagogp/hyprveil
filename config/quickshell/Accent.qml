// GENERATED from Accent.qml.in by hypr/scripts/accent.sh — do not edit.
// The accent is derived from the wallpaper; change the wallpaper, not this file.
// `accent.sh reset` restores the designed red. See docs/CONFIGURATION.md.
//
// Quickshell watches its config directory and reloads when a file changes, so
// writing this file IS the reload — there is no push step, and none of the
// dart-sass recompile the AGS shell needed.
pragma Singleton

// QtQuick, not just Quickshell: the `color` property type and Qt.rgba() are
// QtQuick, and a Singleton without it fails to load with "color is not a type".
import QtQuick
import Quickshell

Singleton {
    readonly property color accent:      "#e14658"
    readonly property color accentHover: "#e86a79"

    // The soft fill behind active chips and selected rows. Kept as one property
    // rather than an alpha applied at each call site, because the design uses a
    // single tint everywhere and four slightly different ones is exactly the
    // drift the token scale exists to prevent.
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.18)

    // Foreground for text and glyphs sitting ON the accent. Fixed, not derived:
    // the accent is clamped to a legibility band (OKLCH C 0.08-0.30, L 0.52-0.68)
    // that is guaranteed to carry this neutral.
    readonly property color accentFg: "#f5f5f7"

    // How opaque the bar and dock have to be on THIS wallpaper.
    //
    // Lives here, in the generated file, for the same reason the accent does: it
    // is measured from the image, not chosen. accent.sh samples the strip the
    // bar covers and solves for the glassiest alpha that still keeps muted text
    // at 4.5:1, so the bar turns to glass over a dark wallpaper and thickens
    // over a bright one instead of paying the bright wallpaper's price always.
    //
    // Tokens.chromeAlpha is the worst-case ceiling and stays the fallback for
    // anything that has not been measured.
    readonly property real chromeAlpha: 0.87

    // The accent and Tokens.dim, lightened until they clear 3.0:1 ON the fill
    // chromeAlpha produces. Use these — never the raw accent or Tokens.dim — for
    // anything drawn directly on the bar or the dock.
    //
    // Chrome is the one surface whose background is not a known constant: it is
    // part wallpaper, so a glyph colour that is legible on the quick-settings
    // panel can vanish on the bar. Alpha alone cannot fix it. Holding the accent
    // at 3.0:1 through opacity needs ~0.97, which is a solid slab and throws
    // away the glass on exactly the wallpapers worth seeing; lifting the two
    // dark glyph colours instead costs a shade of fidelity and keeps the
    // surface. See the contrast budget in docs/CONFIGURATION.md.
    //
    // Over a dark wallpaper these come back unchanged — the lift is zero when
    // the contrast is already free.
    readonly property color accentOnChrome: "#e14658"
    readonly property color dimOnChrome:    "#6b6e78"
}
