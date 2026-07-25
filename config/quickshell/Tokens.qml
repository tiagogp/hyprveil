// GENERATED from Tokens.qml.in by hypr/scripts/theme.sh — do not edit.
// Edit hypr/tokens.conf, then run `theme.sh render`. See docs/CONFIGURATION.md.
//
// This is the whole reason the shell is QML: every value below is a real
// property, so `radius: Tokens.radiusMd` is a live binding. There is no unit
// problem (tokens.conf stores 14, QML wants 14), and no stylesheet to discard
// when one declaration is wrong — the GTK failure modes the CSS consumers have
// to defend against simply do not exist here.
pragma Singleton

// QtQuick, not just Quickshell: the `color` properties in the neutrals block are
// a QtQuick type, and a Singleton without it fails to load.
import QtQuick
import Quickshell

Singleton {
    // ---------------------------------------------------------------------
    // Radius — a 4px ramp whose step equals spacing1, so nesting is concentric
    // by construction: panel > card > control > chip.
    // ---------------------------------------------------------------------
    readonly property int radiusXs:   6
    readonly property int radiusSm:   10
    readonly property int radiusMd:   14
    readonly property int radiusLg:   18
    readonly property int radiusPill: 999

    // ---------------------------------------------------------------------
    // Spacing — 4px grid with three half-steps. Half-steps are legal for
    // padding INSIDE a control; margins, gaps, and grid spacing use full steps.
    // ---------------------------------------------------------------------
    readonly property int spacingHair: 2
    readonly property int spacing1:    4
    readonly property int spacing1h:   6
    readonly property int spacing2:    8
    readonly property int spacing2h:   10
    readonly property int spacing3:    12
    readonly property int spacing4:    16
    readonly property int spacing5:    20
    readonly property int spacing6:    24
    readonly property int spacing8:    32

    // ---------------------------------------------------------------------
    // Type
    // ---------------------------------------------------------------------
    readonly property string fontUi:      "Geist"
    readonly property string fontUiIcons: "Symbols Nerd Font"
    readonly property string fontMono:    "Fira Code"

    readonly property int text2xs: 11
    readonly property int textXs:  12
    readonly property int textSm:  13
    readonly property int textMd:  14
    readonly property int textLg:  16
    readonly property int textXl:  20

    // One-offs, named so they are not mistaken for scale steps.
    readonly property real textMono:   12.5
    readonly property int  textAvatar: 26
    readonly property int  textClock:  104

    readonly property int weightRegular:  400
    readonly property int weightMedium:   500
    readonly property int weightSemibold: 600
    readonly property int weightBold:     700

    // Icon glyph sizes are not type: a 16px icon and 16px text are different
    // optical systems, and coupling them means fixing one breaks the other.
    readonly property int iconSm:   15
    readonly property int iconMd:   18
    readonly property int iconLg:   24
    readonly property int iconXl:   32
    readonly property int iconHit:  40
    readonly property int iconRing: 56

    // ---------------------------------------------------------------------
    // Elevation — surface alpha, hairline opacity, and shadow move TOGETHER.
    // Tiering alpha alone is why nothing read as layered before.
    //
    // Tier 0 sits at 0.88 rather than a glassier 0.82 because 0.82 puts muted
    // text at 4.05:1 over a bright wallpaper, under the 4.5:1 floor.
    // ---------------------------------------------------------------------
    readonly property real elev0Alpha:  0.88
    readonly property real elev0Border: 0.10

    readonly property real elev1Alpha:       0.92
    readonly property real elev1Border:      0.08
    readonly property int  elev1ShadowY:     1
    readonly property int  elev1ShadowBlur:  2
    readonly property real elev1ShadowAlpha: 0.35

    readonly property real elev2Alpha:       0.96
    readonly property real elev2Border:      0.14
    readonly property int  elev2ShadowY:     4
    readonly property int  elev2ShadowBlur:  12
    readonly property real elev2ShadowAlpha: 0.45

    readonly property real elev3Alpha:       0.96
    readonly property real elev3Border:      0.16
    readonly property int  elev3ShadowY:     8
    readonly property int  elev3ShadowBlur:  24
    readonly property real elev3ShadowAlpha: 0.55

    readonly property int blurSize:   8
    readonly property int blurPasses: 2

    // The bar and dock only, and the WORST CASE for them: what a pure white
    // strip under the bar needs to hold muted text at 4.5:1. Accent.chromeAlpha
    // is the measured value for the current wallpaper and is usually glassier;
    // this is the fallback when nothing has been measured. See tokens.conf.
    readonly property real chromeAlpha: 0.87

    // ---------------------------------------------------------------------
    // Motion — milliseconds. Hyprland's deciseconds do not cross into QML.
    //
    // The easing curves are exposed as control-point lists because that is what
    // `easing.bezierCurve` takes; the CSS consumers get the same four numbers
    // wrapped in cubic-bezier() by the same renderer.
    // ---------------------------------------------------------------------
    // dur2h has no decisecond equivalent and so is QML/CSS only, like dur2. It
    // exists because the 150 -> 300 gap is exactly where panel and tile motion
    // wants to sit: 150 is too abrupt to read as travel, 300 too slow to repeat.
    readonly property int dur1:  100
    readonly property int dur2:  150
    readonly property int dur2h: 200
    readonly property int durModal: 280
    readonly property int dur3:  300
    readonly property int dur4:  400

    // Qt's easing.bezierCurve is not the four-number CSS/Hyprland cubic: it
    // wants control points in groups of six — two handles plus the segment's
    // endpoint — and the final point must be (1,1). tokens.conf stores the bare
    // four Hyprland's `bezier =` needs, so the closing `, 1, 1` is appended here
    // to make each a valid single-segment curve. Drop it and Qt rejects the
    // list silently and animates linearly instead — no warning, no easing.
    readonly property var easeOut:      [0.16, 1, 0.3, 1, 1, 1]
    readonly property var easeModal:    [0.28, 0.72, 0, 1, 1, 1]
    readonly property var easeStandard: [0.25, 0.1, 0.25, 1, 1, 1]
    readonly property var easeReduced:  [0.2, 0, 0, 1, 1, 1]
    // Overshoot entrance for modal dialogs; see $ease-bloom-points. The first
    // handle's y > 1 carries a transform past its target and back.
    readonly property var easeBloom:    [0.34, 1.45, 0.6, 1, 1, 1]

    // ---------------------------------------------------------------------
    // Neutrals — fixed by design; only the accent moves. Mirrors
    // hypr/colors.conf, which QML cannot read.
    // ---------------------------------------------------------------------
    readonly property color base:     "#0f1115"
    readonly property color surface:  "#16181d"
    readonly property color elevated: "#1c1f26"
    readonly property color text:     "#f5f5f7"
    readonly property color muted:    "#9a9ca5"
    readonly property color dim:      "#6b6e78"
    readonly property color hairline: "#2a2d35"
    readonly property color warning:  "#e1a346"
    readonly property color error:    "#e5484d"
    readonly property color success:  "#4cae80"

    // Chrome-specific tints/states, mirroring neutrals.conf's $chrome-tint /
    // $chrome-tint-media / $state-hover-surface. Previously hardcoded per
    // literal in Bar.qml/Dock.qml/Media.qml/DockTile.qml.
    readonly property color chromeTint:       "#14161a"
    readonly property color chromeTintMedia:  "#151817"
    readonly property color stateHoverSurface: "#23262e"
}
