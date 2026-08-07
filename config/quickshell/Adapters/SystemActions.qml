pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property bool available: true
    property string state: "idle"
    property bool busy: false
    property string error: ""
    property double lastUpdated: 0

    function refresh(): void { lastUpdated = Date.now(); }
    function run(command: var, nextState: string): void {
        if (busy) return;
        state = nextState;
        error = "";
        lastUpdated = Date.now();
        Quickshell.execDetached(command);
    }
    function lock(): void { run([Quickshell.env("HOME") + "/.config/hypr/scripts/lock.sh"], "locking"); }
    function suspend(): void { run(["systemctl", "suspend"], "suspending"); }
    function reboot(): void { run(["systemctl", "reboot"], "restarting"); }
    function powerOff(): void { run(["systemctl", "poweroff"], "powering-off"); }
    function logout(): void { HyprlandAdapter.exitSession(); state = "logging-out"; lastUpdated = Date.now(); }
    function openUri(uri: string): void { if (uri) run(["xdg-open", uri], "opening"); }
    function openAudioControl(): void { run(["pavucontrol"], "opening-audio"); }
    function openBluetoothControl(): void { run(["blueman-manager"], "opening-bluetooth"); }
    function openNetworkEditor(): void { run(["nm-connection-editor"], "opening-network"); }
    function launchDesktop(desktopId: string): void { if (desktopId) run(["gtk-launch", desktopId], "launching"); }
    function openTrash(): void { run(["nautilus", "--new-window", "trash:///"], "opening-trash"); }
    function copyText(text: string): void { run(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "hyprveil-copy", text], "copying"); }
    function connectWifi(name: string): void { if (name) run(["sh", "-c", "nmcli device wifi connect \"$1\"", "hyprveil-wifi", name], "connecting-wifi"); }
    function openSoundSettings(): void { run(["env", "XDG_CURRENT_DESKTOP=GNOME", "gnome-control-center", "sound"], "opening-audio"); }
    function clipboardCopy(entry: string): void { run(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "hyprveil-clipboard-copy", entry], "copying"); }
    function clipboardDelete(entry: string): void { run(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "hyprveil-clipboard-delete", entry], "deleting"); }
    function clipboardClear(cacheDir: string): void {
        run(["cliphist", "wipe"], "clearing");
        Quickshell.execDetached(["sh", "-c", "rm -rf \"$1\"", "hyprveil-clipboard-cache", cacheDir]);
    }
}
