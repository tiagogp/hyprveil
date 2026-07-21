// Whether the shell should move.
//
// motion-profile.sh already owns the standard/reduced choice and writes it to
// $XDG_STATE_HOME/hyprveil/motion-profile as one word. That file drives
// Hyprland's own animations through hypr/motion/active.conf, but Hyprland does
// not animate the Quickshell surfaces — the bar, dock, panel, OSD and lock draw
// their own transitions in QML, and those cannot see a Hyprland source line.
//
// So the same state file is the source of truth here too: this singleton
// mirrors it and hands out a duration. Watching the file means toggling the
// profile takes effect live, the same reload-by-write the accent uses — there
// is no second switch for a user to forget.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // HYPRVEIL_STATE_HOME mirrors motion-profile.sh so a mocked test session and
    // the real shell read the exact same file.
    readonly property string path:
        (Quickshell.env("HYPRVEIL_STATE_HOME")
            || (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
                + "/hyprveil")
        + "/motion-profile"

    // The default is standard, not reduced: a missing or malformed file is the
    // first-run state, and first-run should look like the designed desktop.
    // Only the exact word "reduced" opts out.
    property bool reduced: false

    // The one call site every Behavior uses. Reduced motion is not slower
    // motion — a long slow fade is worse for vestibular triggers than none —
    // so the reduced answer is zero: the property snaps to its new value with
    // no travel, and the easing curve stops mattering.
    function duration(ms: int): int {
        return root.reduced ? 0 : ms;
    }

    FileView {
        path: root.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.reduced = text().trim() === "reduced"
        onLoadFailed: root.reduced = false
    }
}
