#!/usr/bin/env bash
# Lightweight non-session quality gate. Use --require-shellcheck in CI.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
REQUIRE_SHELLCHECK=0
[ "${1:-}" != --require-shellcheck ] || REQUIRE_SHELLCHECK=1

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

cd "$REPO"
shell_files=()
while IFS= read -r file; do
    shell_files+=("$file")
done < <({ find scripts tests config -type f -name '*.sh' -print; printf '%s\n' install.sh hyprveil; } | sort)

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
    printf 'WARN: ShellCheck is unavailable; bash -n ran. Use tests/run.sh --require-shellcheck when ShellCheck must be enforced.\n' >&2
fi

for file in "${shell_files[@]}"; do
    [ -x "$file" ] || fail "script is not executable: $file"
done
ok "all shell entrypoints have executable bits"

python3 - "$REPO" <<'PY' || fail "JSON/JSONC parsing"
import ast
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
for path in repo.joinpath("config").rglob("*.json"):
    json.loads(path.read_text())
ast.parse((repo / "config/hypr/scripts/data/settings-validator.py").read_text())
PY
ok "JSON and JSONC configs parse"

python3 config/hypr/scripts/data/settings-validator.py \
    config/hypr/scripts/data/settings-schema.json \
    <(jq '.default' config/hypr/scripts/data/settings-schema.json) \
    || fail "authoritative settings default does not satisfy its schema"
ok "authoritative settings default satisfies its schema"

python3 - "$REPO" <<'PY' || fail "Markdown links and formatting"
import pathlib
import re
import sys
from urllib.parse import unquote

repo = pathlib.Path(sys.argv[1])
link_pattern = re.compile(r'(!?)\[[^\]]+\]\(([^)]+)\)')
external_prefixes = (
    "http://",
    "https://",
    "mailto:",
    "app://",
)
# Screenshots are documented as pending in CONTRIBUTING.md ("Screenshots"
# section) until someone contributes a capture; don't fail the link check
# for those known-missing images.
pending_image_prefix = "docs/images/"

errors = []
for path in sorted(repo.rglob("*.md")):
    if ".git" in path.parts:
        continue
    data = path.read_bytes()
    rel = path.relative_to(repo)
    if data and not data.endswith(b"\n"):
        errors.append(f"{rel}: missing final newline")
    text = data.decode("utf-8")
    for number, line in enumerate(text.splitlines(), 1):
        if line.rstrip("\n\r") != line.rstrip():
            errors.append(f"{rel}:{number}: trailing whitespace")
        for match in link_pattern.finditer(line):
            is_image = match.group(1) == "!"
            target = match.group(2).strip()
            if not target or target.startswith("#") or target.startswith(external_prefixes):
                continue
            if target.startswith("<") and target.endswith(">"):
                target = target[1:-1]
            target = target.split("#", 1)[0]
            target = target.split("?", 1)[0]
            if not target:
                continue
            candidate = (path.parent / unquote(target)).resolve()
            try:
                candidate.relative_to(repo.resolve())
            except ValueError:
                errors.append(f"{rel}:{number}: link leaves repository: {match.group(2)}")
                continue
            if not candidate.exists():
                if is_image and target.startswith(pending_image_prefix):
                    continue
                errors.append(f"{rel}:{number}: missing linked path: {match.group(2)}")

if errors:
    raise SystemExit("\n".join(errors))
PY
ok "Markdown files have valid local links and formatting"

for test in tests/lock-smoke.sh \
            tests/palette-drift-smoke.sh \
            tests/qml-load-smoke.sh \
            tests/shell-architecture-smoke.sh \
            tests/shell-cli-smoke.sh \
            tests/layout-matrix-smoke.sh \
            tests/performance-compare-smoke.sh; do
    printf '\n== %s ==\n' "$test"
    "$test"
done

printf '\n== tests/bench.sh --check ==\n'
tests/bench.sh --check

printf '\nHyprveil non-session quality gate passed.\n'
