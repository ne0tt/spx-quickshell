import Quickshell
import Quickshell.Io
import QtQuick

// ============================================================
// SETTINGS DROPDOWN — quick system toggles accessible from the bar.
//
// Toggles provided:
//   • Night Light    — wlsunset warm colour temperature
//   • Animations     — Hyprland motion effects  (hyprctl keyword)
//   • Blur           — compositor blur          (hyprctl keyword)
//
// Night Light defaults (wlsunset): -l 50 -L 14 -t 3500 -T 6500
//   Adjust latitude (-l) and longitude (-L) to your location.
// ============================================================
DropdownBase {
    id: settingsDrop
    reloadableId: "settingsDropdown"

    // Row geometry — bump _rowCount when adding/removing toggle rows.
    // panelFullHeight is derived so implicitHeight stays correct automatically.
    readonly property int _rowCount:  5
    readonly property int _rowH:      48   // SettingsToggleRow height
    readonly property int _gap:       8    // Column spacing
    readonly property int _padTop:    8    // top padding inside content area
    readonly property int _padBottom: 12   // gap between last row and footer

    panelFullHeight: _padTop + _rowCount * _rowH + _rowCount * _gap
                   + 48 + (_monExpanded ? Quickshell.screens.length * 36 : 0)
                   + _padBottom
    implicitHeight:  panelFullHeight + headerHeight + 52   // 16 ears + footerHeight + buffer
    panelWidth:      310
    panelTitle:      "Quick Settings"
    panelIcon:       "󰒓"
    headerHeight:    34

    // ── Queryable toggle states ───────────────────────────────
    property bool nightLight:  false   // reflected from pgrep on open

    // Shared bluetooth state (AppState singleton)
    readonly property bool btPowered: AppState.btPowered

    // Non-queryable states — persisted to settings.json between restarts.
    property bool animations:       true
    property bool blur:             true
    // false = dropdown launcher centred in bar; true = floating rofi-style launcher
    property bool launcherFloating: false

    // Busy guards — prevent double-clicks during command execution
    property bool _nightLightBusy: false

    // Bar monitor list expand/collapse state
    property bool _monExpanded: false

    // ── State persistence ─────────────────────────────────
    // File: <quickshell config dir>/settings.json
    // Only animations / blur / launcherFloating are saved;
    // the other toggles are read from the system on every open.
    readonly property url    _stateUrl:  Qt.resolvedUrl("../settings.json")
    readonly property string _statePath: _stateUrl.toString().replace("file://", "")
    property bool _loaded: false  // guard: don't save during initial load

    // Load state on startup
    Component.onCompleted: _loadProc.running = true

    // Save whenever a persistent value changes (after initial load)
    onAnimationsChanged:       { if (_loaded) _save() }
    onBlurChanged:             { if (_loaded) _save() }
    onLauncherFloatingChanged: { if (_loaded) _save() }

    // Save whenever the bar monitor is changed from the cycle picker
    Connections {
        target: config
        function onBarMonitorChanged() { if (settingsDrop._loaded) settingsDrop._save() }
    }

    // Read the JSON file; apply values, then apply hyprctl for non-default states
    Process {
        id: _loadProc
        running: false
        command: ["cat", settingsDrop._statePath]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var s = JSON.parse(data)
                    if (s.animations       !== undefined) settingsDrop.animations       = s.animations
                    if (s.blur             !== undefined) settingsDrop.blur             = s.blur
                    if (s.launcherFloating !== undefined) settingsDrop.launcherFloating = s.launcherFloating
                    if (s.barMonitor       !== undefined) config.barMonitor             = s.barMonitor
                } catch (e) {}
                // Re-apply hyprctl for any non-default state that survived a reload
                if (!settingsDrop.animations) { animationsProc.target = false; animationsProc.running = true }
                if (!settingsDrop.blur)       { blurProc.target = false;       blurProc.running = true }
            }
        }
        // Always save after load: creates the file on first run and writes back on reload.
        onExited: (code, status) => {
            settingsDrop._loaded = true
            _save()
        }
    }

    // Write compact JSON imperatively — JSON is computed fresh inside _save()
    // and stored in jsonToWrite so there are no binding-evaluation timing issues.
    property bool   _pendingSave: false
    property string _latestJson:  ""

    function _save() {
        // Compute eagerly right now — avoids stale-binding "one step behind" bug
        var json = JSON.stringify({
            animations:       settingsDrop.animations,
            blur:             settingsDrop.blur,
            launcherFloating: settingsDrop.launcherFloating,
            barMonitor:       config.barMonitor
        })
        if (_saveProc.running) {
            _pendingSave = true
            _latestJson  = json   // keep newest value for the follow-up write
        } else {
            _saveProc.jsonToWrite = json
            _saveProc.running = true
        }
    }

    Process {
        id: _saveProc
        running: false
        property string jsonToWrite: ""
        command: ["python3", "-c",
            "import sys; open(sys.argv[1],'w').write(sys.argv[2])",
            settingsDrop._statePath,
            jsonToWrite]
        onExited: {
            if (settingsDrop._pendingSave) {
                settingsDrop._pendingSave = false
                _saveProc.jsonToWrite = settingsDrop._latestJson
                _saveProc.running = true
            }
        }
    }

    // Refresh queryable states whenever the panel opens
    onAboutToOpen: {
        nightLightCheck.running = true
        AppState._btCheckProc.running = true
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
    // BLUETOOTH POWER — delegated to AppState
    // ═══════════════════════════════════════════════════════

    function toggleBluetooth() { AppState.togglePower() }

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

        // ── Bar Monitor selector ─────────────────────────────────
        Item {
            id: _monCard
            width:  parent.width
            height: settingsDrop._monExpanded
                    ? 48 + Quickshell.screens.length * 36
                    : 48
            clip: true
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            // Background — height tracks outer Item so rounded corners are always visible
            Rectangle {
                width:  parent.width
                height: parent.height
                radius: 10
                color:        Qt.rgba(0, 0, 0, 0.18)
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
            }

            // ── Header row (click to expand/collapse) ─────────────
            Item {
                width: parent.width; height: 48

                Rectangle {
                    id: _monIconCircle
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    width: 32; height: 32; radius: 16
                    color:        Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text:           "󰍹"
                        font.family:    config.fontFamily
                        font.styleName: "Solid"
                        font.pixelSize: 15
                        color:          settingsDrop.dimColor
                    }
                }

                Column {
                    anchors {
                        left:           _monIconCircle.right; leftMargin: 10
                        right:          _monChevron.left;     rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2
                    Text {
                        text:           "Bar Monitor"
                        font.family:    config.fontFamily
                        font.pixelSize: 13
                        font.weight:    Font.DemiBold
                        color:          settingsDrop.textColor
                    }
                    Text {
                        text:           config.barMonitor
                        font.family:    config.fontFamily
                        font.pixelSize: 10
                        color:          settingsDrop.accentColor
                    }
                }

                Text {
                    id: _monChevron
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    text:        settingsDrop._monExpanded ? "󰅃" : "󰅀"
                    font.family: config.fontFamily
                    font.pixelSize: 13
                    color:       settingsDrop.dimColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        settingsDrop._monExpanded = !settingsDrop._monExpanded
                        if (settingsDrop.isOpen) settingsDrop.resizePanel()
                    }
                }
            }

            // ── Divider ───────────────────────────────────────────
            Rectangle {
                x: 12; y: 47
                width: parent.width - 24; height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
                visible: settingsDrop._monExpanded
            }

            // ── Monitor list ──────────────────────────────────────
            Column {
                y: 48; width: parent.width

                Repeater {
                    model: {
                        var arr = []
                        for (var i = 0; i < Quickshell.screens.length; i++)
                            arr.push(Quickshell.screens[i].name)
                        return arr
                    }

                    delegate: Item {
                        id: _monDelegate
                        width: parent.width; height: 36

                        readonly property string screenName: modelData
                        readonly property bool   isCurrent:  modelData === config.barMonitor
                        property bool _hov: false

                        Rectangle {
                            anchors {
                                fill:         parent
                                leftMargin:   6; rightMargin: 6
                                topMargin:    2; bottomMargin: 2
                            }
                            radius: 6
                            color: _monDelegate._hov
                                   ? Qt.rgba(1, 1, 1, 0.10)
                                   : _monDelegate.isCurrent
                                     ? Qt.rgba(settingsDrop.accentColor.r,
                                               settingsDrop.accentColor.g,
                                               settingsDrop.accentColor.b, 0.14)
                                     : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                text:        _monDelegate.screenName
                                font.family: config.fontFamily
                                font.pixelSize: 12
                                color: _monDelegate.isCurrent ? settingsDrop.accentColor : settingsDrop.textColor
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Text {
                                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                text:    "󰄬"
                                font.family: config.fontFamily
                                font.pixelSize: 12
                                color:   settingsDrop.accentColor
                                visible: _monDelegate.isCurrent
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: _monDelegate._hov = true
                            onExited:  _monDelegate._hov = false
                            onClicked: {
                                config.barMonitor         = _monDelegate.screenName
                                settingsDrop._monExpanded = false
                                if (settingsDrop.isOpen) settingsDrop.resizePanel()
                            }
                        }
                    }
                }
            }
        }
    }
}
