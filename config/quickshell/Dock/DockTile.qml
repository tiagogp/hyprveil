// One dock tile.
//
// The Waybar version could not draw an icon and a label in the same button, so
// six apps got hardcoded `background-image` rules pointing at absolute Papirus
// paths and every other app fell back to a glyph from a 29-entry lookup table.
// IconImage resolves the desktop entry's icon through the icon theme, so both
// the table and the special cases are gone.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import ".."

Item {
    id: tile

    property var entry: null
    // The window class and the pinned desktop id, kept even when `entry` is set:
    // they are the fallback icon names when the desktop entry cannot be found.
    property string appId: ""
    property string desktopId: ""
    property string glyph: ""
    property string tooltip: ""
    property bool running: false
    property bool active: false

    signal activated()
    signal closed()
    signal unpinned()

    implicitWidth: 44
    implicitHeight: 44

    // The dock lift. Scale rather than position so the tile grows about its own
    // centre and its neighbours do not reflow — a dock that shuffles sideways on
    // hover makes the next tile a moving target. Press dips below rest so a
    // click reads as landing, and because the dip is shorter than the lift it
    // still feels like a button rather than a bounce.
    //
    // 1.08 is deliberately restrained: the tile is 44px, so this is a ~3.5px
    // gain, enough to register in peripheral vision without the icon softening.
    scale: mouse.pressed ? 0.96 : mouse.containsMouse ? 1.08 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: Tokens.dur2h
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.easeOut
        }
    }

    // The desktop entry is the good source for an icon — it is the only one that
    // knows the app's declared Icon= — but DesktopEntries comes up empty on some
    // Quickshell builds (0.3.0 on Fedora COPR indexes nothing), and a dock of
    // blank squares is a worse failure than a slightly wrong icon. So the entry
    // is the first candidate, not the only one: the desktop id and the window
    // class are both real icon names in every theme this ships against.
    //
    // iconPath's second argument is a NAME to fall back to in the string
    // overload, but `true` selects the check overload, which returns "" when the
    // theme has no such icon. That is what makes this a chain rather than a
    // single guess — without it every candidate "resolves" to an image:// URL
    // that renders as nothing.
    readonly property string iconSource: {
        const candidates = [
            entry?.icon ?? "",
            desktopId.replace(/\.desktop$/, ""),
            appId,
            // Last resort, and only for app tiles: a tile carrying its own glyph
            // (the launcher) is meant to draw that glyph, not a generic binary.
            glyph === "" ? "application-x-executable" : ""
        ];
        for (const name of candidates) {
            if (name === "") continue;
            const path = Quickshell.iconPath(name, true);
            if (path !== "") return path;
        }
        return "";
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radiusSm
        color: tile.active ? Accent.accentSoft
             : mouse.containsMouse ? "#23262e"
             : "#1c1f26"
        border.width: tile.active ? 1 : 0
        border.color: Accent.accent

        Behavior on color {
            ColorAnimation {
                duration: Tokens.dur1
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeStandard
            }
        }

        IconImage {
            id: icon
            anchors.centerIn: parent
            implicitSize: Tokens.iconLg
            // Keyed on the resolved path, not on `entry`: an app whose desktop
            // entry is missing still has an icon, and hiding it because the
            // entry is null is what emptied the dock.
            visible: tile.iconSource !== ""
            // DesktopEntry.icon is a theme icon NAME, not a path. Handing it to
            // IconImage directly makes it look for a file of that name and warn
            // once per repaint; iconSource has already been through the theme.
            source: tile.iconSource
            // Every tile draws at full strength. Dimming off-workspace apps
            // made them read as disabled — a greyed icon says "you cannot
            // click this", when in fact clicking is how you get to that
            // window. The running dot below carries the open/closed state on
            // its own; the icon does not need to repeat it.
        }

        Glyph {
            anchors.centerIn: parent
            visible: tile.iconSource === ""
            text: tile.glyph
            size: Tokens.iconMd
            color: tile.active ? Accent.accent : Tokens.muted
        }
    }

    // The running indicator sits outside the tile, so it is not clipped by the
    // corner radius and does not shift the icon off centre.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: Tokens.spacingHair
        width: Tokens.spacing1
        height: Tokens.spacing1
        radius: Tokens.radiusPill
        color: Accent.accent
        // Shown for anything running, including on another workspace — the dot
        // means "open", and a click gets you there.
        //
        // Driven by opacity rather than `visible` so appearing and disappearing
        // are animatable at all: `visible` is a bool and cannot be tweened, and
        // this dot toggles on every launch, close, and workspace switch. It
        // scales up from nothing as it fades so a newly opened app announces
        // itself, which a pure fade at 4px is too small to do.
        opacity: tile.running && !tile.active ? 1.0 : 0.0
        visible: opacity > 0
        scale: opacity > 0 ? 1.0 : 0.4

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.dur2
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeStandard
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.dur2h
                easing.type: Easing.Bezier
                easing.bezierCurve: Tokens.easeOut
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: function (event) {
            if (event.button === Qt.MiddleButton) tile.closed();
            else if (event.button === Qt.RightButton) tile.unpinned();
            else tile.activated();
        }
    }

    // See BarButton: tooltips wait on a PopupWindow-based implementation.
}
