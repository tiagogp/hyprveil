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
import "../Design/Components"
import "../Services"

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
    // >1 when this tile represents several open windows of the same class —
    // see Dock.qml's grouping and WindowPicker.qml for what a click on one
    // of those opens.
    property int windowCount: 0
    // Only pinned tiles opt in: a running window that is not pinned has no
    // stored position, so there is nothing for a drop to write.
    property bool draggable: false

    // Set while a long press is holding this tile. The dock reads it to place
    // the drop indicator and to know a release is a reorder, not a click.
    property bool dragging: false
    // Horizontal travel since the press, applied as a transform rather than to
    // `x`: the tile is inside a RowLayout, and moving a laid-out item's x just
    // gets overwritten on the next relayout.
    property real dragOffset: 0

    signal activated()
    signal closed()
    signal unpinned()
    signal dragStarted()
    signal dragMoved(real dx)
    // Separate from dragCanceled because only one of them may write state: a
    // release is the user choosing a slot, a cancel is the grab being taken away
    // from them, and committing a reorder nobody asked for is the worse failure.
    signal dragEnded()
    signal dragCanceled()

    implicitWidth: 44
    implicitHeight: 44

    // Above its neighbours while lifted, so it passes over them rather than
    // ducking behind the next tile as it travels.
    z: dragging ? 1 : 0

    transform: Translate { x: tile.dragOffset }

    // Only the snap back is animated in practice — during the drag the offset is
    // rewritten every mouse move, which the animation tracks closely enough to
    // read as direct manipulation while still smoothing the jitter of a hand
    // holding a button down.
    Behavior on dragOffset {
        NumberAnimation {
            duration: Motion.duration(Tokens.dur1)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.easeOut
        }
    }

    // Rev 02 drops hover/press magnification outright ("tiles never scale on
    // hover... fill + border lighten only", frame 2c) — the Rectangle below
    // already carries that via Tokens.stateHoverSurface. Scale survives for
    // exactly one case: a tile picked up for reordering has genuinely left the
    // row and is now attached to the pointer, which is a different signal than
    // hover and reads as "this is being dragged", not "this is magnified".
    scale: tile.dragging ? 1.16 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: Motion.duration(Tokens.dur2h)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.easeOut
        }
    }

    // See Services/Icons.qml for why this is a chain rather than a single
    // lookup. A tile carrying its own glyph (the launcher, the pin settings
    // button) opts out of the generic fallback: it is meant to draw that glyph,
    // not a mystery binary.
    readonly property string iconSource:
        Icons.resolve(entry?.icon, desktopId, appId, glyph === "")

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radiusSm
        color: tile.active ? Accent.accentSoft
             : mouse.containsMouse ? Tokens.stateHoverSurface
             : Qt.rgba(0, 0, 0, 0.4)
        border.width: tile.active ? 1 : 0
        border.color: Accent.accentOnChrome

        Behavior on color {
            ColorAnimation {
                duration: Motion.duration(Tokens.dur1)
                easing.type: Easing.BezierSpline
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
            color: tile.active ? Accent.accentOnChrome : Tokens.muted
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
        color: Accent.accentOnChrome
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
                duration: Motion.duration(Tokens.dur2)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.easeStandard
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Motion.duration(Tokens.dur2h)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.easeOut
            }
        }
    }

    HvPointerArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        // 800ms (the Qt default) is long enough that the press reads as the
        // click not registering. 400 is past any plausible click but still
        // arrives while the finger is deliberately resting.
        pressAndHoldInterval: 400

        // Where the press landed, so travel is measured from the grab point
        // rather than from the tile's centre — a tile grabbed by its edge should
        // not jump to centre itself under the cursor.
        property real pressX: 0
        // A completed drag swallows the release. Qt already suppresses `clicked`
        // after a long press, but only for the press that triggered it; this is
        // belt and braces for the case where a drag ends some other way, and it
        // is cleared on every new press so it can never eat a later click.
        property bool dragged: false

        onPressed: function (event) {
            pressX = event.x;
            dragged = false;
        }

        onPressAndHold: function (event) {
            if (!tile.draggable || event.button !== Qt.LeftButton)
                return;
            tile.dragOffset = 0;
            tile.dragging = true;
            tile.dragStarted();
        }

        // hoverEnabled makes this fire on plain mouse-over too, so the drag
        // guard is load-bearing rather than defensive.
        onPositionChanged: function (event) {
            if (!tile.dragging)
                return;
            tile.dragOffset = event.x - pressX;
            tile.dragMoved(tile.dragOffset);
        }

        onReleased: {
            if (!tile.dragging)
                return;
            dragged = true;
            tile.dragging = false;
            // Back to the row immediately. The dock commits the new order to
            // dock-pins.json, and the reloaded model is what actually moves the
            // tile; snapping first means the two never disagree on screen.
            tile.dragOffset = 0;
            tile.dragEnded();
        }

        // A press that is cancelled — the compositor taking the grab, the dock
        // being torn down mid-drag — must not leave a tile stranded off its slot.
        onCanceled: {
            if (!tile.dragging)
                return;
            tile.dragging = false;
            tile.dragOffset = 0;
            tile.dragCanceled();
        }

        onClicked: function (event) {
            if (dragged)
                return;
            if (event.button === Qt.MiddleButton) tile.closed();
            else if (event.button === Qt.RightButton) tile.unpinned();
            else tile.activated();
        }
    }

    // The window-count badge. A second dot rather than a number-in-a-circle:
    // the dot below already carries "running", so this only needs to say
    // "more than one" — the exact count is one hover away in the picker.
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -Tokens.spacingHair
        anchors.topMargin: -Tokens.spacingHair
        width: Tokens.spacing3
        height: Tokens.spacing3
        radius: Tokens.radiusPill
        visible: tile.windowCount > 1
        color: Tokens.elevated
        border.width: 1
        border.color: Accent.accentOnChrome

        Text {
            renderType: Text.NativeRendering
            anchors.centerIn: parent
            text: tile.windowCount > 9 ? "9+" : String(tile.windowCount)
            font.family: Tokens.fontUi
            font.pixelSize: 8
            font.weight: Tokens.weightBold
            color: Accent.accentOnChrome
        }
    }

    // The dock keeps its label property independent from the bar's anchored
    // tooltip component; dock labels will use the same PopupWindow pattern when
    // they are surfaced.
}
