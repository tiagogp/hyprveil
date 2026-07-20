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
    exclusiveZone: 0
    WlrLayershell.namespace: "hyprveil-dock"
    WlrLayershell.layer: WlrLayer.Top

    // Pinned apps first in their saved order, then anything else running on the
    // current workspace. A pinned app that is also running appears once, as the
    // pinned entry — matching the old jq program's unique_by on the class.
    readonly property var items: {
        const out = [];
        const seen = new Set();

        for (const pin of Pins.pins) {
            const id = pin.app_id.toLowerCase();
            seen.add(id);
            // Matched across ALL workspaces: the toplevel is what lets a click
            // focus-and-switch from anywhere, while `onscreen` below decides
            // whether the tile reads as lit or dim.
            const win = Compositor.toplevelForClass(pin.app_id);
            out.push({ appId: pin.app_id, desktopId: pin.desktop_id, toplevel: win, pinned: true });
        }

        for (const t of Hyprland.toplevels.values) {
            const cls = (t.lastIpcObject?.class ?? "").toLowerCase();
            if (!cls || seen.has(cls)) continue;
            if (t.workspace?.id !== Compositor.focusedWorkspaceId) continue;
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
                    tooltip: entry?.name ?? modelData.appId
                    running: modelData.toplevel !== null
                    onscreen: modelData.toplevel?.workspace?.id === Compositor.focusedWorkspaceId
                    active: Hyprland.activeToplevel?.address === modelData.toplevel?.address

                    // A pinned app that is not running launches; anything else
                    // focuses. Middle closes, right unpins — same verbs the
                    // Waybar dock bound, minus the three-way shell dispatch.
                    onActivated: {
                        if (modelData.toplevel)
                            Hyprland.dispatch("focuswindow address:" + modelData.toplevel.address);
                        else if (entry)
                            entry.execute();
                    }
                    onClosed: if (modelData.toplevel)
                        Hyprland.dispatch("closewindow address:" + modelData.toplevel.address)
                    onUnpinned: if (modelData.pinned)
                        Quickshell.execDetached([
                            Quickshell.env("HOME") + "/.config/hypr/scripts/dock-manager.sh",
                            "remove", modelData.appId])
                }
            }
        }
    }
}
