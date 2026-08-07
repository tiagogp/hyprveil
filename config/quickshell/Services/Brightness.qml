// Backlight (and, opportunistically, DDC) brightness as an observable service.
//
// hardware-action.sh already owns the XF86 keys and the OSD; this singleton is
// the missing half — a value the Quick Settings slider can read and drive
// without the panel spawning brightnessctl itself. Two capabilities, not one:
// `available` is the internal panel backlight, `ddcAvailable` is external
// monitors over DDC/CI. Either, both, or neither can be true, and the slider
// hides the row it has no capability for instead of drawing a dead control.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Bumped by the slider while it is on screen, same contract as SysInfo —
    // nothing needs to poll a value nobody is looking at.
    property int watchers: 0
    readonly property bool active: watchers > 0
    function watch(): void { root.watchers++; }
    function unwatch(): void { if (root.watchers > 0) root.watchers--; }

    // "unknown" until the first probe resolves, then true/false for the life of
    // the session. Hardware does not appear or vanish without a restart, so one
    // probe at startup is enough — unlike SysInfo's poll, there is nothing here
    // that changes on its own.
    property bool probed: false
    property bool available: false
    property int percent: 0
    readonly property var state: ({ percent: root.percent, ddcMonitors: root.ddcMonitors })
    readonly property bool busy: backlightProbe.running || backlightSet.running || ddcDetect.running || ddcSetter.running
    property string error: ""
    property double lastUpdated: 0

    // DDC is opportunistic and slow (a real I2C round trip per monitor), so it
    // is probed once, lazily, only when the section that needs it becomes
    // visible — see requestDdcProbe().
    property bool ddcProbed: false
    property bool ddcAvailable: false
    // [{ bus: "3", percent: 62 }, ...] — one entry per detected external
    // display. Empty when ddcutil is missing or nothing answered.
    property var ddcMonitors: []

    function refresh(): void {
        backlightProbe.running = true;
    }

    function requestDdcProbe(): void {
        if (root.ddcProbed) return;
        root.ddcProbed = true;
        ddcDetect.running = true;
    }

    // Same field brightnessctl reports and the same parse hardware-action.sh
    // already uses: device,class,current,percent%,max.
    Process {
        id: backlightProbe
        command: ["sh", "-c",
            "command -v brightnessctl >/dev/null 2>&1 && brightnessctl -m 2>/dev/null | head -n1 || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.probed = true;
                const line = text.trim();
                if (!line) { root.available = false; return; }
                const parts = line.split(",");
                const pct = Number((parts[3] ?? "").replace("%", ""));
                if (isNaN(pct)) { root.available = false; return; }
                root.available = true;
                root.percent = Math.max(0, Math.min(100, Math.round(pct)));
                root.lastUpdated = Date.now();
            }
        }
    }

    Process {
        id: backlightSet
        property int target: 0
        command: ["sh", "-c", "command -v brightnessctl >/dev/null 2>&1 && brightnessctl set " + target + "% >/dev/null 2>&1 || true"]
    }

    function setPercent(pct: int): void {
        if (!root.available) return;
        const clamped = Math.max(0, Math.min(100, Math.round(pct)));
        root.percent = clamped; // optimistic, so the knob does not lag the drag
        backlightSet.target = clamped;
        backlightSet.running = true;
    }

    // `ddcutil detect --brief` lists one "Display N" / "I2C bus: /dev/i2c-M"
    // pair per monitor when it can talk to it at all — a laptop-only machine,
    // or one where ddcutil is not installed, prints nothing and the row stays
    // hidden rather than showing a control that always fails.
    Process {
        id: ddcDetect
        command: ["sh", "-c",
            "command -v ddcutil >/dev/null 2>&1 && ddcutil detect --brief 2>/dev/null | grep -oE 'I2C bus: */dev/i2c-[0-9]+' | grep -oE '[0-9]+$' || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const buses = text.trim().split("\n").filter(b => b !== "");
                root.ddcAvailable = buses.length > 0;
                root.ddcMonitors = buses.map(b => ({ bus: b, percent: 50 }));
                for (const b of buses) ddcGetter.query(b);
            }
        }
    }

    // VCP feature 0x10 is brightness in the MCCS spec; `ddcutil getvcp 10`
    // prints "VCP 10 C current value = N, max value = M" on success. One
    // process per bus, sequential, because I2C over DDC does not like being
    // hammered concurrently from two callers.
    Process {
        id: ddcGetter
        property string bus: ""
        function query(b) {
            ddcGetter.bus = b;
            ddcGetter.running = true;
        }
        command: ["sh", "-c",
            "ddcutil --bus " + bus + " getvcp 10 2>/dev/null | grep -oE 'current value = *[0-9]+' | grep -oE '[0-9]+$' || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const pct = Number(text.trim());
                if (isNaN(pct)) return;
                root.ddcMonitors = root.ddcMonitors.map(m =>
                    m.bus === ddcGetter.bus ? { bus: m.bus, percent: pct } : m);
            }
        }
    }

    Process {
        id: ddcSetter
        property string bus: ""
        property int target: 0
        command: ["sh", "-c", "ddcutil --bus " + bus + " setvcp 10 " + target + " >/dev/null 2>&1 || true"]
    }

    function setDdcPercent(bus: string, pct: int): void {
        const clamped = Math.max(0, Math.min(100, Math.round(pct)));
        root.ddcMonitors = root.ddcMonitors.map(m =>
            m.bus === bus ? { bus: m.bus, percent: clamped } : m);
        ddcSetter.bus = bus;
        ddcSetter.target = clamped;
        ddcSetter.running = true;
    }

    Component.onCompleted: root.refresh()
}
