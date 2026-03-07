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
    property int    fontSize:   12
    property int    fontWeight: Font.Normal

    // Hyprland output name for the monitor the main bar is displayed on.
    // Persisted to settings.json and overwritten by SettingsDropdown on change.
    // Defaults to "DP-1"; updated when settings.json loads via FileView below.
    property string barMonitor: "DP-1"

    // FILEVIEW — reads settings.json via inotify; no blocking XHR.
    // watchChanges: true means SettingsDropdown writes are picked up automatically.
    property var _settingsFile: FileView {
        path: Qt.resolvedUrl("modules/settings/settings.json").toString().replace("file://", "")
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
