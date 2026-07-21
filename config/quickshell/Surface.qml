// The glass surface every panel, card, and pill is built from.
//
// Elevation is one property rather than three, because surface alpha, hairline
// opacity, and shadow have to move TOGETHER — tiering alpha alone is why nothing
// read as layered before. Setting `elevation: 2` picks all three from the token
// scale, so a card cannot end up with a tier-1 border and a tier-3 shadow.
//
// See docs/CONFIGURATION.md for the ramp and the contrast budget behind tier 0.
import QtQuick
import QtQuick.Effects

Rectangle {
    id: root

    // 0 = flat panel fill, 1 = raised card, 2 = window/dialog, 3 = overlay.
    property int elevation: 0
    // The neutral the alpha is applied to. Panels sit on the base, cards on the
    // surface above it.
    property color tint: Tokens.surface

    // Escape hatch for surfaces whose legibility floor is not the tier's. The
    // only current user is chrome (bar, dock), which carries no body text and
    // so can sit glassier than tier 0 — see the contrast budget in
    // docs/CONFIGURATION.md. Deliberately alpha only: the border and shadow still come
    // from the tier, because the point of elevation is that a surface cannot
    // end up with a tier-1 border and a tier-3 shadow. Negative = use the tier.
    property real alphaOverride: -1

    readonly property real _alpha: alphaOverride >= 0 ? alphaOverride : [
        Tokens.elev0Alpha, Tokens.elev1Alpha, Tokens.elev2Alpha, Tokens.elev3Alpha
    ][elevation]
    readonly property real _border: [
        Tokens.elev0Border, Tokens.elev1Border, Tokens.elev2Border, Tokens.elev3Border
    ][elevation]

    color: Qt.rgba(tint.r, tint.g, tint.b, _alpha)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, _border)
    radius: Tokens.radiusMd
    antialiasing: true

    // Tier 0 is the flat fill and deliberately casts nothing: it is the panel
    // itself, and a shadow under the thing everything else sits on reads as a
    // second layer that is not there.
    layer.enabled: root.elevation > 0
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, [
            0, Tokens.elev1ShadowAlpha, Tokens.elev2ShadowAlpha, Tokens.elev3ShadowAlpha
        ][root.elevation])
        shadowVerticalOffset: [
            0, Tokens.elev1ShadowY, Tokens.elev2ShadowY, Tokens.elev3ShadowY
        ][root.elevation]
        shadowBlur: [
            0, Tokens.elev1ShadowBlur, Tokens.elev2ShadowBlur, Tokens.elev3ShadowBlur
        ][root.elevation] / 32.0
    }
}
