// The dock.
//
// This is where the Waybar implementation cost the most. It was ten identical
// `custom/dock-N` modules — the only way Waybar can approximate a dynamic list —
// each running dock.sh every 3 seconds, and each invocation spawned three
// `hyprctl` calls plus a large jq program. Roughly 110 processes per poll cycle,
// forever, to draw a row of icons that changes when a window opens.
//
// Here it is a Repeater over a model. Window state arrives from Hyprland's event
// socket in-process, which also retires dock-watch.sh and its socat dependency.
// Icons come from DesktopEntries, which retires dock-icons.json, the
// has_image_icon() allowlist, and the six hardcoded Papirus paths in the CSS.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import ".."
import "../Services"

PanelWindow {
    id: dock

    // The session-wide pin picker, handed down from shell.qml. One scope for
    // every monitor's dock, for the same reason the panels are single scopes:
    // two docks disagreeing about what is staged is not a state worth having.
    property var pinPicker: null

    anchors.bottom: true
    // Rev 02 floats the dock further off the bottom edge (frame 2a/2c) —
    // spacing3 is the closest step on the closed scale to the mockup's 14px.
    margins.bottom: Tokens.spacing3
    implicitHeight: 44 + Tokens.spacing5
    implicitWidth: row.implicitWidth + Tokens.spacing6
    color: "transparent"
    // Left at the default (auto), which reserves implicitHeight plus the bottom
    // margin. Pinning it to 0 made the dock float over tiled windows: a maximised
    // window ran under it and its last rows were unreachable. The bar has always
    // reserved its strip; the dock now matches.
    WlrLayershell.namespace: "hyprveil-dock"
    WlrLayershell.layer: WlrLayer.Top

    // Pinned apps first in their saved order, then anything else running on ANY
    // workspace. A pinned app that is also running appears once, as the pinned
    // entry — matching the old jq program's unique_by on the class.
    readonly property var items: {
        const out = [];
        const seen = new Set();

        for (const pin of Pins.pins) {
            const id = pin.app_id.toLowerCase();
            seen.add(id);
            // Matched across ALL workspaces: the toplevel is what lets a click
            // focus-and-switch from anywhere.
            const win = Compositor.toplevelForClass(pin.app_id);
            out.push({ appId: pin.app_id, desktopId: pin.desktop_id, toplevel: win, pinned: true });
        }

        for (const t of Hyprland.toplevels.values) {
            const cls = (t.lastIpcObject?.class ?? "").toLowerCase();
            if (!cls || seen.has(cls)) continue;
            // Not filtered to the focused workspace: a window open on another
            // one is still worth a tile, because clicking it is how you get
            // there.
            seen.add(cls);
            out.push({ appId: cls, desktopId: null, toplevel: t, pinned: false });
        }
        return out;
    }

    // ---------------------------------------------------------------------
    // Long-press reordering.
    //
    // Only the pinned prefix of `items` participates, and it is a contiguous
    // run starting at 0, so the whole thing is index arithmetic: a tile that has
    // travelled one slot's width has moved one position. That avoids mapping
    // pointer coordinates between the tile, the row, and the window on every
    // mouse move, and it stays correct whatever the row is centred on.
    //
    // The model is deliberately NOT reordered live. `items` is a plain JS array,
    // so a Repeater rebuilds every delegate when it changes — which would
    // destroy the tile mid-drag, taking the mouse grab with it. The indicator
    // shows the destination instead, and the model updates once on release.
    // ---------------------------------------------------------------------
    property int dragFrom: -1
    property int dragTo: -1
    // Captured once when the drag starts rather than bound: the row does not
    // relayout during a drag, and itemAt() is not a notifying property, so a
    // binding on it would silently never re-evaluate anyway.
    property real pinsOriginX: 0

    readonly property int pinCount: Pins.pins.length
    readonly property real slot: 44 + row.spacing

    function beginDrag(index) {
        dock.dragFrom = index;
        dock.dragTo = index;
        dock.pinsOriginX = pinTiles.itemAt(0)?.x ?? 0;
    }

    function updateDrag(dx) {
        if (dock.dragFrom < 0)
            return;
        const moved = dock.dragFrom + Math.round(dx / dock.slot);
        dock.dragTo = Math.max(0, Math.min(dock.pinCount - 1, moved));
    }

    function commitDrag(item) {
        if (dock.dragFrom >= 0 && dock.dragTo !== dock.dragFrom)
            // dock-manager.sh takes the position 1-based, and matches the id
            // against both desktop_id and app_id — so a pin whose desktop entry
            // was never resolved still moves.
            Quickshell.execDetached([
                Quickshell.env("HOME") + "/.config/hypr/scripts/dock-manager.sh",
                "move", item.desktopId ? item.desktopId : item.appId,
                String(dock.dragTo + 1)]);
        dock.cancelDrag();
    }

    function cancelDrag() {
        dock.dragFrom = -1;
        dock.dragTo = -1;
    }

    Surface {
        anchors.centerIn: parent
        implicitWidth: row.implicitWidth + Tokens.spacing3 * 2
        implicitHeight: row.implicitHeight + Tokens.spacing2h * 2
        elevation: 2
        alphaOverride: Accent.chromeAlpha
        tint: Tokens.chromeTint
        radius: Tokens.radiusLg

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Tokens.spacing2

            // The pin settings tile. Pinning used to be reachable only through
            // Rofi, which meant the dock's own contents were the one thing on
            // the dock you could not change from the dock.
            //
            // It sits where the Rofi launcher tile used to: that tile was a
            // second way to do what tapping Super already does from anywhere, so
            // the leading slot is better spent on the one control that exists
            // nowhere but the dock.
            DockTile {
                glyph: "\u{f0493}"
                tooltip: "Configure dock pins"
                onActivated: if (dock.pinPicker) dock.pinPicker.open = true
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: Tokens.spacing6 + Tokens.spacing1
                Layout.leftMargin: Tokens.spacingHair
                Layout.rightMargin: Tokens.spacingHair
                color: Qt.rgba(1, 1, 1, Tokens.elev0Border)
            }

            Repeater {
                id: pinTiles
                model: dock.items

                DockTile {
                    required property var modelData
                    required property int index

                    entry: DesktopEntries.byId(modelData.desktopId ?? modelData.appId)
                    appId: modelData.appId
                    desktopId: modelData.desktopId ?? ""
                    tooltip: entry?.name ?? modelData.appId
                    running: modelData.toplevel !== null
                    // The toplevel check is not redundant: at cold start
                    // activeToplevel is null, and comparing two optional-chained
                    // nulls yields undefined === undefined, which lit up every
                    // pinned-but-not-running tile as focused.
                    active: modelData.toplevel !== null
                            && Hyprland.activeToplevel?.address === modelData.toplevel.address

                    // A pinned app that is not running launches; anything else
                    // focuses. focuswindow follows the window to whatever
                    // workspace it is on, which is what makes an off-workspace
                    // tile a way to switch pages rather than a dead entry.
                    // Middle closes, right unpins — same verbs the Waybar dock
                    // bound, minus the three-way shell dispatch.
                    onActivated: {
                        if (modelData.toplevel)
                            Compositor.dispatchTo("focuswindow", modelData.toplevel);
                        else if (entry)
                            entry.execute();
                        else if (modelData.desktopId)
                            // Same reason the tile falls back for its icon: with
                            // no entry there is nothing to execute(), and a
                            // pinned app that does nothing on click is a dead
                            // tile. gtk-launch takes the desktop id directly.
                            Quickshell.execDetached(["gtk-launch", modelData.desktopId]);
                    }
                    onClosed: Compositor.dispatchTo("closewindow", modelData.toplevel)
                    onUnpinned: if (modelData.pinned)
                        Quickshell.execDetached([
                            Quickshell.env("HOME") + "/.config/hypr/scripts/dock-manager.sh",
                            "remove", modelData.appId])

                    // A running window that is not pinned has no stored
                    // position, so there is nothing a drop could write.
                    draggable: modelData.pinned
                    onDragStarted: dock.beginDrag(index)
                    onDragMoved: dx => dock.updateDrag(dx)
                    onDragEnded: dock.commitDrag(modelData)
                    onDragCanceled: dock.cancelDrag()
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: Tokens.spacing6 + Tokens.spacing1
                Layout.leftMargin: Tokens.spacingHair
                Layout.rightMargin: Tokens.spacingHair
                color: Qt.rgba(1, 1, 1, Tokens.elev0Border)
            }

            // The trash tile, in the trailing slot every dock puts it in.
            //
            // Stateless on purpose: there is no full/empty variant of the glyph
            // and no dot, because knowing which one to draw means watching
            // ~/.local/share/Trash/files, and Quickshell watches files rather
            // than directories — so the only way to keep it truthful would be
            // the timer-and-subprocess loop the rest of this dock exists to
            // retire. `trash:///` is the XDG-standard URI, and nautilus is
            // launched directly rather than through xdg-open: almost nothing
            // registers x-scheme-handler/trash, and xdg-open answers an
            // unregistered scheme by handing the URI to the default browser.
            DockTile {
                glyph: "\u{f0a79}"
                tooltip: "Trash"
                onActivated: Quickshell.execDetached(
                    ["nautilus", "--new-window", "trash:///"])
            }
        }

        // The drop indicator: where the lifted tile lands if released now.
        //
        // Drawn as a gap marker between two slots rather than a highlight on the
        // target tile, because "swap with this one" and "insert before this one"
        // look identical as a highlight and only one of them is what happens.
        Rectangle {
            // Dragging right lands the tile AFTER the tile currently at dragTo,
            // dragging left lands it BEFORE — same index, opposite edge.
            readonly property int boundary:
                dock.dragTo > dock.dragFrom ? dock.dragTo + 1 : dock.dragTo

            visible: dock.dragFrom >= 0 && dock.dragTo !== dock.dragFrom
            width: 2
            height: 44
            radius: Tokens.radiusPill
            // Chrome-lifted: this 2px bar is drawn straight onto the dock, and a
            // drop marker that cannot be seen is the one thing this control has
            // to communicate.
            color: Accent.accentOnChrome
            y: row.y + (row.height - height) / 2
            x: row.x + dock.pinsOriginX + boundary * dock.slot
               - row.spacing / 2 - width / 2

            Behavior on x {
                NumberAnimation {
                    duration: Motion.duration(Tokens.dur2)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.easeOut
                }
            }
        }
    }
}
