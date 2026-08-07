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

    property bool available: true
    readonly property var state: ({ workspace: root.focusedWorkspaceId, appId: root.activeAppId, title: root.activeTitle })
    property bool busy: false
    property string error: ""
    property double lastUpdated: 0

    function refresh(): void {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        root.lastUpdated = Date.now();
    }

    // The current toplevel, guarded against Hyprland's stale activeToplevel
    // value after switching to or emptying a workspace.
    readonly property var activeWindow: {
        const active = Hyprland.activeToplevel;
        if (active?.workspace?.id === root.focusedWorkspaceId)
            return active;
        return Hyprland.toplevels.values.find(
            w => w.workspace?.id === root.focusedWorkspaceId) ?? null;
    }
    readonly property string activeAppId:
        (root.activeWindow?.lastIpcObject?.class ?? "").toLowerCase()
    readonly property string activeDesktopId:
        root.desktopIdForApp(root.activeAppId)
    readonly property var activeDesktopEntry:
        root.activeAppId === "" ? null
        : DesktopEntries.byId(root.activeDesktopId)
          ?? DesktopEntries.byId(root.activeAppId)
    readonly property string activeIconSource: root.activeAppId === "" ? ""
        : Icons.resolve(root.activeDesktopEntry?.icon,
                        root.activeDesktopId, root.activeAppId, true)

    // Prefer Hyprland's own focus once events have set it; derive it from the
    // active window until then. Both track correctly after the first change, so
    // this is a cold-start bridge rather than a permanent workaround.
    readonly property int focusedWorkspaceId:
        Hyprland.focusedWorkspace?.id
        ?? Hyprland.activeToplevel?.workspace?.id
        ?? -1

    // Empty workspaces get the shell's name rather than a blank gap in the bar.
    // activeToplevel is NOT cleared when the last window on a workspace closes —
    // it keeps pointing at whatever was focused last, on whichever workspace —
    // so an empty title is not a reliable "nothing open" signal on its own. The
    // window count for the focused workspace is: as long as SOMETHING is open
    // here, the bar names a window rather than falling back to the shell. The
    // stale-activeToplevel case is exactly the one that was showing "hyprveil"
    // over a workspace full of windows.
    readonly property string activeTitle: {
        const t = root.activeWindow;
        if (t && t.title !== "")
            return root.displayTitle(t.title);
        for (const w of Hyprland.toplevels.values) {
            if (w.workspace?.id !== root.focusedWorkspaceId) continue;
            if (w.title !== "") return root.displayTitle(w.title);
            // Titleless window: name it by class before giving up on it.
            const cls = w.lastIpcObject?.class ?? "";
            if (cls !== "") return cls;
        }
        return "hyprveil";
    }

    function displayTitle(title: string): string {
        const match = title.match(/^(.*) - hyprveil - Visual Studio Code$/);
        return match ? `Visual Studio Code - ${match[1]}` : title;
    }

    function workspace(id: int): var {
        return Hyprland.workspaces.values.find(w => w.id === id) ?? null;
    }

    function windowForWorkspace(id: int): var {
        if (root.activeWindow?.workspace?.id === id)
            return root.activeWindow;
        return Hyprland.toplevels.values.find(w => w.workspace?.id === id) ?? null;
    }

    function iconSourceForWindow(window: var): string {
        const appId = (window?.lastIpcObject?.class ?? "").toLowerCase();
        if (appId === "")
            return "";
        const desktopId = root.desktopIdForApp(appId);
        const entry = DesktopEntries.byId(desktopId) ?? DesktopEntries.byId(appId);
        return Icons.resolve(entry?.icon, desktopId, appId, true);
    }

    function iconSourceForWorkspace(id: int): string {
        return root.iconSourceForWindow(root.windowForWorkspace(id));
    }

    function desktopIdForApp(appId: string): string {
        if (appId === "")
            return "";
        return Pins.desktopIdForApp(appId) || appId + ".desktop";
    }

    // Every non-special workspace id that currently has a window, plus the
    // focused workspace id even when it is empty — so the bar always shows
    // where you are, not just where something is open.
    function occupiedWorkspaceIds(): var {
        const out = new Set();
        for (const w of Hyprland.workspaces.values) {
            if (w.id > 0 && (w.toplevels?.values?.length ?? 0) > 0)
                out.add(w.id);
        }
        if (root.focusedWorkspaceId > 0)
            out.add(root.focusedWorkspaceId);
        return Array.from(out);
    }

    // The bar's dynamic pill set: occupied workspaces plus the immediate
    // neighbours of the focused one, so switching one step over never
    // requires typing a number that is not currently drawn. Replaces the
    // fixed 1-5 range, which hid every workspace above 5 and every special
    // workspace outright.
    function visibleWorkspaceIds(): var {
        const ids = new Set(root.occupiedWorkspaceIds());
        const focused = root.focusedWorkspaceId > 0 ? root.focusedWorkspaceId : 1;
        if (focused > 1) ids.add(focused - 1);
        ids.add(focused + 1);
        return Array.from(ids).sort((a, b) => a - b);
    }

    // The pre-dynamic behaviour, kept as an opt-out in Preferences
    // (`Settings.bar.workspacesMode === "fixed"`) for anyone who specifically
    // wants a stable-width bar over always-relevant pills.
    function fixedWorkspaceIds(): var {
        return [1, 2, 3, 4, 5];
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

    // Every toplevel of a class, not just the first — what a dock tile needs
    // to know it represents more than one window and to offer a picker rather
    // than silently focusing whichever happened to be first in the list.
    function toplevelsForClass(appId: string): var {
        const id = appId.toLowerCase();
        return Hyprland.toplevels.values.filter(
            t => (t.lastIpcObject?.class ?? "").toLowerCase() === id);
    }

    // Dispatch a window verb at a toplevel.
    //
    // Quickshell reports HyprlandToplevel.address WITHOUT the 0x prefix
    // ("5591416d69d0"), but Hyprland's dispatchers only match "address:0x...";
    // handed the bare form they answer "No such window found" and do nothing.
    // Nothing surfaces that — dispatch has no error path here — so the failure
    // looked like a dead tile: clicking a running app, on this workspace or
    // another, simply had no effect. The old Waybar dock never hit this because
    // it read addresses straight out of `hyprctl clients -j`, which includes
    // the prefix.
    //
    // Conditional rather than unconditional concatenation so this stays correct
    // if a later Quickshell starts including the prefix itself.
    function dispatchTo(verb: string, toplevel: var) {
        const addr = toplevel?.address ?? "";
        if (addr === "") return;
        Hyprland.dispatch(
            verb + " address:" + (addr.startsWith("0x") ? addr : "0x" + addr));
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
