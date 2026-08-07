// Advanced launcher providers — files, calculator, emoji — the roadmap's
// "Providers avançados do launcher" AND, since they are the same mechanism
// seen from two angles, its "Extensões restritas": a small declarative
// registry (hypr/scripts/data/launcher-providers.json) says which provider
// KINDS exist and their metadata; Settings.modules.launcherProviders says
// which are actually enabled. A provider is never arbitrary code — only one
// of the fixed `kind`s below is understood, and an entry with an unknown
// kind, or otherwise malformed, is skipped individually rather than failing
// the whole registry (and therefore the whole launcher) to load.
//
// Off by default except calculator (see settings-store.sh's defaults): a
// four-function calculator has no process to spawn and nothing to leak, so
// it costs nothing to leave on, unlike files (spawns `find` over $HOME) or
// emoji (a longer result list on every keystroke).
import QtQuick
import Quickshell
import Quickshell.Io
import "../Services"

Item {
    id: root

    readonly property string registryPath:
        Quickshell.env("HOME") + "/.config/hypr/scripts/data/launcher-providers.json"

    property var registry: []
    // Files is the only asynchronous provider — a subprocess search cannot
    // resolve inside the synchronous `staticResults` the way arithmetic and
    // an in-memory emoji filter can, so it gets its own debounced Process and
    // its own results list that Launcher.qml merges in alongside the rest.
    property var fileResults: []
    property string _query: ""

    function enabled(id) {
        return Settings.modules.launcherProviders?.[id] ?? false;
    }

    function providerByKind(kind) {
        return root.registry.find(p => p.kind === kind && root.enabled(p.id));
    }

    FileView {
        path: root.registryPath
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                // Only entries shaped the way this file understands survive —
                // see the header note. A future kind this build does not know
                // about is exactly the case this filter exists for.
                const known = ["calculator", "files", "emoji"];
                root.registry = (parsed.providers ?? []).filter(p =>
                    p && typeof p.id === "string" && known.includes(p.kind));
            } catch (e) {
                root.registry = [];
            }
        }
        onLoadFailed: root.registry = []
    }

    // --- Calculator --------------------------------------------------------
    // A small recursive-descent parser rather than eval()/Function(): the
    // query is arbitrary text typed into a launcher, and a four-function
    // calculator has no business running it as script.
    function _evalExpr(text) {
        let i = 0;
        function peek() { return text[i]; }
        function isDigit(c) { return c >= "0" && c <= "9"; }
        function skipSpace() { while (peek() === " ") i++; }

        function parseNumber() {
            skipSpace();
            const start = i;
            if (peek() === "-") i++;
            while (i < text.length && (isDigit(peek()) || peek() === ".")) i++;
            if (i === start || (i === start + 1 && text[start] === "-"))
                throw new Error("expected number");
            return Number(text.slice(start, i));
        }
        function parseFactor() {
            skipSpace();
            if (peek() === "(") {
                i++;
                const v = parseExpr();
                skipSpace();
                if (peek() !== ")") throw new Error("expected )");
                i++;
                return v;
            }
            return parseNumber();
        }
        function parseTerm() {
            let v = parseFactor();
            for (;;) {
                skipSpace();
                if (peek() === "*") { i++; v *= parseFactor(); }
                else if (peek() === "/") { i++; const d = parseFactor(); if (d === 0) throw new Error("div by zero"); v /= d; }
                else break;
            }
            return v;
        }
        function parseExpr() {
            let v = parseTerm();
            for (;;) {
                skipSpace();
                if (peek() === "+") { i++; v += parseTerm(); }
                else if (peek() === "-") { i++; v -= parseTerm(); }
                else break;
            }
            return v;
        }

        const value = parseExpr();
        skipSpace();
        if (i !== text.length) throw new Error("trailing input");
        return value;
    }

    // A query only counts as a calculator query when it plainly looks like
    // arithmetic (digits and operators only) — otherwise every stray "3D"
    // app name or window title would be swallowed as a failed parse attempt.
    readonly property var _mathPattern: /^[-+*/().\d\s]+$/

    function calculatorResult(query) {
        const provider = root.providerByKind("calculator");
        if (!provider) return null;
        const q = query.trim();
        if (q === "" || !root._mathPattern.test(q) || !/\d/.test(q)) return null;
        try {
            const value = root._evalExpr(q);
            if (!isFinite(value)) return null;
            const display = Number.isInteger(value) ? String(value) : value.toFixed(6).replace(/0+$/, "").replace(/\.$/, "");
            return {
                kind: "action", id: "provider-calculator", label: q + " = " + display,
                glyph: String.fromCodePoint(provider.glyphCodepoint ?? 0x2795),
                run: () => Quickshell.execDetached(["wl-copy", display])
            };
        } catch (e) {
            return null;
        }
    }

    // --- Emoji ---------------------------------------------------------------
    // A short, static, curated list rather than the full Unicode emoji
    // database: this is a launcher row, not an emoji picker, and the roadmap
    // explicitly scopes this provider to "sob demanda" — small and fast, not
    // exhaustive.
    readonly property var _emoji: [
        { name: "smile", ch: "🙂" }, { name: "grin", ch: "😄" }, { name: "laugh", ch: "😂" },
        { name: "heart", ch: "❤️" }, { name: "thumbsup", ch: "👍" }, { name: "thumbsdown", ch: "👎" },
        { name: "fire", ch: "🔥" }, { name: "eyes", ch: "👀" }, { name: "thinking", ch: "🤔" },
        { name: "party", ch: "🎉" }, { name: "check", ch: "✅" }, { name: "cross", ch: "❌" },
        { name: "star", ch: "⭐" }, { name: "rocket", ch: "🚀" }, { name: "clap", ch: "👏" },
        { name: "wave", ch: "👋" }, { name: "cry", ch: "😢" }, { name: "sunglasses", ch: "😎" }
    ]

    function emojiResults(query) {
        const provider = root.providerByKind("emoji");
        if (!provider) return [];
        const q = query.trim().toLowerCase();
        if (q === "") return [];
        return root._emoji.filter(e => e.name.includes(q)).slice(0, 5).map(e => ({
            kind: "action", id: "provider-emoji-" + e.name, label: e.ch + "  " + e.name,
            glyph: String.fromCodePoint(provider.glyphCodepoint ?? 0x1F642),
            run: () => Quickshell.execDetached(["wl-copy", e.ch])
        }));
    }

    // --- Files -----------------------------------------------------------
    // Debounced: a search-per-keystroke against the home directory is a
    // process spawn nothing else in this launcher pays, so it waits for
    // typing to pause rather than racing itself on every character.
    Timer {
        id: fileDebounce
        interval: 150
        onTriggered: {
            if (root._query.trim() === "") { root.fileResults = []; return; }
            fileSearch.query = root._query.trim();
            fileSearch.running = true;
        }
    }

    function search(query) {
        root._query = query;
        const provider = root.providerByKind("files");
        if (!provider) { root.fileResults = []; return; }
        fileDebounce.restart();
    }

    Process {
        id: fileSearch
        property string query: ""
        // -iname wraps the query, not a shell-interpolated string, so a
        // query containing quotes or shell metacharacters cannot escape the
        // -iname argument the way it could through `sh -c "...$query..."`.
        command: ["timeout", "2", "find", Quickshell.env("HOME"),
            "-maxdepth", "6", "-iname", "*" + fileSearch.query + "*",
            "-not", "-path", "*/.*"]
        stdout: StdioCollector {
            onStreamFinished: {
                const provider = root.providerByKind("files");
                const lines = text.split("\n").filter(l => l !== "").slice(0, 8);
                root.fileResults = lines.map(path => ({
                    kind: "action", id: "provider-file-" + path, label: path.split("/").pop(),
                    sub: path,
                    glyph: String.fromCodePoint(provider?.glyphCodepoint ?? 0x1F4C1),
                    run: () => Quickshell.execDetached(["xdg-open", path])
                }));
            }
        }
    }
}
