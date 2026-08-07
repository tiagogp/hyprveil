#!/usr/bin/env bash
# Screen recording toggle: start/stop wf-recorder, confirmed by the same OSD
# osd-action.sh drives for volume/brightness/mic. Bound to $mod SHIFT+R,
# alongside the other screenshot/capture binds in keybindings.conf.
set -euo pipefail

PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/hyprveil-record.pid"
OUTPUT_DIR="$HOME/Videos/Screencasts"

show_osd() {
    command -v hyprveil >/dev/null 2>&1 || return 0
    hyprveil shell osd "$@" >/dev/null 2>&1 || true
}

is_recording() {
    [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

stop_recording() {
    local pid
    pid=$(cat "$PID_FILE")
    # SIGINT, not SIGKILL: wf-recorder finalizes the container's index on a
    # clean interrupt. A killed process leaves an unplayable file.
    kill -INT "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
    show_osd recording 0 true
}

start_recording() {
    command -v wf-recorder >/dev/null 2>&1 || {
        printf 'record.sh: wf-recorder is not installed\n' >&2
        exit 1
    }
    mkdir -p "$OUTPUT_DIR"
    local out
    out="$OUTPUT_DIR/Recording_$(date +%Y-%m-%d_%H.%M.%S).mp4"
    wf-recorder -f "$out" >/dev/null 2>&1 &
    disown
    echo "$!" > "$PID_FILE"
    show_osd recording 0 false
}

if is_recording; then
    stop_recording
else
    start_recording
fi
