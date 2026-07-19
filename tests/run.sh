#!/usr/bin/env bash
# P4 non-session quality gate. Use --require-shellcheck in CI/release validation.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
REQUIRE_SHELLCHECK=0
[ "${1:-}" != --require-shellcheck ] || REQUIRE_SHELLCHECK=1

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

cd "$REPO"
mapfile -t shell_files < <({ find scripts tests config -type f -name '*.sh' -print; printf '%s\n' install.sh; } | sort)

for file in "${shell_files[@]}"; do
    bash -n "$file" || fail "Bash syntax: $file"
done
ok "Bash syntax parses for ${#shell_files[@]} shell files"

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -x "${shell_files[@]}"
    ok "ShellCheck passes"
elif [ "$REQUIRE_SHELLCHECK" -eq 1 ]; then
    fail "ShellCheck is required (install the ShellCheck package)"
else
    printf 'WARN: ShellCheck is unavailable; bash -n ran, but the release gate requires tests/run.sh --require-shellcheck.\n' >&2
fi

for file in "${shell_files[@]}"; do
    [ -x "$file" ] || fail "script is not executable: $file"
done
ok "all shell entrypoints have executable bits"

python3 - "$REPO" <<'PY' || fail "JSON/JSONC parsing"
import json
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])

def strip_jsonc(text):
    result = []
    in_string = False
    escaped = False
    line_comment = False
    block_comment = False
    i = 0
    while i < len(text):
        char = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if line_comment:
            if char == "\n":
                line_comment = False
                result.append(char)
        elif block_comment:
            if char == "*" and nxt == "/":
                block_comment = False
                i += 1
        elif in_string:
            result.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        elif char == '"':
            in_string = True
            result.append(char)
        elif char == "/" and nxt == "/":
            line_comment = True
            i += 1
        elif char == "/" and nxt == "*":
            block_comment = True
            i += 1
        else:
            result.append(char)
        i += 1
    return "".join(result)

json.loads(strip_jsonc((repo / "config/waybar/config.jsonc").read_text()))
json.loads((repo / "config/swaync/config.json").read_text())
for number, line in enumerate((repo / "config/wlogout/layout").read_text().splitlines(), 1):
    if line.strip():
        try:
            json.loads(line)
        except json.JSONDecodeError as error:
            raise ValueError(f"config/wlogout/layout:{number}: {error}") from error
json.loads((repo / "config/waybar/scripts/dock-icons.json").read_text())
PY
ok "JSON and JSONC configs parse"

for test in tests/p0-smoke.sh tests/p1-smoke.sh tests/p2-smoke.sh \
            tests/p3-smoke.sh tests/p4-nested-smoke.sh tests/p5-smoke.sh \
            tests/p6-accent-smoke.sh; do
    printf '\n== %s ==\n' "$test"
    "$test"
done

printf '\nHyprveil non-session quality gate passed.\n'
