import Quickshell.Io
import QtQuick

// ============================================================
// CONFIG — shell-wide non-colour settings.
// Declared once in ShellRoot; all components reference via
// the global `config` id, e.g. config.fontFamily.
//
// Persisted settings (barMonitor, animations, blur,
// launcherFloating) are read from and written to
// modules/settings/settings.json via FileView.write() —
// no external processes required.
//
// A 500 ms debounce timer coalesces rapid changes into a
// single file write. reloadableId preserves in-flight
// property values across hot-reloads.
// ============================================================
QtObject {
    id: cfg

    // Font used everywhere in the bar and all dropdowns.
    // Change this one line to restyle the entire shell.
    property string fontFamily: "Hack Nerd Font"
    property int    fontSize:   12
    property int    fontWeight: Font.Normal

    // ── Persisted settings ─────────────────────────────────
    property string barMonitor:       "DP-1"
    property bool   animations:       true
    property bool   blur:             true
    property bool   launcherFloating: false
    property bool   workspaceGlow:    true
    
    // Wallpaper settings
    property string wallpaperFolder:      "wallpaper"
    property bool   wallpaperSubdirs:     true
    property string currentWallpaper:     ""

    // ── Load guard — prevents saves firing during initial read ──
    property bool _loaded: false

    // ── Debounce handlers — restart timer on any persisted change ──
    onBarMonitorChanged:       { if (_loaded) _saveTimer.restart() }
    onAnimationsChanged:       { if (_loaded) _saveTimer.restart() }
    onBlurChanged:             { if (_loaded) _saveTimer.restart() }
    onLauncherFloatingChanged: { if (_loaded) _saveTimer.restart() }
    onWorkspaceGlowChanged:    { if (_loaded) _saveTimer.restart() }
    onWallpaperFolderChanged:  { if (_loaded) _saveTimer.restart() }
    onWallpaperSubdirsChanged: { if (_loaded) _saveTimer.restart() }
    onCurrentWallpaperChanged: { if (_loaded) _saveTimer.restart() }

    // ── 500 ms debounce timer ─────────────────────────────
    property var _saveTimer: Timer {
        interval: 500
        repeat:   false
        onTriggered: cfg._doSave()
    }

    // ── Write helper — called by timer and eagerly on first load ──
    function _doSave() {
        _settingsFile.setText(JSON.stringify({
            barMonitor:       cfg.barMonitor,
            animations:       cfg.animations,
            blur:             cfg.blur,
            launcherFloating: cfg.launcherFloating,
            workspaceGlow:    cfg.workspaceGlow,
            wallpaperFolder:  cfg.wallpaperFolder,
            wallpaperSubdirs: cfg.wallpaperSubdirs,
            currentWallpaper: cfg.currentWallpaper
        }, null, 2))
    }

    // ── FileView — inotify read + FileView.write() via Quickshell.Io ──
    // watchChanges: true means external edits are reflected automatically.
    property var _settingsFile: FileView {
        path: Qt.resolvedUrl("modules/settings/settings.json").toString().replace("file://", "")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var s = JSON.parse(text())
                if (typeof s.barMonitor       === "string"  && s.barMonitor.length > 0) cfg.barMonitor       = s.barMonitor
                if (typeof s.animations       === "boolean")                             cfg.animations       = s.animations
                if (typeof s.blur             === "boolean")                             cfg.blur             = s.blur
                if (typeof s.launcherFloating === "boolean")                             cfg.launcherFloating = s.launcherFloating
                if (typeof s.workspaceGlow    === "boolean")                             cfg.workspaceGlow    = s.workspaceGlow
                if (typeof s.wallpaperFolder  === "string"  && s.wallpaperFolder.length > 0) cfg.wallpaperFolder = s.wallpaperFolder
                if (typeof s.wallpaperSubdirs === "boolean")                             cfg.wallpaperSubdirs = s.wallpaperSubdirs
                if (typeof s.currentWallpaper === "string")                             cfg.currentWallpaper = s.currentWallpaper
            } catch (e) {}
            cfg._loaded = true
            // Eagerly write back: creates the file on first run and captures
            // any reload-safe state that differs from an outdated file.
            cfg._doSave()
        }
    }
}
