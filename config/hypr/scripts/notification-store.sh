#!/usr/bin/env bash
# Persisted notification history: a small, capped, atomically-written JSON
# array under XDG state. Popups.qml calls this on every notification and reads
# it back once at startup, so history survives a shell restart — the gap the
# competitive analysis calls out (Hyprveil's history was session-memory only).
#
# Deliberately narrow-scope for privacy: only appName, summary, image, urgency
# and a timestamp are stored. The message BODY — the part most likely to carry
# something sensitive (a 2FA code, a DM preview) — is never written to disk,
# mirroring the lock screen's existing "count only, never contents" rule.
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil"
STORE_FILE="$STATE_DIR/notifications.json"
LOCK_FILE="$STATE_DIR/notifications.lock"
LIMIT=200

message() { printf '%s\n' "$*" >&2; }

nstore_write_locked() {
    local json=$1 tmp
    tmp=$(mktemp "$STATE_DIR/.notifications.XXXXXX")
    printf '%s\n' "$json" > "$tmp"
    mv -f "$tmp" "$STORE_FILE"
}

nstore_valid() {
    jq -e 'type == "array" and all(.[]; type == "object" and (.sid|type=="string"))' \
        "$1" >/dev/null 2>&1
}

nstore_ensure_locked() {
    mkdir -p "$STATE_DIR"
    if [ ! -e "$STORE_FILE" ] || ! nstore_valid "$STORE_FILE"; then
        if [ -e "$STORE_FILE" ]; then
            local backup
            backup="$STORE_FILE.invalid-$(date +%Y%m%d-%H%M%S)"
            cp -a "$STORE_FILE" "$backup" 2>/dev/null || true
            message "Malformed notification history was backed up to $backup; history was reset."
        fi
        nstore_write_locked '[]'
    fi
}

nstore_init_locked() {
    mkdir -p "$STATE_DIR"
    (
        flock -x 200
        nstore_ensure_locked
    ) 200>"$LOCK_FILE"
}

cmd_list() {
    if [ -e "$STORE_FILE" ] && nstore_valid "$STORE_FILE"; then
        cat "$STORE_FILE"
        return
    fi
    nstore_init_locked
    cat "$STORE_FILE"
}

# append <appName> <summary> <image> <urgency>
# A store id (sid) is stamped here rather than trusted from the caller — it is
# how a later `remove` targets exactly one entry regardless of what the app's
# own (reusable, app-scoped) notification id was.
cmd_append() {
    local app=${1:-} summary=${2:-} image=${3:-} urgency=${4:-normal}
    local sid ts current updated
    sid="$(date +%s%N)-$RANDOM"
    ts=$(date +%s)
    # Truncated defensively even though the caller already caps length —
    # a store that trusts its own writer twice is one that survives the
    # writer changing later without a matching re-audit here.
    summary=${summary:0:300}
    mkdir -p "$STATE_DIR"
    (
        flock -x 200
        nstore_ensure_locked
        current=$(cat "$STORE_FILE")
        updated=$(jq -nc --argjson state "$current" \
            --arg sid "$sid" --arg app "$app" --arg summary "$summary" \
            --arg image "$image" --arg urgency "$urgency" --argjson ts "$ts" --argjson limit "$LIMIT" '
            ($state + [{sid:$sid, app:$app, summary:$summary, image:$image,
                        urgency:$urgency, ts:$ts}])
            | if length > $limit then .[length - $limit:] else . end')
        nstore_write_locked "$updated"
    ) 200>"$LOCK_FILE"
}

cmd_remove() {
    local sid=${1:?usage: notification-store.sh remove <sid>} current updated
    mkdir -p "$STATE_DIR"
    (
        flock -x 200
        nstore_ensure_locked
        current=$(cat "$STORE_FILE")
        updated=$(jq -c --arg sid "$sid" '[.[] | select(.sid != $sid)]' <<<"$current")
        nstore_write_locked "$updated"
    ) 200>"$LOCK_FILE"
}

cmd_clear() {
    mkdir -p "$STATE_DIR"
    (
        flock -x 200
        nstore_write_locked '[]'
    ) 200>"$LOCK_FILE"
}

case "${1:-}" in
    list)   cmd_list ;;
    append) shift; cmd_append "$@" ;;
    remove) shift; cmd_remove "$@" ;;
    clear)  cmd_clear ;;
    *)
        printf 'Usage: %s list|append <app> <summary> <image> <urgency>|remove <sid>|clear\n' "${0##*/}" >&2
        exit 2
        ;;
esac
