// Probe for Osd/StatusCapsule.qml — see tests/p19-status-capsule-smoke.sh,
// which runs this headlessly (see p13-qml-load-smoke.sh) and reads the file
// it writes. Wired into the automated gate for the same reason
// tests/manual/providers exists: this exercises real cross-scope signal
// wiring (Popups.dontDisturb -> StatusCapsule, CalmMode.active ->
// StatusCapsule) that a source-text grep cannot prove actually fires.
//
// Notif/Osd/Services here are SYMLINKS to the real directories, so this can
// never drift into probing a stale copy.
import QtQuick
import Quickshell
import Quickshell.Io
import "Notif"
import "Osd"
import "Services"

ShellRoot {
    Popups { id: notifs; statusCapsule: cap }
    StatusCapsule { id: cap }

    readonly property string outPath: Quickshell.env("HYPRVEIL_PROBE_OUT")
    function report(key, value) {
        Quickshell.execDetached(["sh", "-c",
            'printf "%s:%s\\n" "$1" "$2" >> "$3"',
            "_", key, value, outPath]);
    }

    // Same startup race Providers.qml's probe waits out — Settings and the
    // rest of the scene need a beat to finish their own async setup.
    Timer {
        interval: 500
        running: true
        onTriggered: {
            report("BEFORE", cap.open ? "open" : "closed");

            notifs.dontDisturb = true;
            report("DND_ON", cap.open + ":" + cap.text);

            notifs.dontDisturb = false;
            report("DND_OFF", cap.open + ":" + cap.text);

            CalmMode.toggleManual();
            settleTimer.start();
        }
    }

    Timer {
        id: settleTimer
        interval: 800
        onTriggered: {
            report("CALM_ON", cap.open + ":" + cap.text);
            CalmMode.toggleManual();
            settleTimer2.start();
        }
    }

    Timer {
        id: settleTimer2
        interval: 800
        onTriggered: {
            report("CALM_OFF", cap.open + ":" + cap.text);
            report("DONE", "1");
        }
    }
}
