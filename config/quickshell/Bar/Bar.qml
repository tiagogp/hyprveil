// The top bar.
//
// One process draws this on every monitor (see shell.qml), where Waybar needed a
// second bar definition and a separate module set.
//
// The bar's glass is MEASURED, not fixed. The mockup's 0.5 fill is illegible
// over a bright wallpaper and luxurious over a dark one, so accent.sh samples
// the strip this bar covers and solves for the glassiest alpha that still holds
// the title at 4.5:1 — Accent.chromeAlpha. Tokens.chromeAlpha (0.88) is what a
// pure white wallpaper demands and remains the fallback.
//
// This header used to claim the bar was bound by a 3.0:1 floor "because it
// carries no body text". That was wrong: WCAG's 3.0:1 is SC 1.4.11, for non-text
// UI components, and the title and clock below are text at textSm (13px), which
// SC 1.4.3 holds to 4.5:1 regardless of the surface. The bar shipped at 0.76
// with muted landing at 3.08:1 over bright wallpapers, which is what "the top
// bar is too transparent to read" meant.
//
// The accent and dim glyphs ARE non-text components and do get 3.0:1 — but via
// Accent.accentOnChrome and Accent.dimOnChrome, which lift those two colours
// against the solved fill. Alpha alone would have needed ~0.97 and made the bar
// a solid slab. See the contrast budget in docs/CONFIGURATION.md.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../Services"

PanelWindow {
    id: bar

    // The panel scopes, supplied by shell.qml. Left null-safe throughout: a bar
    // that loses its panel should drop a click, not tear down the whole shell.
    property var notifications: null
    property var quickSettings: null
    property var wallpapers: null

    // The bar's own fill, named because the notification badge has to punch a
    // ring of it back out of the glyph — a badge that borders in anything else
    // reads as a second, floating shape.
    readonly property color chromeTint: "#14161a"

    anchors { top: true; left: true; right: true }
    margins { top: Tokens.spacing2h; left: Tokens.spacing2h; right: Tokens.spacing2h }

    implicitHeight: 44
    color: "transparent"
    WlrLayershell.namespace: "hyprveil-bar"
    WlrLayershell.layer: WlrLayer.Top

    Surface {
        id: surface

        anchors.fill: parent
        elevation: 0
        alphaOverride: Accent.chromeAlpha
        tint: bar.chromeTint
        radius: Tokens.radiusMd

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacing3
            anchors.rightMargin: Tokens.spacing3
            spacing: 0

            Workspaces { id: workspaces; Layout.alignment: Qt.AlignVCenter }

            Item { Layout.fillWidth: true }

            RowLayout {
                id: rightCluster

                Layout.alignment: Qt.AlignVCenter
                spacing: Tokens.spacing4

                // `barWindow` so the hover card can place itself against the
                // bar's real edges instead of a measured offset.
                Media { screen: bar.screen; barWindow: bar }
                StatusCluster {}

                // The wallpaper picker was reachable only from inside quick
                // settings, which buried the one control that changes how the
                // whole desktop looks two clicks deep.
                BarButton {
                    glyph: "\u{f0976}"
                    tooltip: "Wallpaper"
                    glyphColor: (bar.wallpapers?.open ?? false)
                        ? Accent.accentOnChrome : Tokens.muted
                    onClicked: if (bar.wallpapers)
                        bar.wallpapers.open = !bar.wallpapers.open
                }

                // Notifications. The badge counts HISTORY, not live popups — a
                // toast that timed out unread is precisely what this button
                // exists to surface, and counting popups would show zero in the
                // one case that matters.
                BarButton {
                    id: notifButton

                    readonly property int count:
                        bar.notifications?.notifications?.values?.length ?? 0
                    readonly property bool dnd:
                        bar.notifications?.dontDisturb ?? false

                    glyph: dnd ? "\u{f009b}" : "\u{f009a}"
                    tooltip: dnd ? "Do not disturb"
                        : count > 0 ? `${count} notifications` : "Notifications"
                    glyphColor: dnd ? Accent.dimOnChrome
                        : count > 0 ? Accent.accentOnChrome : Tokens.muted
                    // Opens the panel on notifications alone. A click that is
                    // already showing notifications closes; one that lands on
                    // the full panel switches view rather than dismissing, so
                    // the bell never has to be clicked twice.
                    onClicked: {
                        if (!bar.quickSettings) return;
                        if (bar.quickSettings.open && bar.quickSettings.notificationsOnly) {
                            bar.quickSettings.open = false;
                        } else {
                            bar.quickSettings.view = "notifications";
                            bar.quickSettings.open = true;
                        }
                    }
                    // Right-click silences without opening the panel. Muting is
                    // the thing you want at the moment a toast interrupts you,
                    // and routing it through the panel costs three clicks.
                    onRightClicked: if (bar.notifications)
                        bar.notifications.dontDisturb = !bar.notifications.dontDisturb

                    // Suppressed under DND: the bell-off glyph already says the
                    // count is not being shown to you, and a live badge next to
                    // it reads as a contradiction.
                    Rectangle {
                        id: badge

                        // Off the scale on purpose, and named so it is not read
                        // as a step: text2xs (11) is the smallest UI size, and
                        // the badge is not UI text — it is a mark that has to
                        // fit inside a 10px disc.
                        readonly property int countSize: 9
                        readonly property string label: notifButton.count > 9
                            ? "9+" : String(notifButton.count)

                        visible: notifButton.count > 0 && !notifButton.dnd
                        anchors {
                            top: parent.top
                            right: parent.right
                            topMargin: -Tokens.spacingHair
                            rightMargin: -Tokens.spacingHair
                        }

                        // A 10px accent disc inside a 2px ring. The old 16px
                        // circle sat directly on the bell and merged with it at
                        // a glance; shrinking the mark and cutting the bar's own
                        // fill back out around it separates the two without
                        // adding a stroke colour that is on no surface here.
                        //
                        // Two glyphs get a pill rather than a bigger circle:
                        // growing the circle to fit "9+" would undo the shrink
                        // for the case that is already the least precise.
                        implicitHeight: Tokens.spacing3 + Tokens.spacingHair
                        implicitWidth: Math.max(
                            implicitHeight, countText.implicitWidth + Tokens.spacing1h)
                        radius: Tokens.radiusPill
                        // The chrome-lifted accent, not the raw one, even though
                        // this is a FILL rather than a glyph — it sits directly
                        // beside the bell it counts for, and two different
                        // accents touching each other reads as a bug rather than
                        // as two surfaces. The cost is that accentFg below lands
                        // near 4:1 instead of the accent's designed band; that is
                        // the same tradeoff the countSize comment already makes,
                        // and this is a mark, not text.
                        color: Accent.accentOnChrome
                        // Opaque, unlike the bar it borrows from: the ring sits
                        // over the bell glyph, and any alpha would show the
                        // strokes it exists to clear.
                        border.width: Tokens.spacingHair
                        border.color: bar.chromeTint
                        antialiasing: true

                        Text {
                            id: countText
                            renderType: Text.NativeRendering
                            anchors.centerIn: parent
                            // Capped at one digit. Past a few unread the exact
                            // number stops being the information anyway.
                            text: badge.label
                            font.family: Tokens.fontUi
                            font.pixelSize: badge.countSize
                            font.weight: Tokens.weightSemibold
                            color: Accent.accentFg
                        }
                    }
                }

                Text {
                    renderType: Text.NativeRendering
                    text: Time.clock
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.textSm
                    font.weight: Tokens.weightSemibold
                    color: Tokens.text
                }

                BarButton {
                    glyph: "\u{f0425}"
                    tooltip: "Power"
                    accentOnHover: true
                    onClicked: Quickshell.execDetached(
                        ["sh", "-c", Quickshell.env("HOME") + "/.config/wlogout/power-menu.sh"])
                }
            }
        }

        // The focused window's title, centred on the BAR rather than on the gap
        // between the two clusters — those clusters are never the same width, so
        // laying the title out between two stretch spacers parked it off-centre
        // by half their difference.
        //
        // Sitting outside the layout means it can no longer be pushed, so it
        // yields instead, in two stages. While the mirrored clearance can still
        // seat `minWidth`, the title stays locked to the bar's midpoint and
        // elides into whatever both sides can spare. Below that it gives up the
        // centring rather than the title, and falls back to the asymmetric gap
        // between the clusters — off-centre, but legible, and still never
        // overlapping either side.
        Text {
            id: title
            renderType: Text.NativeRendering

            // Roughly a dozen characters. Under this a centred title is more
            // ellipsis than name, at which point being centred is worth less
            // than being readable.
            readonly property int minWidth: 96

            // How far the title leans off true centre toward the middle of the
            // gap, as a fraction of the distance between the two. 0 is centred
            // on the bar; 1 is centred in the gap between the clusters, which
            // is what two stretch spacers give you and what this replaced.
            //
            // The clusters are wildly unequal — workspaces is a fixed 124, the
            // right cluster runs 350-480 — so the two differ by ~140px here,
            // which is why the old layout read as off-centre. Kept as a knob
            // rather than inlined because which of the two looks right is a
            // judgement about air, not a fact about geometry.
            readonly property real opticalBias: 0

            readonly property real gapLeft:
                Tokens.spacing3 * 2 + workspaces.width
            readonly property real gapRight:
                surface.width - Tokens.spacing3 * 2 - rightCluster.width
            readonly property real centre: surface.width / 2 + opticalBias
                * ((gapLeft + gapRight) / 2 - surface.width / 2)

            // Mirrored around wherever the centre landed, so the bias never
            // buys width on one side that it cannot match on the other — the
            // title stays visually centred on `centre` right up to the point it
            // gives up and falls back.
            readonly property real centred: Math.max(0, 2 * Math.min(
                centre - gapLeft, gapRight - centre))
            readonly property bool isCentred: centred >= minWidth
            readonly property real budget:
                isCentred ? centred : Math.max(0, gapRight - gapLeft)

            y: (surface.height - height) / 2
            x: isCentred ? centre - width / 2
                : gapLeft + (gapRight - gapLeft - width) / 2
            width: Math.min(implicitWidth, budget)
            horizontalAlignment: Text.AlignHCenter
            text: Compositor.activeTitle
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.textSm
            font.weight: Tokens.weightMedium
            color: Tokens.muted
            elide: Text.ElideRight
        }
    }
}
