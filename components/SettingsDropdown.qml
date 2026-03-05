import Quickshell
import Quickshell.Io
import QtQuick

// ============================================================
// SETTINGS DROPDOWN — quick system toggles accessible from the bar.
//
// Toggles provided:
//   • Night Light    — wlsunset warm colour temperature
//   • Do Not Disturb — dunst notification pause
//   • Animations     — Hyprland motion effects  (hyprctl keyword)
//   • Blur           — compositor blur          (hyprctl keyword)
//   • Idle Inhibit   — prevent screen sleep     (systemd-inhibit)
//
// Night Light defaults (wlsunset): -l 50 -L 14 -t 3500 -T 6500
//   Adjust latitude (-l) and longitude (-L) to your location.
// ============================================================
DropdownBase {
    id: settingsDrop
    reloadableId: "settingsDropdown"

    // Row geometry — bump _rowCount when adding/removing toggle rows.
    // panelFullHeight is derived so implicitHeight stays correct automatically.
    readonly property int _rowCount:  7
    readonly property int _rowH:      48   // SettingsToggleRow height
    readonly property int _gap:       8    // Column spacing
    readonly property int _padTop:    8    // top padding inside content area
    readonly property int _padBottom: 12   // gap between last row and footer

    panelFullHeight: _padTop + _rowCount * _rowH + (_rowCount - 1) * _gap + _padBottom
    implicitHeight:  panelFullHeight + headerHeight + 52   // 16 ears + footerHeight + buffer
    panelWidth:      310
    panelTitle:      "Quick Settings"
    panelIcon:       "󰒓"
    headerHeight:    34

    // ── Queryable toggle states ───────────────────────────────
    property bool nightLight:  false   // reflected from pgrep on open
    property bool dnd:         false   // reflected from dunstctl on open
    property bool idleInhibit: false   // reflected from pgrep on open

    // Shared bluetooth state — injected from shell.qml (BluetoothState singleton)
    property QtObject btData: null
    readonly property bool btPowered: btData ? btData.btPowered : false

    // Non-queryable states — tracked locally; defaults assume enabled.
    // Reset to defaults on shell reload (intentional: no persistent state needed).
    property bool animations:       true
    property bool blur:             true
    // false = dropdown launcher centred in bar; true = floating rofi-style launcher
    property bool launcherFloating: false

    // Busy guards — prevent double-clicks during command execution
    property bool _nightLightBusy: false
    property bool _dndBusy:        false
    property bool _idleBusy:       false

    // Refresh queryable states whenever the panel opens
    onAboutToOpen: {
        nightLightCheck.running = true
        dndCheck.running        = true
        idleCheck.running       = true
        if (settingsDrop.btData) settingsDrop.btData.refresh()
    }

    // ═══════════════════════════════════════════════════════
    // NIGHT LIGHT — hyprshade
    // Shader name must match a file in ~/.config/hypr/shaders/.
    // Default: "blue-light-filter" (ships with hyprshade).
    // ═══════════════════════════════════════════════════════

    readonly property string _nlShader: "blue-light-filter-50"

    // Check whether a screen shader is currently active via hyprctl.
    // When no shader is set the option value contains "EMPTY"; any other
    // value means hyprshade (or another tool) has applied a shader.
    Process {
        id: nightLightCheck
        running: false
        command: ["sh", "-c",
            "hyprctl getoption decoration:screen_shader | grep -q EMPTY && echo 0 || echo 1"]
        stdout: SplitParser {
            onRead: data => {
                settingsDrop.nightLight = data.trim() === "1"
                settingsDrop._nightLightBusy = false
            }
        }
    }

    Process {
        id: nightLightEnable
        running: false
        command: ["hyprshade", "on", settingsDrop._nlShader]
        onExited: nightLightCheck.running = true
    }

    Process {
        id: nightLightDisable
        running: false
        command: ["hyprshade", "off"]
        onExited: nightLightCheck.running = true
    }

    function toggleNightLight() {
        if (settingsDrop._nightLightBusy) return
        settingsDrop._nightLightBusy = true
        if (settingsDrop.nightLight) {
            nightLightDisable.running = true
        } else {
            nightLightEnable.running = true
        }
    }

    // ═══════════════════════════════════════════════════════
    // DO NOT DISTURB — dunstctl
    // ═══════════════════════════════════════════════════════

    Process {
        id: dndCheck
        running: false
        command: ["dunstctl", "is-paused"]
        stdout: SplitParser {
            onRead: data => {
                settingsDrop.dnd = data.trim() === "true"
                settingsDrop._dndBusy = false
            }
        }
    }

    Process {
        id: dndToggle
        running: false
        command: ["dunstctl", "set-paused", "toggle"]
        onExited: dndCheck.running = true
    }

    function toggleDnd() {
        if (settingsDrop._dndBusy) return
        settingsDrop._dndBusy = true
        dndToggle.running = true
    }

    // ═══════════════════════════════════════════════════════
    // ANIMATIONS — hyprctl keyword
    // ═══════════════════════════════════════════════════════

    Process {
        id: animationsProc
        running: false
        property bool target: true
        command: ["hyprctl", "keyword", "animations:enabled",
                  animationsProc.target ? "true" : "false"]
    }

    function toggleAnimations() {
        settingsDrop.animations  = !settingsDrop.animations
        animationsProc.target    = settingsDrop.animations
        animationsProc.running   = true
    }

    // ═══════════════════════════════════════════════════════
    // BLUR — hyprctl keyword
    // ═══════════════════════════════════════════════════════

    Process {
        id: blurProc
        running: false
        property bool target: true
        command: ["hyprctl", "keyword", "decoration:blur:enabled",
                  blurProc.target ? "true" : "false"]
    }

    function toggleBlur() {
        settingsDrop.blur  = !settingsDrop.blur
        blurProc.target    = settingsDrop.blur
        blurProc.running   = true
    }

    // ═══════════════════════════════════════════════════════
    // IDLE INHIBIT — systemd-inhibit
    // ═══════════════════════════════════════════════════════

    Process {
        id: idleCheck
        running: false
        command: ["sh", "-c",
            "pgrep -f 'systemd-inhibit.*sleep' > /dev/null && echo 1 || echo 0"]
        stdout: SplitParser {
            onRead: data => {
                settingsDrop.idleInhibit = data.trim() === "1"
                settingsDrop._idleBusy   = false
            }
        }
    }

    Process {
        id: idleEnable
        running: false
        command: ["sh", "-c",
            "systemd-inhibit --what=idle --who=Quickshell --why='Idle inhibit' sleep infinity &"]
        onExited: idleCheck.running = true
    }

    Process {
        id: idleDisable
        running: false
        command: ["sh", "-c", "pkill -f 'systemd-inhibit.*sleep'"]
        onExited: idleCheck.running = true
    }

    function toggleIdleInhibit() {
        if (settingsDrop._idleBusy) return
        settingsDrop._idleBusy = true
        if (settingsDrop.idleInhibit) {
            idleDisable.running = true
        } else {
            idleEnable.running = true
        }
    }

    // ═══════════════════════════════════════════════════════
    // BLUETOOTH POWER — delegated to BluetoothState
    // ═══════════════════════════════════════════════════════

    function toggleBluetooth() {
        if (settingsDrop.btData) settingsDrop.btData.togglePower()
    }

    // ═══════════════════════════════════════════════════════
    // TOGGLE ROWS
    // x matches PowerProfileDropdown / VlanDropdown conventions.
    // ═══════════════════════════════════════════════════════
    Column {
        x: 16 + 14
        y: 16 + settingsDrop.headerHeight + settingsDrop._padTop
        width: settingsDrop.panelWidth - 28
        spacing: settingsDrop._gap

        SettingsToggleRow {
            width:       parent.width
            cardIcon:    "󱠃"
            label:       "Night Light"
            subtitle:    "Warm colour temperature"
            checked:     settingsDrop.nightLight
            isBusy:      settingsDrop._nightLightBusy
            accentColor: settingsDrop.accentColor
            textColor:   settingsDrop.textColor
            dimColor:    settingsDrop.dimColor
            onToggled:   settingsDrop.toggleNightLight()
        }

        SettingsToggleRow {
            width:       parent.width
            cardIcon:    "󰂛"
            label:       "Do Not Disturb"
            subtitle:    "Pause notifications"
            checked:     settingsDrop.dnd
            isBusy:      settingsDrop._dndBusy
            accentColor: settingsDrop.accentColor
            textColor:   settingsDrop.textColor
            dimColor:    settingsDrop.dimColor
            onToggled:   settingsDrop.toggleDnd()
        }

        SettingsToggleRow {
            width:       parent.width
            cardIcon:    "󰝥"
            label:       "Animations"
            subtitle:    "Hyprland motion effects"
            checked:     settingsDrop.animations
            accentColor: settingsDrop.accentColor
            textColor:   settingsDrop.textColor
            dimColor:    settingsDrop.dimColor
            onToggled:   settingsDrop.toggleAnimations()
        }

        SettingsToggleRow {
            width:       parent.width
            cardIcon:    "󰻑"
            label:       "Blur"
            subtitle:    "Compositor blur effect"
            checked:     settingsDrop.blur
            accentColor: settingsDrop.accentColor
            textColor:   settingsDrop.textColor
            dimColor:    settingsDrop.dimColor
            onToggled:   settingsDrop.toggleBlur()
        }

        SettingsToggleRow {
            width:       parent.width
            cardIcon:    "󰤄"
            label:       "Idle Inhibit"
            subtitle:    "Prevent screen sleep"
            checked:     settingsDrop.idleInhibit
            isBusy:      settingsDrop._idleBusy
            accentColor: settingsDrop.accentColor
            textColor:   settingsDrop.textColor
            dimColor:    settingsDrop.dimColor
            onToggled:   settingsDrop.toggleIdleInhibit()
        }

        SettingsToggleRow {
            width:       parent.width
            cardIcon:    "󰂯"
            label:       "Bluetooth"
            subtitle:    "Adapter power"
            checked:     settingsDrop.btPowered
            accentColor: settingsDrop.accentColor
            textColor:   settingsDrop.textColor
            dimColor:    settingsDrop.dimColor
            onToggled:   settingsDrop.toggleBluetooth()
        }

        SettingsToggleRow {
            width:       parent.width
            cardIcon:    "󰀻"
            label:       "Floating Launcher"
            subtitle:    "Use popup instead of dropdown"
            checked:     settingsDrop.launcherFloating
            accentColor: settingsDrop.accentColor
            textColor:   settingsDrop.textColor
            dimColor:    settingsDrop.dimColor
            onToggled:   settingsDrop.launcherFloating = !settingsDrop.launcherFloating
        }
    }
}
