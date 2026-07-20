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

    anchors.bottom: true
    margins.bottom: Tokens.spacing1h
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

    Surface {
        anchors.centerIn: parent
        implicitWidth: row.implicitWidth + Tokens.spacing3 * 2
        implicitHeight: row.implicitHeight + Tokens.spacing2h * 2
        elevation: 2
        alphaOverride: Tokens.chromeAlpha
        tint: "#14161a"
        radius: Tokens.radiusLg

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Tokens.spacing2

            DockTile {
                glyph: "\u{f035c}"
                tooltip: "Applications"
                onActivated: Quickshell.execDetached(
                    ["sh", "-c", "pkill rofi || rofi -show drun"])
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: Tokens.spacing6 + Tokens.spacing1
                Layout.leftMargin: Tokens.spacingHair
                Layout.rightMargin: Tokens.spacingHair
                color: Qt.rgba(1, 1, 1, Tokens.elev0Border)
            }

            Repeater {
                model: dock.items

                DockTile {
                    required property var modelData

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
                }
            }
        }
    }
}
