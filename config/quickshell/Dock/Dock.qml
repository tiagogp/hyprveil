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

    // Preferences > dock autohide, with a per-monitor override — see
    // Settings.dockAutohideFor. Read from the window's own connector name so
    // one instance of this file, Variant-ed per screen by shell.qml, can
    // answer differently on a laptop panel than on an external display.
    readonly property string monitorName: dock.screen?.name ?? ""
    readonly property bool autohide: Settings.dockAutohideFor(dock.monitorName)
    readonly property bool revealed: !dock.autohide || dockHover.hovered

    anchors { bottom: true; left: true; right: true }
    // Rev 02 floats the dock further off the bottom edge (frame 2a/2c) —
    // spacing3 is the closest step on the closed scale to the mockup's 14px.
    margins.bottom: Tokens.spacing3
    implicitHeight: 44 + Tokens.spacing5
    color: "transparent"
    // The dock is visually a centered pill, but the layer window spans the
    // bottom edge so wlroots can reserve a real workarea strip. Be explicit
    // about that strip: some Hyprland/Quickshell combinations do not infer an
    // exclusive zone for a bottom-anchored layer from ExclusionMode alone. Keep
    // the reserved strip to the dock window's height; the bottom margin is
    // visual breathing room, not extra tiled-window padding.
    exclusionMode: dock.autohide ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: dock.autohide ? 0 : dock.implicitHeight
    WlrLayershell.namespace: "hyprveil-dock"
    WlrLayershell.layer: WlrLayer.Top

    mask: Region { item: dockSurface }

    // Pinned apps first in their saved order, then anything else running on ANY
    // workspace. A pinned app that is also running appears once, as the pinned
    // entry — matching the old jq program's unique_by on the class.
    readonly property var items: {
        const out = [];
        const seen = new Set();

        for (const pin of Pins.pins) {
            const id = pin.app_id.toLowerCase();
            const desktopId = pin.desktop_id || Compositor.desktopIdForApp(id);
            seen.add(id);
            // Every window of the class, not just one — see Compositor.
            // toplevelsForClass and WindowPicker.qml for what a second window
            // does to the tile.
            const wins = Compositor.toplevelsForClass(pin.app_id);
            out.push({
                appId: pin.app_id,
                desktopId: desktopId,
                toplevel: wins[0] ?? null,
                toplevels: wins,
                pinned: true
            });
        }

        for (const t of Hyprland.toplevels.values) {
            const cls = (t.lastIpcObject?.class ?? "").toLowerCase();
            if (!cls || seen.has(cls)) continue;
            // Not filtered to the focused workspace: a window open on another
            // one is still worth a tile, because clicking it is how you get
            // there.
            seen.add(cls);
            const wins = Compositor.toplevelsForClass(cls);
            out.push({
                appId: cls,
                desktopId: Compositor.desktopIdForApp(cls),
                toplevel: wins[0] ?? null,
                toplevels: wins,
                pinned: false
            });
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

    // Everything visible lives in this one Item so autohide can translate it
    // as a unit and track hover across it as a unit — see the autohide
    // properties above. HoverHandler here (not a background MouseArea) is
    // the same pattern Media.qml/MediaCard.qml use: it reports hover across
    // the whole Item's bounds regardless of which tile's own MouseArea is
    // topmost at the cursor, which a plain background MouseArea would not.
    Item {
        id: dockChrome
        anchors.fill: parent

        HoverHandler { id: dockHover }

        transform: Translate {
            // Slides the dock below the visible edge rather than fading it —
            // a faded-but-still-hoverable dock would dead-zone clicks in the
            // space it used to occupy.
            y: dock.revealed ? 0 : dock.implicitHeight
            Behavior on y {
                NumberAnimation {
                    duration: Motion.duration(Tokens.dur2h)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.easeStandard
                }
            }
        }

        Surface {
            id: dockSurface
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
                        readonly property string resolvedDesktopId:
                            modelData.desktopId || Compositor.desktopIdForApp(modelData.appId)

                        entry: DesktopEntries.byId(resolvedDesktopId)
                               ?? DesktopEntries.byId(modelData.appId)
                        appId: modelData.appId
                        desktopId: resolvedDesktopId
                        tooltip: entry?.name ?? modelData.appId
                        running: modelData.toplevel !== null
                        windowCount: modelData.toplevels?.length ?? 0
                        // The toplevel check is not redundant: at cold start
                        // activeToplevel is null, and comparing two optional-chained
                        // nulls yields undefined === undefined, which lit up every
                        // pinned-but-not-running tile as focused.
                        active: modelData.toplevel !== null
                                && Hyprland.activeToplevel?.address === modelData.toplevel.address

                        // A pinned app that is not running launches; a single
                        // running window focuses; two or more open the picker
                        // instead of silently picking the first one Hyprland
                        // happened to report. focuswindow follows the window to
                        // whatever workspace it is on, which is what makes an
                        // off-workspace tile a way to switch pages rather than a
                        // dead entry. Middle closes, right unpins — same verbs the
                        // Waybar dock bound, minus the three-way shell dispatch.
                        onActivated: {
                            if ((modelData.toplevels?.length ?? 0) > 1) {
                                picker.toplevels = modelData.toplevels;
                                picker.visible = !picker.visible;
                            } else if (modelData.toplevel) {
                                Compositor.dispatchTo("focuswindow", modelData.toplevel);
                            } else if (entry) {
                                entry.execute();
                            } else if (modelData.desktopId) {
                                // Same reason the tile falls back for its icon: with
                                // no entry there is nothing to execute(), and a
                                // pinned app that does nothing on click is a dead
                                // tile. gtk-launch takes the desktop id directly.
                                Quickshell.execDetached(["gtk-launch", modelData.desktopId]);
                            }
                        }

                        WindowPicker {
                            id: picker
                            target: parent
                            onPicked: toplevel => Compositor.dispatchTo("focuswindow", toplevel)
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
}
