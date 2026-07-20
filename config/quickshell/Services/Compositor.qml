// Hyprland state, with the two startup quirks handled in one place.
//
// Quickshell's Hyprland collections are populated lazily and from events. A shell
// that starts and then reads them finds them EMPTY, and nothing warns — the bar
// draws no workspace pills and the dock shows no running windows, which looks
// like a layout bug rather than missing data. Two separate problems:
//
//  1. Nothing is fetched until something asks. refreshMonitors() has to run
//     FIRST and on its own tick: batching the three refreshes into one tick
//     leaves every workspace with id -1 and an empty lastIpcObject, because the
//     workspace objects are created from toplevel data before the monitor query
//     that gives them their identity has come back.
//
//  2. focusedMonitor, focusedWorkspace, and workspace.focused are only set by
//     event-socket traffic, so at startup they are null until the user changes
//     something. activeToplevel IS populated, and it carries its workspace, so
//     focus is derived from it and only falls back to the direct property.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // Prefer Hyprland's own focus once events have set it; derive it from the
    // active window until then. Both track correctly after the first change, so
    // this is a cold-start bridge rather than a permanent workaround.
    readonly property int focusedWorkspaceId:
        Hyprland.focusedWorkspace?.id
        ?? Hyprland.activeToplevel?.workspace?.id
        ?? -1

    readonly property string activeTitle: Hyprland.activeToplevel?.title ?? ""

    function workspace(id: int): var {
        return Hyprland.workspaces.values.find(w => w.id === id) ?? null;
    }

    // Windows on the focused workspace, by lowercased class.
    function classesOnFocused(): var {
        const out = new Set();
        for (const t of Hyprland.toplevels.values) {
            if (t.workspace?.id !== root.focusedWorkspaceId) continue;
            const cls = (t.lastIpcObject?.class ?? "").toLowerCase();
            if (cls) out.add(cls);
        }
        return out;
    }

    function toplevelForClass(appId: string): var {
        const id = appId.toLowerCase();
        // Matched across ALL workspaces: the toplevel is what lets a click
        // focus-and-switch from anywhere.
        return Hyprland.toplevels.values.find(
            t => (t.lastIpcObject?.class ?? "").toLowerCase() === id) ?? null;
    }

    // The collections are a snapshot: refreshing once at startup populates them,
    // but a window opened afterwards is never added. Events carry the change, so
    // the snapshot is re-taken whenever the window set can have moved.
    //
    // Coalesced through a short timer rather than refreshed per event: opening a
    // window emits openwindow, activewindow, and activewindowv2 together, and
    // three IPC round-trips per window is what the Waybar dock was doing wrong.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow":
            case "closewindow":
            case "movewindow":
            case "movewindowv2":
            case "activewindow":
            case "activewindowv2":
            case "workspace":
            case "workspacev2":
            case "focusedmon":
                resync.restart();
                break;
            }
        }
    }

    readonly property Timer resync: Timer {
        interval: 80
        onTriggered: Hyprland.refreshToplevels()
    }

    Component.onCompleted: prime.start()

    // Monitors first, alone; toplevels once that has landed. Workspaces need no
    // explicit refresh — they arrive with the monitor and toplevel data, and
    // asking for them in the same tick is what produced the id -1 state.
    property int _stage: 0
    readonly property Timer prime: Timer {
        interval: 200
        repeat: true
        onTriggered: {
            root._stage++;
            if (root._stage === 1) Hyprland.refreshMonitors();
            else if (root._stage === 3) Hyprland.refreshToplevels();
            else if (root._stage >= 4) stop();
        }
    }
}
