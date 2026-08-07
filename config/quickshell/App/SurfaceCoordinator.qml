// Session-wide ownership of interactive surfaces.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../Services"

Singleton {
    id: root

    property string activeSurface: ""
    property var targetScreen: null
    property var originItem: null
    property var originRect: ({ x: 0, y: 0, width: 0, height: 0 })
    property var history: []
    property var registry: ({})
    property bool changing: false

    function registerSurface(name: string, controller: var, nature: string): void {
        const next = Object.assign({}, registry);
        next[name] = { controller, nature };
        registry = next;
    }

    function unregisterSurface(name: string): void {
        const next = Object.assign({}, registry);
        delete next[name];
        registry = next;
        if (activeSurface === name) close();
    }

    function resolveScreen(requested: var): var {
        if (requested && typeof requested !== "string") return requested;
        let connector = typeof requested === "string" ? requested : "";
        if (!connector || connector === "focused")
            connector = Settings.surfaces?.popupMonitor ?? "focused";
        if (connector === "focused") connector = Hyprland.focusedMonitor?.name ?? "";
        for (const candidate of Quickshell.screens) {
            if ((candidate.name ?? "") === connector) return candidate;
        }
        return Quickshell.screens[0] ?? null;
    }

    function rememberOrigin(item: var): void {
        originItem = item ?? null;
        if (!item) {
            originRect = { x: 0, y: 0, width: 0, height: 0 };
            return;
        }
        originRect = { x: item.x ?? 0, y: item.y ?? 0,
            width: item.width ?? 0, height: item.height ?? 0 };
    }

    function setControllerOpen(name: string, value: bool): void {
        const entry = registry[name];
        if (!entry?.controller) return;
        if (entry.controller.targetScreen !== undefined)
            entry.controller.targetScreen = targetScreen;
        entry.controller.open = value;
    }

    function open(name: string, screen: var, origin: var): string {
        if (!registry[name]) return "unknown surface: " + name;
        const previous = activeSurface;
        changing = true;
        if (previous && previous !== name) setControllerOpen(previous, false);
        if (previous && previous !== name)
            history = history.concat([{ surface: previous }]);
        targetScreen = resolveScreen(screen);
        rememberOrigin(origin);
        activeSurface = name;
        setControllerOpen(name, true);
        changing = false;
        return name;
    }

    function toggle(name: string, screen: var, origin: var): string {
        if (activeSurface === name && registry[name]?.controller?.open) {
            close();
            return "closed";
        }
        return open(name, screen, origin);
    }

    function close(name: string): string {
        if (name && activeSurface !== name) return activeSurface || "closed";
        const previous = activeSurface;
        const restore = originItem;
        changing = true;
        if (previous) setControllerOpen(previous, false);
        activeSurface = "";
        targetScreen = null;
        originItem = null;
        originRect = { x: 0, y: 0, width: 0, height: 0 };
        history = [];
        changing = false;
        if (restore?.forceActiveFocus) Qt.callLater(() => restore.forceActiveFocus());
        return "closed";
    }

    function pushPage(page: string): void {
        if (!activeSurface) return;
        history = history.concat([{ surface: activeSurface, page }]);
    }

    function back(): string {
        const entry = registry[activeSurface];
        if (!entry) return close();
        if (history.length > 0 && history[history.length - 1].surface === activeSurface) {
            const last = history[history.length - 1];
            history = history.slice(0, -1);
            if (entry.controller.page !== undefined) entry.controller.page = last.page;
            return activeSurface;
        }
        if (entry.controller.back) {
            entry.controller.back();
            return entry.controller.open ? activeSurface : "closed";
        }
        return close();
    }

    // Adopts state changes from legacy per-feature IPC handlers and local close
    // buttons. This keeps them mutually exclusive during the migration.
    function reportState(name: string, isOpen: bool): void {
        if (changing) return;
        if (isOpen) {
            if (activeSurface && activeSurface !== name) {
                changing = true;
                setControllerOpen(activeSurface, false);
                changing = false;
            }
            activeSurface = name;
            targetScreen = resolveScreen(null);
            if (registry[name]?.controller?.targetScreen !== undefined)
                registry[name].controller.targetScreen = targetScreen;
        } else if (activeSurface === name) {
            activeSurface = "";
            targetScreen = null;
            history = [];
        }
    }

    IpcHandler {
        target: "surface"
        function open(name: string): string { return root.open(name, null, null); }
        function toggle(name: string): string { return root.toggle(name, null, null); }
        function close(): string { return root.close(); }
        function back(): string { return root.back(); }
        function active(): string { return root.activeSurface || "closed"; }
    }
}
