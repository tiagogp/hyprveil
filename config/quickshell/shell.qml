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

ShellRoot {
    // One bar and one dock per monitor. Variants re-instantiates its delegate
    // for each entry, so hotplugging a display is handled by the model changing
    // rather than by any code of ours.
    Variants {
        model: Quickshell.screens
        delegate: Bar { required property var modelData; screen: modelData }
    }

    Variants {
        model: Quickshell.screens
        delegate: Dock { required property var modelData; screen: modelData }
    }

    // Popups are deliberately NOT per-monitor. The design stacks them top-right
    // on the focused output; drawing the same toast on every screen is noise,
    // and AGS had the multi-monitor path written but never instantiated it.
    Popups { id: notifs }

    // The panel reads the popup scope's server rather than owning one, so the
    // history it lists and the toasts that appeared are the same objects.
    QuickSettings { notifications: notifs; wallpapers: wallpapers }

    // The wallpaper picker. wallpaper.sh owns the state and the Hyprpaper IPC;
    // this only renders `list` and calls `apply`.
    Wallpapers { id: wallpapers }

    // Holds the session lock. See Lock/Lock.qml and hypr/scripts/lock.sh — a
    // failure here is a lockout, so the script never trusts this unconditionally.
    Lock {}

    // Bluetooth connect/disconnect and low-battery notifications. Sends through
    // notify-send so they land in the same history and honour the same DND as
    // everything else.
    BluetoothWatch {}
}
