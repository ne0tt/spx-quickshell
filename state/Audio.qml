pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ============================================================
// AUDIO SERVICE — handles CAVA audio visualizer 
// Complements AppState's basic volume control
// ============================================================
Singleton {
    id: audioService
    
    // ── CAVA Visualizer ──────────────────────────────────────────
    property var cava: QtObject {
        id: cavaObj
        
        // Audio visualization data
        property var values: new Array(24).fill(0)  // Initialize with 24 bars (even number)
        property bool active: false
        
        // Control when CAVA should run (set by UI components)
        property bool visualizationVisible: false
        
        // Auto-restart timer (defined before process so it can be referenced)
        property var restartTimer: Timer {
            interval: 2000
            repeat: false
            onTriggered: {
                cavaProcess.running = true
            }
        }
        
        // CAVA process - outputs raw data to stdout
        property var _cavaProcess: Process {
            id: cavaProcess
            running: cavaObj.visualizationVisible
            command: [
                "cava", 
                "-p", Quickshell.env("HOME") + "/dotfiles/.config/quickshell/cava.conf"
            ]
            
            stdout: SplitParser {
                splitMarker: "\n"
                onRead: data => {
                    if (data.trim() === "") return
                    
                    try {
                        // Parse CAVA raw output (semicolon-separated values)
                        var rawValues = data.trim().split(';')
                        var parsedValues = []
                        
                        for (var i = 0; i < rawValues.length && i < 24; i++) {
                            var val = parseInt(rawValues[i] || '0') / 1000.0  // normalize to 0-1
                            parsedValues.push(Math.max(0, Math.min(1, val || 0)))
                        }
                        
                        // Fill remaining slots if needed
                        while (parsedValues.length < 24) {
                            parsedValues.push(0)
                        }
                        
                        cavaObj.values = parsedValues
                        cavaObj.active = parsedValues.some(v => v > 0.01)
                    } catch (e) {
                        // Silently ignore parse errors
                    }
                }
            }
            
            onExited: (exitCode) => {
                if (exitCode !== 0) {
                    // Restart after 2 seconds
                    cavaObj.restartTimer.start()
                }
            }
        }
    }
}