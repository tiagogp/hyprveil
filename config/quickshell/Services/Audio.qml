pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool available: sink !== null || source !== null
    readonly property var state: ({
        volume: sink?.audio?.volume ?? 0,
        muted: sink?.audio?.muted ?? false,
        microphoneMuted: source?.audio?.muted ?? false
    })
    property bool busy: false
    property string error: ""
    property double lastUpdated: Date.now()

    function refresh(): void { lastUpdated = Date.now(); }
    function setVolume(value: real): void {
        if (!sink?.audio) return;
        sink.audio.volume = Math.max(0, Math.min(1.5, value));
        lastUpdated = Date.now();
    }
    function setMuted(value: bool): void {
        if (sink?.audio && sink.audio.muted !== value) sink.audio.muted = value;
        lastUpdated = Date.now();
    }
    function setMicrophoneMuted(value: bool): void {
        if (source?.audio && source.audio.muted !== value) source.audio.muted = value;
        lastUpdated = Date.now();
    }
}
