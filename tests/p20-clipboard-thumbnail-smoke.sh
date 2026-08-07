#!/usr/bin/env bash
# The clipboard image-thumbnail pipeline Panel/ClipboardSection.qml's Process
# runs (decode via cliphist, downsize via magick/convert) — extracted
# verbatim here so this test and the QML source cannot silently drift apart.
# Also checks the isImageEntry() detection heuristic against a REAL cliphist
# list line, since the shape of that line ("binary data 312 B png 8x8", not
# an "image/png" mime string) was verified empirically, not assumed.
set -euo pipefail

TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p20.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

if ! command -v cliphist >/dev/null 2>&1; then
    printf 'WARN: cliphist is unavailable; skipping the clipboard thumbnail smoke test\n' >&2
    exit 0
fi
if ! command -v convert >/dev/null 2>&1 && ! command -v magick >/dev/null 2>&1; then
    printf 'WARN: neither magick nor convert is available; skipping the clipboard thumbnail smoke test\n' >&2
    exit 0
fi

# The exact pipeline from ClipboardSection.qml's thumbGen Process, as a
# function taking (entry, outPath) instead of QML's ($1, $2).
generate_thumb() {
    local entry=$1 out=$2
    mkdir -p "$(dirname "$out")" || return 0
    [ -f "$out" ] && return 0
    local im
    im=$(command -v magick || command -v convert) || return 0
    printf '%s\n' "$entry" | cliphist decode | "$im" - -resize 64x64 "$out" 2>/dev/null || true
}

# isImageEntry(), as a shell equivalent of the QML regex, for testing
# against real cliphist output without a JS engine.
is_image_entry() {
    printf '%s' "$1" | grep -qiE 'binary data.*\b(png|jpe?g|gif|bmp|webp|tiff|ico)\b'
}

export XDG_CACHE_HOME="$TMP/cache"
export HOME="$TMP/home"
mkdir -p "$HOME"

command -v magick >/dev/null 2>&1 && IM=magick || IM=convert
"$IM" -size 8x8 xc:red "$TMP/test.png" 2>/dev/null

cat "$TMP/test.png" | cliphist store
printf 'plain text on the clipboard\n' | cliphist store

image_line=$(cliphist list | grep 'binary data')
text_line=$(cliphist list | grep 'plain text')

is_image_entry "$image_line" || fail "a real cliphist image entry was not detected as an image: $image_line"
if is_image_entry "$text_line"; then fail "a plain text entry was misdetected as an image: $text_line"; fi
ok "isImageEntry matches a real cliphist binary-image line and not a text line"

out="$TMP/thumb.png"
generate_thumb "$image_line" "$out"
[ -f "$out" ] || fail "thumbnail was not generated for a real image entry"
command -v identify >/dev/null 2>&1 && {
    dims=$(identify -format '%wx%h' "$out" 2>/dev/null)
    case "$dims" in
        64x64|*x64|64x*) : ;;
        *) fail "thumbnail was not resized to fit 64x64: $dims" ;;
    esac
}
ok "generate_thumb decodes and downsizes a real clipboard image entry"

before_mtime=$(stat -c %Y "$out")
sleep 1
generate_thumb "$image_line" "$out"
after_mtime=$(stat -c %Y "$out")
[ "$before_mtime" = "$after_mtime" ] || fail "an existing thumbnail was regenerated instead of reused"
ok "an already-generated thumbnail is reused, not redecoded"

# --- missing image tooling leaves no thumbnail, and does not error ---------
# A PATH with everything generate_thumb needs EXCEPT magick/convert — both
# live in the same directory as mkdir/dirname/cliphist on this machine, so
# excluding a directory would take those down too; symlinking in only the
# tools that should still resolve is the reliable way to hide just the two.
out2="$TMP/thumb2.png"
mkdir -p "$TMP/limitedbin"
for tool in mkdir dirname cliphist grep cat; do
    ln -s "$(command -v "$tool")" "$TMP/limitedbin/$tool"
done
(
    # shellcheck disable=SC2123  # intentional, subshell-scoped: hides
    # magick/convert without also hiding the other tools this test needs.
    PATH="$TMP/limitedbin"
    generate_thumb "$image_line" "$out2"
)
[ ! -f "$out2" ] || fail "a thumbnail was produced with no magick/convert on PATH"
ok "missing magick/convert leaves no thumbnail instead of failing the pipeline"

ok "clipboard thumbnail smoke tests passed"
