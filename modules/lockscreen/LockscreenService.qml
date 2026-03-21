import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: lockRoot

    // Import config to access barMonitor setting  
    // Use relative import since lockscreen runs as separate process
    property alias config: configLoader.item
    
    Loader {
        id: configLoader
        source: "../../Config.qml"
    }

    // The lockscreen context manages authentication and shared state
    LockscreenContext {
        id: lockContext

        onUnlocked: {
            console.log("Lockscreen: User authenticated, unlocking session")
            
            // Unlock the session before exiting to avoid compositor fallback lock
            sessionLock.locked = false
            
            // Exit the lockscreen
            Qt.quit()
        }

        onFailed: {
            console.log("Lockscreen: Authentication failed")
        }
    }

    // Session lock manager
    WlSessionLock {
        id: sessionLock

        // Lock immediately when the service starts
        locked: true

        Component.onCompleted: {
            console.log("Lockscreen: Session locked")
        }

        onLockedChanged: {
            if (locked) {
                console.log("Lockscreen: Session lock activated")
            } else {
                console.log("Lockscreen: Session lock deactivated")
            }
        }

        // Create lock surface for each screen - WlSessionLockSurface automatically handles multi-monitor
        WlSessionLockSurface {
            LockscreenSurface {
                anchors.fill: parent
                context: lockContext
                
                // Determine if this screen is the primary monitor
                // Use same logic as main bar - respects config.barMonitor setting
                // Handle async config loading with fallback
                isPrimary: {
                    if (!config || !config.barMonitor) {
                        console.log("Primary monitor (fallback):", Quickshell.screens[0]?.name || "unknown")
                        return screen === Quickshell.screens[0]
                    }
                    const targetScreen = Quickshell.screens.find(s => s.name === config.barMonitor) ?? Quickshell.screens[0]
                    return screen === targetScreen
                }
            }
        }
    }

    // Handle Hyprland-specific events if available
    Connections {
        target: typeof Hyprland !== "undefined" ? Hyprland : null
        enabled: target !== null

        // Log monitor changes
        function onFocusedMonitorChanged() {
            if (Hyprland.focusedMonitor) {
                console.log("Lockscreen: Focused monitor changed to:", Hyprland.focusedMonitor.name)
            }
        }
    }

    // Emergency exit handling (Ctrl+Alt+Escape or similar)
    // This should be used very carefully and only for development/testing
    Connections {
        target: Quickshell
        
        function onLastWindowClosed() {
            console.log("Lockscreen: Emergency exit - last window closed")
            Qt.quit()
        }
    }

    Component.onCompleted: {
        console.log("Lockscreen: Service started")
        console.log("Available screens:", Quickshell.screens.length)
        
        for (let i = 0; i < Quickshell.screens.length; i++) {
            const screen = Quickshell.screens[i]
            console.log(`  Screen ${i}: ${screen.name} (${screen.width}x${screen.height})`)
        }
        
        if (typeof Hyprland !== "undefined" && Hyprland.focusedMonitor) {
            console.log("Primary monitor (Hyprland focused):", Hyprland.focusedMonitor.name)
        } else {
            console.log("Primary monitor (fallback):", Quickshell.screens[0]?.name || "none")
        }
    }
}