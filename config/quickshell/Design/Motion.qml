pragma Singleton

import QtQuick
import Quickshell
import ".."
import "../Services" as Services

Singleton {
    readonly property int enterDuration: Services.Motion.duration(Tokens.durModal)
    readonly property int exitDuration: Services.Motion.duration(Tokens.dur2h)
    readonly property int pageDuration: Services.Motion.duration(Tokens.dur2h)
    readonly property var easing: Tokens.easeOut
    readonly property var modalEasing: Tokens.easeModal

    function duration(ms: int): int { return Services.Motion.duration(ms); }
}
