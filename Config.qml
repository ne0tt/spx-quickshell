import QtQuick

// ============================================================
// CONFIG — shell-wide non-colour settings.
// Declared once in ShellRoot; all components reference via
// the global `config` id, e.g. config.fontFamily.
// ============================================================
QtObject {
    // Font used everywhere in the bar and all dropdowns.
    // Change this one line to restyle the entire shell.
    property string fontFamily: "Hack Nerd Font"

    // Hyprland output name for the monitor the main bar is displayed on.
    // Persisted to settings.json and overwritten by SettingsDropdown on change.
    // Read synchronously on init so the correct monitor is available immediately
    // on hot-reloads (e.g. triggered by matugen writing Colors.qml), preventing
    // the bar from disappearing due to a race with SettingsDropdown's async load.
    property string barMonitor: _readBarMonitor()

    function _readBarMonitor() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", Qt.resolvedUrl("settings.json"), false)
        try {
            xhr.send()
            var s = JSON.parse(xhr.responseText)
            if (typeof s.barMonitor === "string" && s.barMonitor.length > 0)
                return s.barMonitor
        } catch (e) {}
        return "DP-1"
    }
}
