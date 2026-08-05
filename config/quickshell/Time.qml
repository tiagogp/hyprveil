// One clock for the whole shell.
//
// The bar, the notification timestamps, and the lock screen all need the time.
// One SystemClock view keeps every consumer on the same minute boundary.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Only ticks once a minute. The design shows no seconds anywhere, so waking
    // the shell 60 times more often would buy nothing but battery drain.
    // SystemClock also aligns its update to the real minute boundary instead of
    // polling every second and checking whether the minute changed.
    readonly property string clock: Qt.formatDateTime(systemClock.date, "hh:mm")
    readonly property string date: Qt.formatDateTime(systemClock.date, "dddd, MMMM d")

    // The current date, exposed so the calendar can highlight today reactively.
    // Minute precision includes midnight, so the highlight rolls over without a
    // second timer or a polling assignment in QML.
    readonly property date today: systemClock.date

    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }

    // Relative timestamps for notification cards ("now", "4m", "2h").
    //
    // Guards the input rather than trusting it: every comparison against NaN is
    // false, so a missing or invalid date used to fall all the way through to
    // the last line and render "NaNd" instead of failing visibly.
    function ago(when): string {
        const ms = when instanceof Date ? when.getTime() : NaN;
        if (isNaN(ms)) return "";
        const mins = Math.floor((systemClock.date.getTime() - ms) / 60000);
        if (mins < 1) return "now";
        if (mins < 60) return mins + "m";
        const hours = Math.floor(mins / 60);
        if (hours < 24) return hours + "h";
        return Math.floor(hours / 24) + "d";
    }
}
