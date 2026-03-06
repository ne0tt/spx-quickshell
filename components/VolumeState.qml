import QtQuick
import Quickshell.Services.Pipewire

/*
    VOLUME STATE — reactive binding to the PipeWire default sink.
    No polling, no pamixer processes. PipeWire signals update
    volume and muted automatically whenever any client (keyboard
    shortcut, pavucontrol, etc.) changes the sink state.
*/

QtObject {
    id: _state

    // Keep the default sink node alive and bound.
    
    property var _tracker: PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    // The live default audio sink; null until PipeWire is ready.
    readonly property var sink: Pipewire.defaultAudioSink

    // ── Public state (0–100 int + bool) ───────────────────
    // Derived reactively from sink.audio — no manual sync needed.
    readonly property int  volume: sink?.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted:  sink?.audio?.muted ?? false

    // ── Public API ────────────────────────────────────────
    function refresh()    {}   // no-op: state is always up to date
    function toggleMute() { if (sink?.audio) sink.audio.muted = !sink.audio.muted }
    function volumeUp()   { if (sink?.audio) sink.audio.volume = Math.min(1.0, sink.audio.volume + 0.05) }
    function volumeDown() { if (sink?.audio) sink.audio.volume = Math.max(0.0, sink.audio.volume - 0.05) }
    function setVolume(v) { if (sink?.audio) sink.audio.volume = Math.max(0.0, Math.min(1.0, v / 100)) }
}
