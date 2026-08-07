#!/usr/bin/env bash
# Upcoming calendar events for Panel/Calendar.qml — the roadmap's "Eventos no
# calendário", via an ICS adapter rather than a live EDS D-Bus session.
#
# The real Evolution Data Server API is asynchronous (open a CalendarView,
# submit an S-expression query, collect signals) — not something to bolt onto
# a bash script with any confidence without a live EDS session to validate
# against. Every EDS-backed calendar (Evolution, GNOME Online Accounts,
# Thunderbird via some setups) also keeps a plain `.ics` file on disk that
# this can read directly, and the roadmap itself lists "EDS/ICS opcional" —
# ICS is the supported half of that pair here.
#
# No RRULE (recurring event) expansion: a recurring event's UNANTICIPATED
# next-occurrence math is its own project, and printing only the literal
# DTSTART is honest about that rather than silently wrong for every meeting
# that repeats weekly.
set -uo pipefail

message() { printf '%s\n' "$*" >&2; }

# Every directory a `.ics` might live in. Overridable so a test (or someone
# with an unusual setup) is not stuck with these exact paths.
ics_dirs() {
    if [ -n "${HYPRVEIL_ICS_DIRS:-}" ]; then
        printf '%s\n' "${HYPRVEIL_ICS_DIRS//:/$'\n'}"
        return
    fi
    local data_home=${XDG_DATA_HOME:-$HOME/.local/share}
    printf '%s\n' \
        "$data_home/evolution/calendar" \
        "$data_home/khal" \
        "$data_home/hyprveil/calendar"
}

find_ics_files() {
    local dir
    while IFS= read -r dir; do
        [ -n "$dir" ] && [ -d "$dir" ] || continue
        find "$dir" -type f -name '*.ics' 2>/dev/null
    done < <(ics_dirs)
}

# Unfolds RFC 5545 line continuations (a line starting with a space or tab
# continues the previous one) so a wrapped SUMMARY does not get truncated at
# whatever column the writer wrapped it at.
unfold() {
    awk '
        /^[ \t]/ { line = line substr($0, 2); next }
        NR > 1   { print line }
        { line = $0 }
        END { print line }
    '
}

# DTSTART comes in three shapes: a bare DATE (20260810), a floating
# DATE-TIME (20260810T090000), or a UTC DATE-TIME (20260810T090000Z). All
# three normalize to epoch seconds so events sort and filter uniformly;
# floating time is treated as local time, which is right for the common case
# and wrong only for an event explicitly authored in another timezone (a
# TZID parameter is not resolved here).
to_epoch() {
    local raw=$1 y m d hh=00 mm=00 ss=00 utc=0
    case "$raw" in
        *Z) utc=1; raw=${raw%Z} ;;
    esac
    case "$raw" in
        ????????T??????)
            hh=${raw:9:2}; mm=${raw:11:2}; ss=${raw:13:2} ;;
    esac
    y=${raw:0:4}; m=${raw:4:2}; d=${raw:6:2}
    [ -n "$y" ] && [ -n "$m" ] && [ -n "$d" ] || { echo ""; return; }
    if [ "$utc" = 1 ]; then
        date -u -d "${y}-${m}-${d} ${hh}:${mm}:${ss} UTC" +%s 2>/dev/null
    else
        date -d "${y}-${m}-${d} ${hh}:${mm}:${ss}" +%s 2>/dev/null
    fi
}

# Extracts every VEVENT's (summary, dtstart-epoch, dtstart-raw) as
# tab-separated rows, one file at a time — a single malformed file cannot
# take the rest down with it, since each is parsed independently and a parse
# failure just yields no rows for that file.
extract_events() {
    local file=$1
    unfold < "$file" | awk -F: '
        /^BEGIN:VEVENT/ { insummary=0; summary=""; dtstart=""; next }
        /^SUMMARY/      { summary=substr($0, index($0, ":") + 1); next }
        /^DTSTART/      { dtstart=substr($0, index($0, ":") + 1); next }
        /^END:VEVENT/   { if (dtstart != "") print summary "\t" dtstart; next }
    '
}

cmd_upcoming() {
    local limit=${1:-5} now rows
    now=$(date +%s)
    rows=""
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        while IFS=$'\t' read -r summary dtstart; do
            [ -n "$dtstart" ] || continue
            local epoch
            epoch=$(to_epoch "$dtstart")
            [ -n "$epoch" ] || continue
            [ "$epoch" -ge "$now" ] || continue
            rows="$rows$epoch"$'\t'"$summary"$'\t'"$dtstart"$'\n'
        done < <(extract_events "$file")
    done < <(find_ics_files)

    if [ -z "$rows" ]; then
        printf '[]\n'
        return
    fi

    printf '%s' "$rows" | sort -n | head -n "$limit" | \
        jq -Rn --arg tz "$(date +%Z)" '
            [inputs | select(length > 0) | split("\t") |
                {epoch: (.[0] | tonumber), summary: .[1], raw: .[2]}]
        '
}

case "${1:-}" in
    upcoming) shift; cmd_upcoming "$@" ;;
    *)
        printf 'Usage: %s upcoming [limit]\n' "${0##*/}" >&2
        exit 2
        ;;
esac
