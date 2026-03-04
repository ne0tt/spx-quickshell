import QtQuick
import Quickshell.Io

// ============================================================
// VOLUME STATE — single source of truth for VolumePanel and
// VolumeDropdown. Polls pamixer every 5 s in the background;
// call refresh() to force an immediate re-read.
// ============================================================
QtObject {
    id: _state

    // ── Public state ──────────────────────────────────────
    property int  volume: 0
    property bool muted:  false

    // ── Public API ────────────────────────────────────────
    function refresh()       { _fetchProc.running = true }
    function toggleMute()    { _muteProc.running  = true }
    function volumeUp()      { _upProc.running    = true }
    function volumeDown()    { _downProc.running  = true }
    function setVolume(v)    {
        _setVolProc.command = ["sh", "-c", "pamixer --set-volume " + String(v) + "; pamixer --get-volume; pamixer --get-mute"]
        _setVolProc.running = true
    }

    // ── Shared output parser — reused by fetch + all mutations ──
    function _parse(s) {
        var v = parseInt(s)
        if (!isNaN(v)) _state.volume = v
        else           _state.muted  = (s === "true")
    }

    // ── Fetch process (background poll) ──────────────────
    property var _fetchProc: Process {
        command: ["sh", "-c", "pamixer --get-volume; pamixer --get-mute"]
        stdout: SplitParser { onRead: data => _state._parse(data.trim()) }
    }

    // ── Mutation processes — each applies the change and reads state
    //    back in a single fork, eliminating the follow-up refresh() call.
    property var _muteProc: Process {
        command: ["sh", "-c", "pamixer --toggle-mute; pamixer --get-volume; pamixer --get-mute"]
        stdout: SplitParser { onRead: data => _state._parse(data.trim()) }
    }

    property var _upProc: Process {
        command: ["sh", "-c", "pamixer -i 5; pamixer --get-volume; pamixer --get-mute"]
        stdout: SplitParser { onRead: data => _state._parse(data.trim()) }
    }

    property var _downProc: Process {
        command: ["sh", "-c", "pamixer -d 5; pamixer --get-volume; pamixer --get-mute"]
        stdout: SplitParser { onRead: data => _state._parse(data.trim()) }
    }

    property var _setVolProc: Process {
        command: ["sh", "-c", "echo"]
        stdout: SplitParser { onRead: data => _state._parse(data.trim()) }
    }

    // ── Background poll — keeps panel in sync with system ─
    property var _timer: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: _state.refresh()
    }
}
