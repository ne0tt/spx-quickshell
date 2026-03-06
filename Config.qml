import Quickshell.Io
import QtQuick

// ============================================================
// CONFIG — shell-wide non-colour settings.
// Declared once in ShellRoot; all components reference via
// the global `config` id, e.g. config.fontFamily.
// ============================================================
QtObject {
    id: cfg

    // Font used everywhere in the bar and all dropdowns.
    // Change this one line to restyle the entire shell.
    property string fontFamily: "Hack Nerd Font"

    // Hyprland output name for the monitor the main bar is displayed on.
    // Persisted to settings.json and overwritten by SettingsDropdown on change.
    // Defaults to "DP-1"; updated when settings.json loads via FileView below.
    property string barMonitor: "DP-1"

    // Terminal emulator used when spawning interactive processes (e.g. yay -Syu).
    // Change this to your preferred terminal: "foot", "alacritty", "wezterm", etc.
    property string terminal: "kitty"

    // Hyprshade shader name applied when Night Light is enabled.
    // Must match a file in ~/.config/hypr/shaders/ (without extension).
    // Ships with hyprshade: "blue-light-filter", "vibrance", etc.
    property string nightLightShader: "blue-light-filter-50"

    // How often (in milliseconds) to check for pending Arch package updates.
    // Default: 900 000 ms = 15 minutes. Reduce for more frequent checks.
    property int updateCheckInterval: 900000

    // FILEVIEW — reads settings.json via inotify; no blocking XHR.
    // watchChanges: true means SettingsDropdown writes are picked up automatically.
    property var _settingsFile: FileView {
        path: Qt.resolvedUrl("settings.json").toString().replace("file://", "")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var s = JSON.parse(text())
                if (typeof s.barMonitor === "string" && s.barMonitor.length > 0)
                    cfg.barMonitor = s.barMonitor
            } catch (e) {}
        }
    }
}
