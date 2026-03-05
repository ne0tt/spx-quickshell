import QtQuick
import Quickshell.Io

// ============================================================
// BLUETOOTH STATE — single source of truth for BluetoothPanel,
// BluetoothDropdown and SettingsDropdown.
// Reads power state on startup and re-reads any time
// bluetoothctl reports a change (debounced 600 ms).
// Call refresh() to force an immediate re-read.
// ============================================================
QtObject {
    id: _state

    // ── Public state ──────────────────────────────────────
    property bool btPowered: false

    // ── Public API ────────────────────────────────────────
    function refresh()     { _checkProc.running = true }
    function powerOn()     { _onProc.running    = true }
    function powerOff()    { _offProc.running   = true }
    function togglePower() {
        if (_state.btPowered) _offProc.running = true
        else                  _onProc.running  = true
    }

    // ── State check ───────────────────────────────────────
    property var _checkProc: Process {
        running: false
        command: ["sh", "-c",
            "bluetoothctl show | grep -q 'Powered: yes' && echo 1 || echo 0"]
        stdout: SplitParser {
            onRead: data => { _state.btPowered = data.trim() === "1" }
        }
    }

    // ── Mutation processes ────────────────────────────────
    property var _onProc: Process {
        running: false
        command: ["bluetoothctl", "power", "on"]
        onExited: _state.refresh()
    }

    property var _offProc: Process {
        running: false
        command: ["bluetoothctl", "power", "off"]
        onExited: _state.refresh()
    }

    // ── Live monitor — debounced so rapid events only trigger once ─
    property var _monitor: Process {
        running: true
        command: ["bluetoothctl", "monitor"]
        stdout: SplitParser {
            onRead: data => _btDebounce.restart()
        }
    }

    property var _btDebounce: Timer {
        interval: 600
        repeat: false
        onTriggered: _state.refresh()
    }

    // ── Initial load ──────────────────────────────────────
    property var _init: Timer {
        interval: 0
        repeat: false
        running: true
        onTriggered: _state.refresh()
    }
}
