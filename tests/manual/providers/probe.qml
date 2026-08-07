// Probe for Launcher/Providers.qml — see tests/p18-launcher-providers-smoke.sh,
// which runs this headlessly (Quickshell tolerates no live Wayland
// connection for pure QML/JS evaluation — see p13-qml-load-smoke.sh) and
// reads the file it writes to. Unlike the other tests/manual/ probes, this
// one IS wired into the automated gate, because Providers.qml is exactly
// the kind of code most likely to hide an off-by-one or an operator-
// precedence bug — a hand-rolled arithmetic parser — and grepping its
// source cannot exercise that the way actually calling it can.
//
// Results are written to $HYPRVEIL_PROBE_OUT (set by the driver script)
// rather than printed: Quickshell does not surface console.log on stdout in
// this mode, and Qt.quit() has no receiver here (Quickshell owns its own
// event loop), so the driver just runs this under `timeout` and reads the
// file afterwards instead of waiting for the process to exit on its own.
//
// Services here is a SYMLINK to the real directory, so this can never drift
// into probing a stale copy; Launcher is likewise a symlink, and only
// Providers.qml within it is ever instantiated.
import QtQuick
import Quickshell
import Quickshell.Io
import "Launcher"
import "Services"

ShellRoot {
    Providers { id: providers }

    readonly property string outPath: Quickshell.env("HYPRVEIL_PROBE_OUT")

    function report(key, value) {
        // Positional args ($1/$2), not string interpolation into `-c` —
        // JSON.stringify's output can contain quotes the shell would
        // otherwise need escaping for.
        Quickshell.execDetached(["sh", "-c",
            'printf "%s:%s\\n" "$1" "$2" >> "$3"',
            "_", key, value, outPath]);
    }

    // Both the provider registry (Providers.qml's own FileView) and Settings
    // (a shelled-out `settings-store.sh get`) finish loading asynchronously,
    // some time after Component.onCompleted — which is exactly the ordering
    // a synchronous-looking `calculatorResult()` call has to be safe against
    // in the real launcher too, not just here. This gives both a beat to
    // land before the first assertion instead of racing them.
    Timer {
        id: startTimer
        interval: 500
        running: true
        onTriggered: {
            report("CALC_ADD", JSON.stringify(providers.calculatorResult("2 + 2")?.label ?? null));
            report("CALC_PRECEDENCE", JSON.stringify(providers.calculatorResult("2 + 3 * 4")?.label ?? null));
            report("CALC_PAREN", JSON.stringify(providers.calculatorResult("(2 + 3) * 4")?.label ?? null));
            report("CALC_DIV", JSON.stringify(providers.calculatorResult("9 / 2")?.label ?? null));
            report("CALC_DIVZERO", JSON.stringify(providers.calculatorResult("1 / 0")));
            report("CALC_NEGATIVE", JSON.stringify(providers.calculatorResult("-5 + 2")?.label ?? null));
            report("CALC_NONMATH", JSON.stringify(providers.calculatorResult("firefox")));
            report("CALC_GARBLED", JSON.stringify(providers.calculatorResult("2 + + 2")));
            report("CALC_EMPTY", JSON.stringify(providers.calculatorResult("")));

            // Emoji is OFF by default — must yield nothing until enabled.
            report("EMOJI_DISABLED", JSON.stringify(providers.emojiResults("fire")));

            Settings.set({ modules: Object.assign({}, Settings.modules, {
                launcherProviders: Object.assign({}, Settings.modules.launcherProviders, { emoji: true })
            }) });

            // Settings.set() shells out asynchronously; give it a beat to
            // land and the FileView watch to pick the write back up before
            // reading.
            settleTimer.start();
        }
    }

    Timer {
        id: settleTimer
        interval: 800
        onTriggered: {
            report("EMOJI_ENABLED_FIRE", JSON.stringify(providers.emojiResults("fire").map(e => e.label)));
            report("EMOJI_ENABLED_NOMATCH", JSON.stringify(providers.emojiResults("zzznomatch")));
            report("EMOJI_ENABLED_EMPTY", JSON.stringify(providers.emojiResults("")));
            report("DONE", "1");
        }
    }
}
