#!/usr/bin/env bash
# The ICS calendar-events adapter: past/future/UTC/all-day parsing, ordering,
# limit, missing directories, and malformed files.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p15.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

SCRIPT="$REPO/config/hypr/scripts/calendar-events.sh"

# --- no calendar directories: empty array, not an error ---------------------
out=$(HYPRVEIL_ICS_DIRS="$TMP/nowhere" "$SCRIPT" upcoming)
[ "$out" = "[]" ] || fail "missing ICS directories did not fall back to an empty array: $out"
ok "no ICS source falls back to an empty event list without erroring"

# --- past/future/UTC/all-day events, ordering, and filtering ----------------
mkdir -p "$TMP/cal"
future_local=$(date -d "+2 days" +%Y%m%dT%H%M%S)
future_utc=$(date -d "+5 days" +%Y%m%dT%H%M%SZ)
past_local=$(date -d "-2 days" +%Y%m%dT%H%M%S)
future_date=$(date -d "+1 days" +%Y%m%d)
cat > "$TMP/cal/calendar.ics" <<EOF
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:1
SUMMARY:Team standup
DTSTART:$future_local
END:VEVENT
BEGIN:VEVENT
UID:2
SUMMARY:Old meeting
DTSTART:$past_local
END:VEVENT
BEGIN:VEVENT
UID:3
SUMMARY:UTC event
DTSTART:$future_utc
END:VEVENT
BEGIN:VEVENT
UID:4
SUMMARY:All-day trip
DTSTART;VALUE=DATE:$future_date
END:VEVENT
END:VCALENDAR
EOF

out=$(HYPRVEIL_ICS_DIRS="$TMP/cal" "$SCRIPT" upcoming)
echo "$out" | jq -e 'length == 3' >/dev/null || fail "expected 3 upcoming events, got: $out"
echo "$out" | jq -e '.[0].summary == "All-day trip"' >/dev/null \
    || fail "events are not sorted soonest-first: $out"
echo "$out" | jq -e 'any(.[]; .summary == "Old meeting") | not' >/dev/null \
    || fail "a past event was not filtered out"
echo "$out" | jq -e 'any(.[]; .summary == "UTC event")' >/dev/null \
    || fail "a UTC DTSTART was not parsed"
ok "past events are excluded; local/UTC/all-day DTSTART all parse and sort soonest-first"

# --- limit ------------------------------------------------------------------
out=$(HYPRVEIL_ICS_DIRS="$TMP/cal" "$SCRIPT" upcoming 1)
echo "$out" | jq -e 'length == 1' >/dev/null || fail "limit argument was not honored: $out"
ok "the limit argument caps the number of events returned"

# --- malformed / incomplete ICS content does not crash the adapter ---------
mkdir -p "$TMP/badcal"
cat > "$TMP/badcal/bad.ics" <<'EOF'
this is not
a valid ics file at all
BEGIN:VEVENT
SUMMARY:incomplete
EOF
out=$(HYPRVEIL_ICS_DIRS="$TMP/badcal" "$SCRIPT" upcoming 2>"$TMP/stderr")
[ "$out" = "[]" ] || fail "malformed ICS content should yield no events, not: $out"
ok "malformed or incomplete ICS content is skipped instead of crashing the adapter"

ok "calendar-events.sh smoke tests passed"
