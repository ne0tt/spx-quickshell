pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ============================================================
// BLUETOOTH STATE — rfkill power control + bluetoothctl monitor.
// Power state is read on startup and re-read (debounced 600 ms)
// whenever bluetoothctl reports a change.
//
// Access from any QML file (import qs.state or "../../state"):
//   BluetoothState.btPowered
//   BluetoothState.togglePower() / powerOn() / powerOff()
// ============================================================
Singleton {
    id: bluetoothState

    property bool btPowered: false

    function powerOn()     { _btOnProc.running  = true }
    function powerOff()    { _btOffProc.running = true }
    function togglePower() {
        if (bluetoothState.btPowered) _btOffProc.running = true
        else                          _btOnProc.running  = true
    }

    property var _btCheckProc: Process {
        running: false
        command: ["sh", "-c",
            "bluetoothctl show | grep -q 'Powered: yes' && echo 1 || echo 0"]
        stdout: SplitParser {
            onRead: data => { bluetoothState.btPowered = data.trim() === "1" }
        }
    }

    property var _btOnProc: Process {
        running: false
        command: ["rfkill", "unblock", "bluetooth"]
        // Adapter needs ~400 ms to fully initialize after unblock
        onExited: _btOnDelayTimer.restart()
    }

    property var _btOnDelayTimer: Timer {
        interval: 400
        repeat:   false
        onTriggered: bluetoothState._btCheckProc.running = true
    }

    property var _btOffProc: Process {
        running: false
        command: ["rfkill", "block", "bluetooth"]
        onExited: bluetoothState._btCheckProc.running = true
    }

    property var _btMonitor: Process {
        running: true
        command: ["bluetoothctl", "monitor"]
        stdout: SplitParser {
            onRead: data => _btDebounce.restart()
        }
    }

    property var _btDebounce: Timer {
        interval: 600
        repeat:   false
        onTriggered: bluetoothState._btCheckProc.running = true
    }

    Component.onCompleted: _btCheckProc.running = true
}
