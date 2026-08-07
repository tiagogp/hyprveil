#!/usr/bin/env bash
# The optional Matugen accent provider: present, absent, and malformed output.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p14.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

ADAPTER="$REPO/config/hypr/scripts/matugen-adapter.sh"
mkdir -p "$TMP/bin" "$TMP/scriptdir"
touch "$TMP/wallpaper.jpg"

# Stand in for accent.sh so this test never touches real theme state — only
# the adapter's own parsing and command construction are under test here.
cat > "$TMP/scriptdir/accent.sh" <<'EOF'
#!/usr/bin/env bash
printf 'accent.sh %s\n' "$*" >> "$MOCK_LOG"
EOF
chmod +x "$TMP/scriptdir/accent.sh"
cp "$ADAPTER" "$TMP/scriptdir/matugen-adapter.sh"
chmod +x "$TMP/scriptdir/matugen-adapter.sh"

# --- matugen missing: neutral, exit 0, accent.sh never called --------------
MOCK_LOG="$TMP/log-missing"
: > "$MOCK_LOG"
PATH="/usr/bin:/bin" MOCK_LOG="$MOCK_LOG" "$TMP/scriptdir/matugen-adapter.sh" from-wallpaper "$TMP/wallpaper.jpg" \
    2>"$TMP/stderr-missing" || fail "missing matugen must exit 0 (neutral), not fail"
[ ! -s "$MOCK_LOG" ] || fail "accent.sh was called even though matugen is not installed"
grep -qi 'not installed' "$TMP/stderr-missing" || fail "missing-matugen message was not printed"
ok "matugen absent leaves the accent untouched and exits 0"

# --- matugen present, well-formed JSON: primary color reaches accent.sh ----
cat > "$TMP/bin/matugen" <<'EOF'
#!/usr/bin/env bash
echo '{"colors":{"primary":{"dark":"#abcdef","light":"#123456"}}}'
EOF
chmod +x "$TMP/bin/matugen"
MOCK_LOG="$TMP/log-ok"
: > "$MOCK_LOG"
PATH="$TMP/bin:/usr/bin:/bin" MOCK_LOG="$MOCK_LOG" "$TMP/scriptdir/matugen-adapter.sh" from-wallpaper "$TMP/wallpaper.jpg" \
    || fail "adapter did not exit 0 on well-formed matugen output"
grep -qx 'accent.sh set #abcdef' "$TMP/log-ok" \
    || fail "adapter did not hand the dark-mode primary color to accent.sh set"
ok "matugen present maps its primary color onto accent.sh set"

# --- matugen present but unparsable: neutral, not a crash -------------------
cat > "$TMP/bin/matugen" <<'EOF'
#!/usr/bin/env bash
echo 'not json'
EOF
chmod +x "$TMP/bin/matugen"
MOCK_LOG="$TMP/log-bad"
: > "$MOCK_LOG"
PATH="$TMP/bin:/usr/bin:/bin" MOCK_LOG="$MOCK_LOG" "$TMP/scriptdir/matugen-adapter.sh" from-wallpaper "$TMP/wallpaper.jpg" \
    2>"$TMP/stderr-bad" || fail "unparsable matugen output must exit 0 (neutral), not fail"
[ ! -s "$MOCK_LOG" ] || fail "accent.sh was called with unparsable matugen output"
ok "unparsable matugen output leaves the accent untouched instead of crashing"

# --- missing path argument / nonexistent file -------------------------------
"$TMP/scriptdir/matugen-adapter.sh" from-wallpaper >/dev/null 2>&1 \
    && fail "adapter accepted a missing path argument"
"$TMP/scriptdir/matugen-adapter.sh" from-wallpaper "$TMP/does-not-exist.jpg" >/dev/null 2>&1 \
    && fail "adapter accepted a nonexistent wallpaper path"
ok "adapter rejects a missing argument and a nonexistent wallpaper path"

ok "Matugen adapter smoke tests passed"
