// One system-tray icon.
//
// The three-button contract mirrors what every StatusNotifierItem host offers:
// left activates (or opens the menu when the item is menu-only), middle fires
// the secondary action, right opens the context menu, and the wheel scrolls —
// which is how tray-based volume and brightness applets expect to be driven.
//
// The icon is imagery, not a Nerd Font glyph, so hover feedback is opacity
// rather than the colour lift a BarAction uses: a third-party icon has no
// token colour to shift to.
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../Services"
import ".."
import "../Design/Components"

Item {
    id: root

    property var item: null
    // The item may live directly in the bar or inside the collapsed tray
    // PopupWindow. Menus must anchor to whichever window actually hosts it.
    property var hostWindow: null
    property bool compact: false

    implicitWidth: compact ? 28 : Tokens.iconHit
    implicitHeight: Tokens.iconHit
    Accessible.role: Accessible.Button
    Accessible.name: root.item?.tooltipTitle || root.item?.title || "Tray item"

    function openMenu(): void {
        if (!(root.item?.hasMenu ?? false) || !root.hostWindow) return;
        // Scene coordinates equal the layer surface's own coordinates, so this
        // maps the icon's bottom edge straight into the window rect the anchor
        // wants — no hand-measured offset that drifts as the bar's contents
        // come and go.
        const p = root.mapToItem(null, 0, root.height);
        menuAnchor.anchor.rect = Qt.rect(p.x, p.y, root.width, 1);
        menuAnchor.open();
    }

    IconImage {
        id: icon
        anchors.centerIn: parent
        source: root.item?.icon ?? ""
        implicitSize: Tokens.iconSm
        opacity: mouse.containsMouse ? 1 : 0.82

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.duration(Tokens.dur1)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.easeStandard
            }
        }
    }

    HvPointerArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: function (event) {
            if (event.button === Qt.RightButton) {
                root.openMenu();
            } else if (event.button === Qt.MiddleButton) {
                root.item?.secondaryActivate();
            } else if (root.item?.onlyMenu ?? false) {
                // Nothing to activate — the whole item IS its menu.
                root.openMenu();
            } else {
                root.item?.activate();
            }
        }

        onWheel: function (wheel) {
            if (wheel.angleDelta.y !== 0) root.item?.scroll(wheel.angleDelta.y, false);
            if (wheel.angleDelta.x !== 0) root.item?.scroll(wheel.angleDelta.x, true);
        }
    }

    QsMenuAnchor {
        id: menuAnchor
        menu: root.item?.menu ?? null
        anchor.window: root.hostWindow
    }

    BarTooltip {
        target: root
        text: {
            const title = root.item?.tooltipTitle || root.item?.title || "";
            const detail = root.item?.tooltipDescription || "";
            return detail === "" ? title : title + " — " + detail;
        }
        requested: mouse.containsMouse
    }
}
