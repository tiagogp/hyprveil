// Hyprveil shell — bar, dock, and notifications in one process.
//
// This replaces Waybar plus AGS. Both were fighting their toolkit rather than
// the design: Waybar cannot render a dynamic list, so the dock was ten
// hand-duplicated modules whose count WAS the pin limit, and a Waybar module has
// one click target, so the media player was four modules polling playerctl four
// times over. AGS needed a dart-sass recompile at runtime to change one color.
//
// The shell is also the notification daemon (see Notif/Popups.qml), which is why
// notification-daemon.sh treats it as a backend and why it must not be restarted
// casually — a restart discards the session's notification history.
import Quickshell
import "Bar"
import "Dock"
import "Notif"
import "Panel"
import "Lock"
import "Services"
import "Osd"

ShellRoot {
    // One bar and one dock per monitor. Variants re-instantiates its delegate
    // for each entry, so hotplugging a display is handled by the model changing
    // rather than by any code of ours.
    // The bar carries the only on-screen route to the two panels below. Both are
    // single session-wide scopes rather than one per bar, so every monitor's bar
    // toggles the same panel and their button states cannot disagree.
    Variants {
        model: Quickshell.screens
        delegate: Bar {
            required property var modelData
            screen: modelData
            notifications: notifs
            quickSettings: qsPanel
            wallpapers: wallpaperPicker
        }
    }

    // Every dock shares one pin picker, for the same reason the panels are
    // single scopes: two monitors staging different pin lists is not a state
    // worth having, and whichever one applied last would win silently.
    Variants {
        model: Quickshell.screens
        delegate: Dock {
            required property var modelData
            screen: modelData
            pinPicker: dockPins
        }
    }

    PinPicker { id: dockPins }

    // Popups are deliberately NOT per-monitor. The design stacks them top-right
    // on the focused output; drawing the same toast on every screen is noise,
    // and AGS had the multi-monitor path written but never instantiated it.
    Popups { id: notifs }

    // The panel reads the popup scope's server rather than owning one, so the
    // history it lists and the toasts that appeared are the same objects.
    //
    // The picker's id is NOT `wallpapers`: QuickSettings has a property of that
    // name, and a property shadows an id of the same name in its own binding
    // scope, so `wallpapers: wallpapers` bound the property to itself and the
    // panel's "Wallpapers…" row opened nothing.
    QuickSettings {
        id: qsPanel
        notifications: notifs
        wallpapers: wallpaperPicker
        cheatsheet: keybindSheet
    }

    // The wallpaper picker. wallpaper.sh owns the state and the Hyprpaper IPC;
    // this only renders `list` and calls `apply`.
    Wallpapers { id: wallpaperPicker }

    // The keybind cheatsheet, rendered from keybindings.conf itself. Reached
    // from the panel or by SUPER+slash, which goes through the same IPC.
    Cheatsheet { id: keybindSheet }

    // Holds the session lock. See Lock/Lock.qml and hypr/scripts/lock.sh — a
    // failure here is a lockout, so the script never trusts this unconditionally.
    //
    // Reads the same notification scope the bar and panel do, so the lock can
    // report how many arrived while away. It shows the count only — never the
    // contents.
    Lock { notifications: notifs }

    // Bluetooth connect/disconnect and low-battery notifications. Sends through
    // notify-send so they land in the same history and honour the same DND as
    // everything else.
    BluetoothWatch {}

    // Volume, microphone, and brightness feedback for hardware keys. The helper
    // script owns the system command and this scope only renders the latest
    // value, so repeated keypresses update one overlay instead of stacking.
    Osd {}
}
