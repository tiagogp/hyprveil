pragma Singleton

import QtQuick
import Quickshell
import "../Adapters"
import "../Utils"

Singleton {
    id: root

    readonly property bool available: LauncherAdapter.available
    readonly property var state: ({ registry: LauncherAdapter.registry, files: fileResults })
    readonly property bool busy: LauncherAdapter.busy
    readonly property string error: LauncherAdapter.error
    readonly property double lastUpdated: LauncherAdapter.lastUpdated
    readonly property var registry: LauncherAdapter.registry
    readonly property var fileResults: {
        const provider = providerByKind("files");
        return LauncherAdapter.matches.map(path => ({
            kind: "action", id: "provider-file-" + path,
            label: Strings.basename(path), sub: path,
            glyph: String.fromCodePoint(provider?.glyphCodepoint ?? 0x1F4C1),
            run: () => SystemActions.openUri(path)
        }));
    }

    readonly property var _mathPattern: /^[-+*/().\d\s]+$/
    readonly property var _emoji: [
        { name: "smile", ch: "🙂" }, { name: "grin", ch: "😄" }, { name: "laugh", ch: "😂" },
        { name: "heart", ch: "❤️" }, { name: "thumbsup", ch: "👍" }, { name: "thumbsdown", ch: "👎" },
        { name: "fire", ch: "🔥" }, { name: "eyes", ch: "👀" }, { name: "thinking", ch: "🤔" },
        { name: "party", ch: "🎉" }, { name: "check", ch: "✅" }, { name: "cross", ch: "❌" },
        { name: "star", ch: "⭐" }, { name: "rocket", ch: "🚀" }, { name: "clap", ch: "👏" },
        { name: "wave", ch: "👋" }, { name: "cry", ch: "😢" }, { name: "sunglasses", ch: "😎" }
    ]

    function refresh(): void { LauncherAdapter.refresh(); }
    function enabled(id: string): bool { return Settings.providers.launcher?.[id] ?? false; }
    function providerByKind(kind: string): var {
        return registry.find(provider => provider.kind === kind && enabled(provider.id));
    }

    function _evalExpr(text: string): real {
        let i = 0;
        function peek() { return text[i]; }
        function digit(c) { return c >= "0" && c <= "9"; }
        function spaces() { while (peek() === " ") i++; }
        function number() {
            spaces();
            const start = i;
            if (peek() === "-") i++;
            while (i < text.length && (digit(peek()) || peek() === ".")) i++;
            if (i === start || (i === start + 1 && text[start] === "-")) throw new Error("number");
            return Number(text.slice(start, i));
        }
        function factor() {
            spaces();
            if (peek() === "(") {
                i++;
                const value = expression();
                spaces();
                if (peek() !== ")") throw new Error("parenthesis");
                i++;
                return value;
            }
            return number();
        }
        function term() {
            let value = factor();
            for (;;) {
                spaces();
                if (peek() === "*") { i++; value *= factor(); }
                else if (peek() === "/") { i++; const divisor = factor(); if (divisor === 0) throw new Error("zero"); value /= divisor; }
                else break;
            }
            return value;
        }
        function expression() {
            let value = term();
            for (;;) {
                spaces();
                if (peek() === "+") { i++; value += term(); }
                else if (peek() === "-") { i++; value -= term(); }
                else break;
            }
            return value;
        }
        const value = expression();
        spaces();
        if (i !== text.length) throw new Error("input");
        return value;
    }

    function calculatorResult(query: string): var {
        const provider = providerByKind("calculator");
        const valueText = query.trim();
        if (!provider || valueText === "" || !_mathPattern.test(valueText) || !/\d/.test(valueText)) return null;
        try {
            const value = _evalExpr(valueText);
            if (!isFinite(value)) return null;
            const display = Number.isInteger(value) ? String(value)
                : value.toFixed(6).replace(/0+$/, "").replace(/\.$/, "");
            return { kind: "action", id: "provider-calculator",
                label: valueText + " = " + display,
                glyph: String.fromCodePoint(provider.glyphCodepoint ?? 0x2795),
                run: () => SystemActions.copyText(display) };
        } catch (e) { return null; }
    }

    function emojiResults(query: string): var {
        const provider = providerByKind("emoji");
        const value = query.trim().toLowerCase();
        if (!provider || value === "") return [];
        return _emoji.filter(entry => entry.name.includes(value)).slice(0, 5).map(entry => ({
            kind: "action", id: "provider-emoji-" + entry.name,
            label: entry.ch + "  " + entry.name,
            glyph: String.fromCodePoint(provider.glyphCodepoint ?? 0x1F642),
            run: () => SystemActions.copyText(entry.ch)
        }));
    }

    function search(query: string): void {
        if (!providerByKind("files")) {
            LauncherAdapter.matches = [];
            return;
        }
        LauncherAdapter.searchFiles(query);
    }
}
