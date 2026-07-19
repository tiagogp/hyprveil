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
    Popups {}
}
