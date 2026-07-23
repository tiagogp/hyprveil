// The keybind scheme, read back out of the file that defines it.
//
// keybindings.conf is the only source of truth. Nothing here restates a bind,
// so a cheatsheet cannot drift from the config the way a hand-written table in
// the README does — rebinding a key changes what the modal shows, with no
// second place to remember to edit.
//
// The file's own comment conventions carry the structure: `##!` opens a
// section (the end-4 convention this scheme was ported from), and a plain `#`
// comment introduces the group of binds beneath it. Both were already there as
// authoring aids; this reads them as the outline they always were.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.config/hypr/keybindings.conf"

    // [ { title, groups: [ { label, binds: [ { keys: [...], desc, search } ] } ] } ]
    property var sections: []
    property bool failed: false

    // Binds in the file, not rows on screen: _collapse turns ten per-digit
    // workspace binds into one row, and counting rows would report a scheme a
    // third smaller than the one the file defines. Set by _parse, which is the
    // only place both numbers exist at once.
    property int count: 0

    // Forces a re-read. The modal calls this on opening: the file is edited by
    // hand between openings, and watchChanges only covers the case where the
    // shell happened to be watching a path that already existed.
    function refresh() {
        file.reload();
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.failed = false;
            root.sections = root._parse(text());
        }
        onLoadFailed: {
            root.failed = true;
            root.sections = [];
        }
    }

    // ------------------------------------------------------------------
    // Parsing
    // ------------------------------------------------------------------

    function _parse(text) {
        const vars = {};
        const sections = [];
        let section = null;
        let group = null;
        // The label a plain comment has staged for the next group of binds.
        let pending = "";

        for (const raw of text.split("\n")) {
            const line = raw.trim();

            // A blank line ends a group, which is what makes the plain comments
            // above each cluster read as headings rather than as stray notes.
            if (line === "") {
                pending = "";
                group = null;
                continue;
            }

            if (line.startsWith("##!")) {
                section = { title: _sectionTitle(line.slice(3)), groups: [] };
                sections.push(section);
                group = null;
                pending = "";
                continue;
            }

            if (line.startsWith("#")) {
                pending = _label(line.replace(/^#+\s*/, ""));
                continue;
            }

            const eq = line.indexOf("=");
            if (eq === -1)
                continue;

            const lhs = line.slice(0, eq).trim();
            const rhs = line.slice(eq + 1).trim();

            // `$terminal = kitty` and friends. Collected before the binds that
            // use them, so a bind can be shown as the command it actually runs.
            if (lhs.startsWith("$")) {
                vars[lhs] = rhs;
                continue;
            }

            // bind, bindl, binde, bindm, bindr, bindel — the flags change when
            // a bind fires, not what it does, so they do not reach the display.
            if (!/^bind[lermdointsp]*$/.test(lhs))
                continue;

            if (section === null) {
                section = { title: "Other", groups: [] };
                sections.push(section);
            }

            // Split into at most four fields: an exec command may contain
            // commas of its own, and they belong to the command.
            const parts = rhs.split(",");
            const mods = (parts[0] || "").trim();
            const key = (parts[1] || "").trim();
            const dispatcher = (parts[2] || "").trim();
            const args = parts.slice(3).join(",").trim();

            if (group === null || pending !== "") {
                group = { label: pending, binds: [] };
                section.groups.push(group);
                pending = "";
            }

            group.binds.push({
                mods: mods,
                dispatcher: dispatcher,
                digit: /^[0-9]$/.test(key),
                keys: _combo(mods, key),
                desc: _describe(dispatcher, args, vars)
            });
        }

        let total = 0;
        for (const s of sections) {
            for (const g of s.groups) {
                total += g.binds.length;
                g.binds = _collapse(g.binds);
                for (const b of g.binds)
                    b.search = (b.keys.join(" ") + " " + b.desc).toLowerCase();
            }
            // A section whose binds were all comments and no binds is a heading
            // with nothing under it.
            s.groups = s.groups.filter(g => g.binds.length > 0);
        }

        root.count = total;
        return sections.filter(s => s.groups.length > 0);
    }

    // "Utilities (end-4 cluster: screenshot / OCR / …)" is a note to whoever
    // edits the file, not a heading. Everything from the first aside on is the
    // note.
    function _sectionTitle(raw) {
        const t = raw.trim();
        let cut = t.length;
        for (const mark of [" (", " —", " -", ":"]) {
            const at = t.indexOf(mark);
            if (at !== -1 && at < cut)
                cut = at;
        }
        return t.slice(0, cut);
    }

    function _label(raw) {
        const t = raw.replace(/\s*\([^)]*\)/g, "").trim();
        return t === "" ? "" : t.charAt(0).toUpperCase() + t.slice(1);
    }

    // ------------------------------------------------------------------
    // Keys
    // ------------------------------------------------------------------

    readonly property var _modNames: ({
        "$mod": "Super", "SUPER": "Super", "CTRL": "Ctrl",
        "SHIFT": "Shift", "ALT": "Alt"
    })

    readonly property var _keyNames: ({
        "Return": "Enter", "Escape": "Esc", "Print": "PrtSc", "Delete": "Del",
        "SUPER_L": "Super", "GRAVE": "`",
        "minus": "-", "equal": "=", "slash": "/", "Period": ".",
        "semicolon": ";", "apostrophe": "'",
        "bracketleft": "[", "bracketright": "]",
        "left": "←", "right": "→", "up": "↑", "down": "↓",
        "mouse:272": "Left click", "mouse:273": "Right click",
        "mouse_down": "Scroll ↓", "mouse_up": "Scroll ↑",
        "XF86AudioPlay": "Play/Pause", "XF86AudioNext": "Next track",
        "XF86AudioPrev": "Prev track", "XF86AudioMute": "Mute",
        "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −",
        "XF86MonBrightnessUp": "Bright +", "XF86MonBrightnessDown": "Bright −"
    })

    function _combo(mods, key) {
        const out = [];
        for (const m of mods.split(/\s+/))
            if (m !== "")
                out.push(root._modNames[m] || m);
        if (key !== "") {
            const label = root._keyNames[key] || key.replace(/^XF86/, "");
            // `bindr = $mod, SUPER_L` is the tap-Super-alone launcher: the
            // modifier IS the key, and drawing it twice reads as a chord that
            // cannot be pressed.
            if (out.indexOf(label) === -1)
                out.push(label);
        }
        return out;
    }

    // Runs of per-digit binds are one idea written ten times. Collapsing them
    // is not cosmetic: ten near-identical rows bury the binds around them, and
    // the workspace section is otherwise thirty rows of noise.
    function _collapse(binds) {
        const out = [];
        let i = 0;
        while (i < binds.length) {
            let j = i;
            if (binds[i].digit) {
                while (j + 1 < binds.length && binds[j + 1].digit
                       && binds[j + 1].mods === binds[i].mods
                       && binds[j + 1].dispatcher === binds[i].dispatcher)
                    j++;
            }

            if (j - i >= 2) {
                const keys = binds[i].keys.slice(0, -1);
                keys.push(binds[i].keys[binds[i].keys.length - 1] + " – "
                          + binds[j].keys[binds[j].keys.length - 1]);
                out.push({ keys: keys, desc: _rangeDesc(binds[i].dispatcher) });
                i = j + 1;
            } else {
                out.push(binds[i]);
                i++;
            }
        }
        return out;
    }

    function _rangeDesc(dispatcher) {
        switch (dispatcher) {
        case "workspace":             return "Switch to workspace 1–10";
        case "movetoworkspace":       return "Move the window to workspace 1–10";
        case "movetoworkspacesilent": return "Send the window to workspace 1–10 and stay put";
        }
        return dispatcher + " 1–10";
    }

    // ------------------------------------------------------------------
    // Actions
    // ------------------------------------------------------------------

    readonly property var _dirs: ({ l: "left", r: "right", u: "up", d: "down" })

    function _describe(dispatcher, args, vars) {
        if (dispatcher === "exec")
            return _execDescribe(args, vars);

        switch (dispatcher) {
        case "killactive":     return "Close the focused window";
        case "exit":           return "Exit Hyprland";
        case "togglefloating": return "Float / unfloat the window";
        case "fullscreen":     return args === "1" ? "Maximize, keeping the bar and gaps"
                                                   : "Fullscreen";
        case "pin":            return "Keep the window on every workspace";
        case "pseudo":         return "Pseudo-tile the window";
        case "togglesplit":    return "Flip the split direction";
        case "splitratio":     return "Resize the split (" + args + ")";
        case "movefocus":      return "Focus the window " + (root._dirs[args] || args);
        case "movewindow":     return root._dirs[args]
                                    ? "Move the window " + root._dirs[args]
                                    : "Drag to move a floating window";
        case "resizewindow":   return "Drag to resize a floating window";
        case "workspace":      return _workspace(args);
        case "movetoworkspace":
            return "Move the window to " + _target(args);
        case "movetoworkspacesilent":
            return "Send the window to " + _target(args) + " and stay put";
        case "togglespecialworkspace":
            return "Toggle the " + args + " workspace";
        case "focusmonitor":
            return args === "+1" ? "Focus the next monitor"
                 : args === "-1" ? "Focus the previous monitor"
                 : "Focus monitor " + args;
        }

        return args === "" ? dispatcher : dispatcher + " " + args;
    }

    function _workspace(args) {
        const rel = args.match(/^([re])([+-])(\d+)$/);
        if (rel) {
            const forward = rel[2] === "+";
            return (forward ? "Next" : "Previous") + " workspace"
                 + (rel[1] === "e" ? ", creating it if empty" : "");
        }
        return "Switch to " + _target(args);
    }

    function _target(args) {
        if (args.startsWith("special:"))
            return "the " + args.slice(8) + " workspace";
        return "workspace " + args;
    }

    // $terminal, $fileManager, $browser, and $editor are defined in apps.conf,
    // not here (see the comment at the top of keybindings.conf), so they never
    // reach `vars` and would otherwise show up in the modal as the literal,
    // unsubstituted variable name. Matching the variable name itself is the
    // one place these four need special-casing.
    function _execDescribe(args, vars) {
        const term = args.match(/^\$terminal(?:\s+-e\s+(.+))?$/);
        if (term)
            return term[1] ? "Open " + term[1] + " in a terminal" : "Open terminal";
        if (args === "$fileManager") return "Open file manager";
        if (args === "$browser")     return "Open browser";
        if (args === "$editor")      return "Open editor";
        if (args === "$launcher")    return "Open app launcher";
        if (args === "$locker")      return "Lock the screen";
        if (args === "$powermenu")   return "Open power menu";

        const cmd = root._command(args, vars);
        for (const rule of root._execRules)
            if (rule.re.test(cmd))
                return rule.desc;

        // No rule recognizes it: fall back to the command itself rather than
        // a guess, so a newly added bind is still legible, just less tidy.
        return cmd;
    }

    // Matched against the command after variable substitution, in order —
    // first match wins, which is why the more specific screenshot/OCR combo
    // is listed ahead of the plain region-grab it also contains as a
    // substring. Each entry describes one exec bind in keybindings.conf; a
    // bind added there without a matching rule here just shows its raw
    // command (see _execDescribe), so this list can lag without breaking
    // anything.
    readonly property var _execRules: [
        { re: /tesseract/,               desc: "Screenshot a region and copy its text (OCR)" },
        { re: /grim -g.*slurp/,          desc: "Screenshot a selected region to clipboard" },
        { re: /Screenshots.*grim/,       desc: "Screenshot the full screen to a file and clipboard" },
        { re: /^grim - \| wl-copy$/,     desc: "Screenshot the full screen to clipboard" },
        { re: /rofi -show window/,       desc: "Open window switcher" },
        { re: /overview toggle/,         desc: "Toggle window overview" },
        { re: /cheatsheet toggle/,       desc: "Toggle this shortcuts window" },
        { re: /hyprpicker/,              desc: "Pick a color from the screen" },
        { re: /cliphist list/,           desc: "Open clipboard history" },
        { re: /rofimoji/,                desc: "Open emoji picker" },
        { re: /notification-daemon\.sh toggle/, desc: "Toggle do-not-disturb" },
        { re: /wallpaper\.sh pick/,      desc: "Pick a wallpaper" },
        { re: /zoom\.sh -/,              desc: "Zoom out" },
        { re: /zoom\.sh/,                desc: "Zoom in" },
        { re: /playerctl play-pause/,    desc: "Play / pause media" },
        { re: /playerctl next/,          desc: "Next track" },
        { re: /playerctl previous/,      desc: "Previous track" },
        { re: /osd-action\.sh microphone-mute/, desc: "Mute / unmute microphone" },
        { re: /osd-action\.sh volume-mute/,     desc: "Mute / unmute volume" },
        { re: /osd-action\.sh volume-up/,       desc: "Volume up" },
        { re: /osd-action\.sh volume-down/,     desc: "Volume down" },
        { re: /osd-action\.sh brightness-up/,   desc: "Brightness up" },
        { re: /osd-action\.sh brightness-down/, desc: "Brightness down" },
        { re: /hyprctl kill/,            desc: "Force-kill the focused window" },
        { re: /systemctl suspend/,       desc: "Suspend the system" }
    ]

    // The command as it will actually run, not a label invented for it. A
    // hand-written description is a second source of truth that goes stale the
    // first time the command changes and nobody remembers this file exists.
    function _command(args, vars) {
        let cmd = args;
        for (const name in vars)
            cmd = cmd.split(name).join(vars[name]);
        // Script paths are all under the same two config dirs; the directory is
        // the same on every row and so carries no information.
        cmd = cmd.replace(/~\/\.config\/[A-Za-z0-9._-]+\/(scripts\/)?/g, "");
        return cmd.replace(/\s+/g, " ").trim();
    }
}
