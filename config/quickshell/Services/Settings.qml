// The typed, versioned settings singleton — the QML half of
// settings-store.sh. Panel/Preferences.qml (and anything else that reads a
// user preference not owned by its own script, e.g. dock autohide, bar
// workspace mode, the calm-mode toggle, launcher providers, per-monitor
// overrides) binds to `Settings.data` here; nothing reads settings.json
// itself and nothing writes it directly — see set() below.
//
// Same shape as Motion.qml: a FileView watches the state file so an edit
// from anywhere (this panel, `settings-store.sh set` from a terminal, a
// future CLI) applies live with no second reload path to forget. The
// difference is the write side — Motion's file is single-word and trivial to
// validate inline, but settings.json has real structure, so every write
// still goes through the script for its merge/migrate/atomic-write, rather
// than duplicating that logic here and risking the two drifting apart.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string scriptPath:
        Quickshell.env("HOME") + "/.config/hypr/scripts/settings-store.sh"

    readonly property string path:
        (Quickshell.env("HYPRVEIL_STATE_HOME")
            || (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
                + "/hyprveil")
        + "/settings.json"

    // Mirrors settings-store.sh's defaults() so a binding sees sane values
    // for the one frame before the first load completes, and so a component
    // reading a field the store has not learned yet (a brand-new install,
    // before `ensure` below has ever run) still gets something rather than
    // undefined.
    property var data: ({
        version: 1,
        bar: { workspacesMode: "dynamic" },
        dock: { autohide: false },
        accent: { provider: "hyprveil" },
        modules: {
            calmMode: false,
            launcherProviders: { files: false, calculator: true, emoji: false }
        },
        preferences: { popupMonitor: "focused" },
        monitors: {},
        scenes: { profiles: {}, previous: null }
    })
    property bool loaded: false

    // Convenience readers so a binding can write `Settings.dock.autohide`
    // without every call site repeating the `?? {}` guard for a key an older
    // settings.json has not been migrated to yet.
    readonly property var bar: root.data.bar ?? {}
    readonly property var dock: root.data.dock ?? {}
    readonly property var accent: root.data.accent ?? {}
    readonly property var modules: root.data.modules ?? {}
    readonly property var preferences: root.data.preferences ?? {}
    readonly property var monitors: root.data.monitors ?? {}
    readonly property var scenes: root.data.scenes ?? {}

    // The saved override for one monitor's name (Hyprland's connector name,
    // e.g. "eDP-1"), or an empty object when it has none — a monitor nobody
    // has customized falls through to the shell's global defaults exactly as
    // if this function returned nothing at all.
    function monitorOverride(name: string): var {
        return root.monitors[name] ?? {};
    }

    // Dock autohide for one monitor: its own override when it has one,
    // otherwise the global default — the "herança global previsível" the
    // roadmap's per-monitor overrides item asks for.
    function dockAutohideFor(name: string): bool {
        const override = root.monitorOverride(name);
        return override.dockAutohide ?? (root.dock.autohide ?? false);
    }

    // Shallow-merges `patch` into the stored settings and re-reads the
    // result once the script's atomic write lands (via the FileView watch
    // below) — the same "write, then let the watcher pick it up" flow
    // Motion.qml and Accent.qml already use, so a caller never needs to
    // guess whether its own write already applied.
    function set(patch: var): void {
        writer.patchJson = JSON.stringify(patch);
        writer.running = true;
    }

    function setMonitorOverride(name: string, patch: var): void {
        const merged = Object.assign({}, root.monitorOverride(name), patch);
        const next = Object.assign({}, root.monitors);
        next[name] = merged;
        root.set({ monitors: next });
    }

    function reset(): void {
        resetter.running = true;
    }

    // Created once at startup to make sure settings.json exists (and is
    // migrated) even before anything calls set() — the same role
    // motion-profile.sh's --ensure plays for the motion state file.
    //
    // Every one of these three explicitly reloads the FileView when it
    // finishes, rather than trusting `watchChanges` alone. Two reasons:
    // watching a path that does NOT YET EXIST (a brand-new install, before
    // `ensure` has ever run) cannot be armed until the file exists, so a
    // FileView that only reacts to inotify never recovers from its own
    // first `onLoadFailed` on a cold start; and even once the file exists,
    // this process's own `mv -f tmp target` atomic rename replaces the
    // inode FileView had open rather than writing into it, which is not
    // guaranteed to be picked up as a change on every FileView backend. An
    // explicit reload after every write THIS SINGLETON initiates removes
    // both races instead of hoping the watch fires in time.
    Process {
        id: ensure
        command: [root.scriptPath, "get"]
        onRunningChanged: if (!running) file.reload()
    }

    Process {
        id: writer
        property string patchJson: "{}"
        command: [root.scriptPath, "set", patchJson]
        onRunningChanged: if (!running) file.reload()
    }

    Process {
        id: resetter
        command: [root.scriptPath, "reset"]
        onRunningChanged: if (!running) file.reload()
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(text());
                root.loaded = true;
            } catch (e) {
                // Keep the last-known-good in-memory value; settings-store.sh
                // itself is the thing responsible for backing up and
                // resetting a malformed file on disk.
            }
        }
        // No file yet on a brand-new install — `ensure` above creates it and
        // then explicitly reloads this FileView itself; see the Process
        // comment above for why that reload cannot be left to watchChanges.
        onLoadFailed: ensure.running = true
    }

    Component.onCompleted: ensure.running = true
}
