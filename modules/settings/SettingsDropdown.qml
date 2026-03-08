import Quickshell
import Quickshell.Io
import QtQuick
import "../../base"
import "../../state"

// ============================================================
// SETTINGS DROPDOWN — quick system toggles accessible from the bar.
//
// Toggles provided:
//   • Night Light    — hyprshade shader toggle
//   • Animations     — Hyprland motion effects  (hyprctl keyword)
//   • Blur           — compositor blur          (hyprctl keyword)
//
// Night Light: toggles hyprshade on/off using the shader set in _nlShader.
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

    // Busy guards — prevent double-clicks during command execution
    property bool _nightLightBusy: false

    // Bar monitor list expand/collapse state
    property bool _monExpanded: false

    // Apply Hyprland settings for any non-default value once Config finishes
    // loading from disk. Component.onCompleted handles the hot-reload case
    // (Config already loaded); Connections handles cold start (Config loads
    // after this component is instantiated).
    Component.onCompleted: {
        if (config._loaded) {
            if (!config.animations) { animationsProc.target = false; animationsProc.running = true }
            if (!config.blur)       { blurProc.target = false;       blurProc.running = true }
        }
    }
    Connections {
        target: config
        function on_LoadedChanged() {
            if (!config._loaded) return
            if (!config.animations) { animationsProc.target = false; animationsProc.running = true }
            if (!config.blur)       { blurProc.target = false;       blurProc.running = true }
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
        config.animations      = !config.animations
        animationsProc.target  = config.animations
        animationsProc.running = true
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
        config.blur          = !config.blur
        blurProc.target      = config.blur
        blurProc.running     = true
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
            checked:     config.animations
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
            checked:     config.blur
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
            checked:     config.launcherFloating
            accentColor: settingsDrop.accentColor
            textColor:   settingsDrop.textColor
            dimColor:    settingsDrop.dimColor
            onToggled:   config.launcherFloating = !config.launcherFloating
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
