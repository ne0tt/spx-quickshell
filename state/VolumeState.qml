pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// ============================================================
// VOLUME STATE — reactive PipeWire default-sink binding.
// PipeWire signals fire automatically when any client changes
// the default sink (keyboard shortcuts, pavucontrol, etc.).
//
// Access from any QML file (import qs.state or "../../state"):
//   VolumeState.volume
//   VolumeState.muted
//   VolumeState.toggleMute() / volumeUp() / volumeDown() / setVolume(v)
// ============================================================
Singleton {
    id: volumeState

    property var _pwTracker: PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    readonly property var  audioSink: Pipewire.defaultAudioSink
    readonly property int  volume:    audioSink?.audio ? Math.min(100, Math.round(audioSink.audio.volume * 100)) : 0
    readonly property bool muted:     audioSink?.audio?.muted ?? false

    function toggleMute() { if (audioSink?.audio) audioSink.audio.muted = !audioSink.audio.muted }
    function volumeUp()   { if (audioSink?.audio) audioSink.audio.volume = Math.min(1.0, audioSink.audio.volume + 0.05) }
    function volumeDown() { if (audioSink?.audio) audioSink.audio.volume = Math.max(0.0, audioSink.audio.volume - 0.05) }
    function setVolume(v) { if (audioSink?.audio) audioSink.audio.volume = Math.max(0.0, Math.min(1.0, v / 100)) }
}
