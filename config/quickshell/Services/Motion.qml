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
import "../Utils"

Singleton {
    id: root

    property bool available: true
    readonly property string state: root.reduced ? "reduced" : "standard"
    property bool busy: false
    property string error: ""
    property double lastUpdated: 0

    // HYPRVEIL_STATE_HOME mirrors motion-profile.sh so a mocked test session and
    // the real shell read the exact same file.
    readonly property string path: Paths.stateHome + "/motion-profile"

    // The default is standard, not reduced: a missing or malformed file is the
    // first-run state, and first-run should look like the designed desktop.
    // Only the exact word "reduced" opts out.
    property bool systemReduced: false
    readonly property bool reduced:
        (Settings.animation.reducedMotion ?? false)
        || (Settings.animation.profile ?? "system") === "reduced"
        || ((Settings.animation.profile ?? "system") === "system" && systemReduced)

    // The one call site every Behavior uses. Reduced motion is not slower
    // motion — a long slow fade is worse for vestibular triggers than none —
    // so the reduced answer is zero: the property snaps to its new value with
    // no travel, and the easing curve stops mattering. Calm Mode's
    // "pausa de animação em bateria" reuses the exact same zero-duration
    // path rather than a separate slow-motion mode of its own.
    function duration(ms: int): int {
        return (root.reduced || CalmMode.pauseAnimations) ? 0 : ms;
    }

    function refresh(): void { file.reload(); }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { root.systemReduced = text().trim() === "reduced"; root.lastUpdated = Date.now(); }
        onLoadFailed: root.systemReduced = false
    }
}
