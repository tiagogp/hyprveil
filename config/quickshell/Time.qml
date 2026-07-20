// One clock for the whole shell.
//
// The bar, the notification timestamps, and the lock screen all need the time.
// A Timer per consumer means they tick at different moments and visibly disagree
// by a second; one singleton means they cannot.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // Only ticks once a minute. The design shows no seconds anywhere, so waking
    // the shell 60 times more often would buy nothing but battery drain.
    readonly property string clock: Qt.formatDateTime(_now, "hh:mm")
    readonly property string date: Qt.formatDateTime(_now, "dddd, MMMM d")

    property date _now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        // Polled at 1s but only assigned when the minute changes, so bindings
        // re-evaluate on the minute rather than continuously.
        onTriggered: {
            const now = new Date();
            if (now.getMinutes() !== _now.getMinutes() || now.getDate() !== _now.getDate())
                _now = now;
        }
    }

    // Relative timestamps for notification cards ("now", "4m", "2h").
    //
    // Guards the input rather than trusting it: every comparison against NaN is
    // false, so a missing or invalid date used to fall all the way through to
    // the last line and render "NaNd" instead of failing visibly.
    function ago(when): string {
        const ms = when instanceof Date ? when.getTime() : NaN;
        if (isNaN(ms)) return "";
        const mins = Math.floor((_now.getTime() - ms) / 60000);
        if (mins < 1) return "now";
        if (mins < 60) return mins + "m";
        const hours = Math.floor(mins / 60);
        if (hours < 24) return hours + "h";
        return Math.floor(hours / 24) + "d";
    }
}
