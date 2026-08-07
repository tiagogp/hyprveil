pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    property bool available: true
    property var state: ({ focusedMonitor: Hyprland.focusedMonitor?.name ?? "" })
    property bool busy: false
    property string error: ""
    property double lastUpdated: Date.now()

    function refresh(): void {
        Hyprland.refreshToplevels();
        lastUpdated = Date.now();
    }
    function dispatch(action: string, argument: string): void {
        Hyprland.dispatch(argument ? action + " " + argument : action);
        lastUpdated = Date.now();
    }
    function exitSession(): void { dispatch("exit", ""); }
}
