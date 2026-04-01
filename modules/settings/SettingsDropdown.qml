import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "../.."
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

    keyboardFocusEnabled: true

    Item {
        focus: true
        Keys.onPressed: function(event) {
            // ── Escape: exit sub-nav or close panel ──────────────
            if (event.key === Qt.Key_Escape) {
                if (settingsDrop._inSubNav) {
                    settingsDrop._inSubNav = false
                    if (settingsDrop._navFocus === 0) {
                        settingsDrop._nlExpanded = false
                        if (settingsDrop.isOpen) settingsDrop.resizePanel()
                    } else if (settingsDrop._navFocus === 7) {
                        settingsDrop._monExpanded = false
                        if (settingsDrop.isOpen) settingsDrop.resizePanel()
                    }
                } else {
                    settingsDrop.closePanel()
                }
                event.accepted = true
                return
            }

            // ── Space: toggle the switch on expandable cards ──────
            if (event.key === Qt.Key_Space) {
                if (settingsDrop._navFocus === 0) {
                    settingsDrop.toggleNightLight()
                    event.accepted = true
                    return
                }
            }

            // ── Left / Right: slider control (Night Light sub-nav) ─
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                if (settingsDrop._inSubNav && settingsDrop._navFocus === 0) {
                    var sdir = (event.key === Qt.Key_Right) ? 1 : -1
                    settingsDrop._nlSubFocus = Math.max(0, Math.min(3, settingsDrop._nlSubFocus + sdir))
                    event.accepted = true
                    return
                }
            }

            // ── Up / Down: move focus ─────────────────────────────
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                var dir = (event.key === Qt.Key_Down) ? 1 : -1
                if (settingsDrop._inSubNav) {
                    if (settingsDrop._navFocus === 0) {
                        settingsDrop._nlSubFocus = Math.max(0, Math.min(3, settingsDrop._nlSubFocus + dir))
                    } else if (settingsDrop._navFocus === 7) {
                        settingsDrop._monSubFocus = Math.max(0, Math.min(
                            Quickshell.screens.length - 1, settingsDrop._monSubFocus + dir))
                    }
                } else {
                    var next = settingsDrop._navFocus + dir
                    if (settingsDrop._navFocus < 0) next = (dir > 0) ? 0 : 8
                    settingsDrop._navFocus = Math.max(0, Math.min(8, next))
                }
                event.accepted = true
                return
            }

            // ── Enter / Return: activate ──────────────────────────
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (settingsDrop._inSubNav) {
                    if (settingsDrop._navFocus === 0) {
                        settingsDrop.setNightLightStrength(
                            ["soft","warm","hot","max"][settingsDrop._nlSubFocus])
                        settingsDrop._inSubNav = false
                        settingsDrop._nlExpanded = false
                        if (settingsDrop.isOpen) settingsDrop.resizePanel()
                    } else if (settingsDrop._navFocus === 7) {
                        var screens = []
                        for (var i = 0; i < Quickshell.screens.length; i++)
                            screens.push(Quickshell.screens[i].name)
                        var chosen = screens[settingsDrop._monSubFocus]
                        settingsDrop.closePanel()
                        config.barMonitor = chosen
                    }
                } else if (settingsDrop._navFocus >= 0) {
                    settingsDrop._activateCard(settingsDrop._navFocus)
                }
                event.accepted = true
                return
            }
        }
    }

    // Row geometry — bump _rowCount when adding/removing toggle rows.
    // Night Light and Bar Monitor cards are counted separately below.
    // panelFullHeight is derived so implicitHeight stays correct automatically.
    readonly property int _rowCount:  7    // 5 toggles + wallpaper + lockscreen
    readonly property int _rowH:      48   // SettingsToggleRow height
    readonly property int _gap:       8    // Column spacing
    readonly property int _padTop:    8    // top padding inside content area
    readonly property int _padBottom: 12   // gap between last row and footer

    panelFullHeight: _padTop + _rowCount * _rowH + (_rowCount + 1) * _gap
                   + 48 + (_nlExpanded ? 60 : 0)
                   + 48 + (_monExpanded ? Quickshell.screens.length * 36 : 0)
                   + _padBottom
    implicitHeight:  panelFullHeight + headerHeight + 52   // 16 ears + footerHeight + buffer
    panelWidth:      360
    panelTitle:      "Settings"
    panelIcon:       "󰒓"
    headerHeight:    34

    // ── Queryable toggle states ───────────────────────────────
    property bool nightLight:  false   // reflected from pgrep on open

    // Shared bluetooth state (AppState singleton)
    readonly property bool btPowered: BluetoothState.btPowered

    // Busy guards — prevent double-clicks during command execution
    property bool _nightLightBusy: false

    // Night light expand/collapse state
    property bool _nlExpanded: false

    // Bar monitor list expand/collapse state
    property bool _monExpanded: false

    // Optimistic local mirrors — flip immediately so pills animate before
    // the underlying command/config write finishes.
    property bool _nlPending:       nightLight
    property bool _animPending:     config.animations
    property bool _blurPending:     config.blur
    property bool _btPending:       BluetoothState.btPowered
    property bool _launcherPending: config.launcherFloating
    property bool _glowPending:     config.workspaceGlow

    onNightLightChanged:                   _nlPending       = nightLight
    onBtPoweredChanged:                    _btPending       = BluetoothState.btPowered
    Connections {
        target: config
        function onAnimationsChanged()     { settingsDrop._animPending     = config.animations }
        function onBlurChanged()           { settingsDrop._blurPending     = config.blur }
        function onLauncherFloatingChanged(){ settingsDrop._launcherPending = config.launcherFloating }
        function onWorkspaceGlowChanged()  { settingsDrop._glowPending     = config.workspaceGlow }
    }

    // ── Keyboard navigation state ─────────────────────────
    // _navFocus: -1 = nothing focused, 0-8 = card index
    //   0=NightLight  1=Animations  2=Blur  3=Bluetooth
    //   4=LauncherFloat  5=WorkspaceGlow  6=Wallpaper
    //   7=BarMonitor  8=LockScreen
    property int  _navFocus:    -1
    property bool _inSubNav:    false   // navigating items inside an expanded card
    property int  _nlSubFocus:  0       // 0=soft 1=warm 2=hot 3=max
    property int  _monSubFocus: 0       // index into Quickshell.screens

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
        BluetoothState._btCheckProc.running = true
        _navFocus = -1
        _inSubNav = false
    }

    // ═══════════════════════════════════════════════════════
    // NIGHT LIGHT — hyprshade
    // Shader name must match a file in ~/.config/hypr/shaders/.
    // Default: "blue-light-filter" (ships with hyprshade).
    // ═══════════════════════════════════════════════════════

    // Derive shader name from persisted strength setting.
    readonly property string _nlShader: {
        switch (config.nightLightStrength) {
            case "soft": return "blue-light-filter-25"
            case "hot":  return "blue-light-filter-75"
            case "max":  return "blue-light-filter-100"
            default:     return "blue-light-filter-50"
        }
    }

    readonly property string _nlStrengthLabel: {
        switch (config.nightLightStrength) {
            case "soft": return "Soft (25%)"
            case "hot":  return "Hot (75%)"
            case "max":  return "Max (100%)"
            default:     return "Warm (50%)"
        }
    }

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
        settingsDrop._nlPending = !settingsDrop._nlPending
        if (settingsDrop.nightLight) {
            nightLightDisable.running = true
        } else {
            nightLightEnable.running = true
        }
    }

    function setNightLightStrength(strength) {
        config.nightLightStrength = strength
        // Re-apply shader live if night light is currently on
        if (settingsDrop.nightLight) {
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
        settingsDrop._animPending = !settingsDrop._animPending
        config.animations         = settingsDrop._animPending
        animationsProc.target     = settingsDrop._animPending
        animationsProc.running    = true
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
        settingsDrop._blurPending = !settingsDrop._blurPending
        config.blur               = settingsDrop._blurPending
        blurProc.target           = settingsDrop._blurPending
        blurProc.running          = true
    }

    // ═══════════════════════════════════════════════════════
    // BLUETOOTH POWER — delegated to AppState
    // ═══════════════════════════════════════════════════════

    function toggleBluetooth() {
        settingsDrop._btPending = !settingsDrop._btPending
        BluetoothState.togglePower()
    }

    // ── Keyboard activation dispatch ──────────────────────
    function _activateCard(idx) {
        switch (idx) {
            case 0: // Night Light — expand + enter sub-nav for strength
                if (!_nlExpanded) { _nlExpanded = true; if (isOpen) resizePanel() }
                _inSubNav = true
                var nlKeys = ["soft","warm","hot","max"]
                var nlIdx = nlKeys.indexOf(config.nightLightStrength)
                _nlSubFocus = nlIdx < 0 ? 1 : nlIdx
                break
            case 1: toggleAnimations(); break
            case 2: toggleBlur(); break
            case 3: toggleBluetooth(); break
            case 4: settingsDrop._launcherPending = !settingsDrop._launcherPending; config.launcherFloating = settingsDrop._launcherPending; break
            case 5: settingsDrop._glowPending = !settingsDrop._glowPending; config.workspaceGlow = settingsDrop._glowPending; break
            case 6:
                closePanel()
                Qt.callLater(function() {
                    wpDropdown.panelX = Math.max(0, (root.screen.width / 2) - (wpDropdown.panelWidth / 2) - 16)
                    root.switchPanel(() => wpDropdown.openPanel())
                })
                break
            case 7: // Bar Monitor — expand + enter sub-nav for monitor list
                if (!_monExpanded) { _monExpanded = true; if (isOpen) resizePanel() }
                _inSubNav = true
                var mIdx = 0
                for (var i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === config.barMonitor) { mIdx = i; break }
                }
                _monSubFocus = mIdx
                break
            case 8: activateLockscreen(); break
        }
    }

    // ═══════════════════════════════════════════════════════
    // LOCKSCREEN — launch as separate process
    // ═══════════════════════════════════════════════════════

    Process {
        id: lockscreenProcess
        running: false
        command: ["quickshell", "-p", Quickshell.env("HOME") + "/dotfiles/.config/quickshell/modules/lockscreen/LockscreenService.qml"]
        
        onExited: (exitCode, exitStatus) => {
            console.log("Lockscreen process exited with code:", exitCode)
        }
    }

    function activateLockscreen() {
        console.log("Activating lockscreen from settings...")
        settingsDrop.closePanel()  // Close settings dropdown first
        Qt.callLater(function() {
            lockscreenProcess.startDetached()
        })
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

        // ── Night Light card (expandable for strength) ───────
        Item {
            id: _nlCard
            width:  parent.width
            height: settingsDrop._nlExpanded ? 48 + 60 : 48
            clip:   true
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            // Background — colour reflects on/off state like SettingsToggleRow
            Rectangle {
                width:  parent.width
                height: parent.height
                radius: 10
                color: settingsDrop._nlPending
                    ? Qt.rgba(settingsDrop.accentColor.r, settingsDrop.accentColor.g, settingsDrop.accentColor.b, 0.10)
                    : Qt.rgba(0, 0, 0, 0.18)
                border.color: settingsDrop._nlPending
                    ? Qt.rgba(settingsDrop.accentColor.r, settingsDrop.accentColor.g, settingsDrop.accentColor.b, 0.36)
                    : Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                Behavior on color        { ColorAnimation { duration: 260 } }
                Behavior on border.color { ColorAnimation { duration: 260 } }
            }

            // ── Header row ──────────────────────────────────────
            Item {
                width: parent.width; height: 48

                // Clicking the header (except the toggle pill) expands/collapses
                MouseArea {
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        settingsDrop._nlExpanded = !settingsDrop._nlExpanded
                        if (settingsDrop.isOpen) settingsDrop.resizePanel()
                    }
                }

                Rectangle {
                    id: _nlIconCircle
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    width: 32; height: 32; radius: 16
                    color: settingsDrop._nlPending
                        ? Qt.rgba(settingsDrop.accentColor.r, settingsDrop.accentColor.g, settingsDrop.accentColor.b, 0.22)
                        : Qt.rgba(1, 1, 1, 0.05)
                    border.color: settingsDrop._nlPending
                        ? Qt.rgba(settingsDrop.accentColor.r, settingsDrop.accentColor.g, settingsDrop.accentColor.b, 0.55)
                        : Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1
                    Behavior on color        { ColorAnimation { duration: 260 } }
                    Behavior on border.color { ColorAnimation { duration: 260 } }
                    Text {
                        anchors.centerIn: parent
                        text:           "󱠃"
                        font.family:    config.fontFamily
                        font.styleName: "Solid"
                        font.pixelSize: 15
                        color: settingsDrop._nlPending ? settingsDrop.accentColor : settingsDrop.dimColor
                        Behavior on color { ColorAnimation { duration: 260 } }
                    }
                }

                Column {
                    anchors {
                        left: _nlIconCircle.right; leftMargin: 10
                        right: _nlTogglePill.left; rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2
                    Text {
                        text:           "Night Light"
                        font.family:    config.fontFamily
                        font.pixelSize: 13
                        font.weight:    Font.DemiBold
                        color:          settingsDrop.textColor
                    }
                    Text {
                        text:   settingsDrop._nlStrengthLabel
                        font.family:    config.fontFamily
                        font.pixelSize: 10
                        color:  settingsDrop._nlPending ? settingsDrop.accentColor : settingsDrop.dimColor
                        Behavior on color { ColorAnimation { duration: 260 } }
                    }
                }

                // Toggle pill — inner MouseArea absorbs click, stops expand from firing
                Rectangle {
                    id: _nlTogglePill
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    width: 38; height: 20; radius: 10
                    color: settingsDrop._nlPending
                        ? Qt.rgba(settingsDrop.accentColor.r, settingsDrop.accentColor.g, settingsDrop.accentColor.b, 0.82)
                        : Qt.rgba(1, 1, 1, 0.15)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Rectangle {
                        width: 14; height: 14; radius: 7
                        anchors.verticalCenter: parent.verticalCenter
                        x: settingsDrop._nlPending ? parent.width - width - 3 : 3
                        color: settingsDrop._nlPending ? "white" : Qt.rgba(1, 1, 1, 0.55)
                        Behavior on x     { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation  { duration: 180 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        enabled:      !settingsDrop._nightLightBusy
                        onClicked:    settingsDrop.toggleNightLight()
                    }
                }

            }

            // Divider
            Rectangle {
                x: 12; y: 47
                width: parent.width - 24; height: 1
                color:   Qt.rgba(1, 1, 1, 0.08)
                visible: settingsDrop._nlExpanded
            }

            // ── Strength slider ──────────────────────────────────
            Item {
                y: 48
                width: parent.width
                height: 60

                readonly property int _snapIdx: {
                    switch (config.nightLightStrength) {
                        case "soft": return 0
                        case "hot":  return 2
                        case "max":  return 3
                        default:     return 1
                    }
                }

                Item {
                    id: _sliderArea
                    anchors {
                        left:  parent.left;  leftMargin:  24
                        right: parent.right; rightMargin: 24
                        top:   parent.top;   topMargin:   10
                    }
                    height: 34

                    // Track background
                    Rectangle {
                        id: _trackBg
                        x: 7; y: 5
                        width: parent.width - 14; height: 3; radius: 2
                        color: Colors.col_background
                    }

                    // Active fill (left side up to knob centre)
                    Rectangle {
                        x: _trackBg.x; y: _trackBg.y
                        width: _nlKnob.x + 7 - _trackBg.x
                        height: _trackBg.height; radius: _trackBg.radius
                        color: Qt.rgba(settingsDrop.accentColor.r, settingsDrop.accentColor.g, settingsDrop.accentColor.b, 0.70)
                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    // Knob
                    Rectangle {
                        id: _nlKnob
                        width: 14; height: 14; radius: 7
                        y: 0
                        x: (settingsDrop._inSubNav && settingsDrop._navFocus === 0)
                           ? settingsDrop._nlSubFocus * (_sliderArea.width - 14) / 3
                           : _sliderArea.parent._snapIdx * (_sliderArea.width - 14) / 3
                        color: settingsDrop._nlPending ? settingsDrop.accentColor : Qt.rgba(1, 1, 1, 0.75)
                        border.color: "black"
                        border.width: 1
                        Behavior on x     { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation  { duration: 260 } }
                    }

                    // Labels
                    Text {
                        anchors { left: parent.left; top: _trackBg.bottom; topMargin: 6 }
                        text: "Soft"; font.family: config.fontFamily; font.pixelSize: 10
                        color: config.nightLightStrength === "soft"
                            ? (settingsDrop._nlPending ? settingsDrop.accentColor : settingsDrop.textColor)
                            : (settingsDrop._inSubNav && settingsDrop._navFocus === 0 && settingsDrop._nlSubFocus === 0)
                                ? settingsDrop.textColor
                                : settingsDrop.dimColor
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        x: Math.round((_sliderArea.width - 14) / 3)
                        anchors { top: _trackBg.bottom; topMargin: 6 }
                        text: "Warm"; font.family: config.fontFamily; font.pixelSize: 10
                        color: config.nightLightStrength === "warm"
                            ? (settingsDrop._nlPending ? settingsDrop.accentColor : settingsDrop.textColor)
                            : (settingsDrop._inSubNav && settingsDrop._navFocus === 0 && settingsDrop._nlSubFocus === 1)
                                ? settingsDrop.textColor
                                : settingsDrop.dimColor
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        x: Math.round(2 * (_sliderArea.width - 14) / 3)
                        anchors { top: _trackBg.bottom; topMargin: 6 }
                        text: "Hot"; font.family: config.fontFamily; font.pixelSize: 10
                        color: config.nightLightStrength === "hot"
                            ? (settingsDrop._nlPending ? settingsDrop.accentColor : settingsDrop.textColor)
                            : (settingsDrop._inSubNav && settingsDrop._navFocus === 0 && settingsDrop._nlSubFocus === 2)
                                ? settingsDrop.textColor
                                : settingsDrop.dimColor
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        anchors { right: parent.right; top: _trackBg.bottom; topMargin: 6 }
                        text: "Max"; font.family: config.fontFamily; font.pixelSize: 10
                        color: config.nightLightStrength === "max"
                            ? (settingsDrop._nlPending ? settingsDrop.accentColor : settingsDrop.textColor)
                            : (settingsDrop._inSubNav && settingsDrop._navFocus === 0 && settingsDrop._nlSubFocus === 3)
                                ? settingsDrop.textColor
                                : settingsDrop.dimColor
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    // Click and drag
                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        function _snap(mx) {
                            var idx = Math.round((mx - 7) / ((_sliderArea.width - 14) / 3))
                            idx = Math.max(0, Math.min(3, idx))
                            settingsDrop.setNightLightStrength(["soft", "warm", "hot", "max"][idx])
                        }
                        onClicked:         (mouse) => _snap(mouse.x)
                        onPositionChanged: (mouse) => { if (pressed) _snap(mouse.x) }
                    }
                }
            }

            // ── Keyboard focus ring ──────────────────────────────
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: "transparent"
                border.color: settingsDrop._navFocus === 0
                    ? Qt.rgba(settingsDrop.accentColor.r, settingsDrop.accentColor.g, settingsDrop.accentColor.b,
                              settingsDrop._inSubNav ? 0.80 : 0.60)
                    : "transparent"
                border.width: 1.5
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }
        }

        SettingsToggleRow {
            id:          _animRow
            width:       parent.width
            cardIcon:    "󰝥"
            label:       "Animations"
            subtitle:    "Hyprland motion effects"
            checked:     settingsDrop._animPending
            accentColor: settingsDrop.accentColor
            textColor:   settingsDrop.textColor
            dimColor:    settingsDrop.dimColor
            keyFocused:  settingsDrop._navFocus === 1 && !settingsDrop._inSubNav
            onToggled:   settingsDrop.toggleAnimations()
        }

        SettingsToggleRow {
            id:          _blurRow
            width:       parent.width
            cardIcon:    "󰻑"
            label:       "Blur"
            subtitle:    "Compositor blur effect"
            checked:     settingsDrop._blurPending
            accentColor: settingsDrop.accentColor
            textColor:   settingsDrop.textColor
            dimColor:    settingsDrop.dimColor
            keyFocused:  settingsDrop._navFocus === 2 && !settingsDrop._inSubNav
            onToggled:   settingsDrop.toggleBlur()
        }

        SettingsToggleRow {
            id:          _btRow
            width:       parent.width
            cardIcon:    "󰂯"
            label:       "Bluetooth"
            subtitle:    "Adapter power"
            checked:     settingsDrop._btPending
            accentColor: settingsDrop.accentColor
            textColor:   settingsDrop.textColor
            dimColor:    settingsDrop.dimColor
            keyFocused:  settingsDrop._navFocus === 3 && !settingsDrop._inSubNav
            onToggled:   settingsDrop.toggleBluetooth()
        }

        SettingsToggleRow {
            id:          _launcherRow
            width:       parent.width
            cardIcon:    "󰀻"
            label:       "Floating Launcher"
            subtitle:    "Use popup instead of dropdown"
            checked:     settingsDrop._launcherPending
            accentColor: settingsDrop.accentColor
            textColor:   settingsDrop.textColor
            dimColor:    settingsDrop.dimColor
            keyFocused:  settingsDrop._navFocus === 4 && !settingsDrop._inSubNav
            onToggled:   { settingsDrop._launcherPending = !settingsDrop._launcherPending; config.launcherFloating = settingsDrop._launcherPending }
        }

        SettingsToggleRow {
            id:          _glowRow
            width:       parent.width
            cardIcon:    "󱃄"
            label:       "Workspace Glow"
            subtitle:    "Highlight active workspace"
            checked:     settingsDrop._glowPending
            accentColor: settingsDrop.accentColor
            textColor:   settingsDrop.textColor
            dimColor:    settingsDrop.dimColor
            keyFocused:  settingsDrop._navFocus === 5 && !settingsDrop._inSubNav
            onToggled:   { settingsDrop._glowPending = !settingsDrop._glowPending; config.workspaceGlow = settingsDrop._glowPending }
        }

        // WALLPAPER ACTION BUTTON
        Item {
            width: parent.width
            height: 48

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Qt.rgba(0, 0, 0, 0.18)
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1

                // Left icon circle
                Rectangle {
                    id: wallpaperIconCircle
                    anchors {
                        left: parent.left
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    width: 32; height: 32; radius: 16
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰸉"
                        font.family: settingsDrop.fontFamily
                        font.styleName: "Solid"
                        font.pixelSize: 15
                        color: settingsDrop.dimColor
                    }
                }

                // Label
                Column {
                    anchors {
                        left: wallpaperIconCircle.right
                        leftMargin: 10
                        right: wallpaperArrow.left
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        text: "Change Wallpaper"
                        font.family: settingsDrop.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: settingsDrop.textColor
                        elide: Text.ElideRight
                    }

                    Text {
                        text: "Open wallpaper picker"
                        font.family: settingsDrop.fontFamily
                        font.pixelSize: 10
                        color: settingsDrop.dimColor
                        elide: Text.ElideRight
                    }
                }

                // Right arrow
                Text {
                    id: wallpaperArrow
                    anchors {
                        right: parent.right
                        rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: "󰅂"
                    font.family: settingsDrop.fontFamily
                    font.styleName: "Solid"
                    font.pixelSize: 12
                    color: settingsDrop.dimColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // Close settings dropdown and open wallpaper dropdown
                        settingsDrop.closePanel()
                        Qt.callLater(function() {
                            wpDropdown.panelX = Math.max(0, (root.screen.width / 2) - (wpDropdown.panelWidth / 2) - 16)
                            root.switchPanel(() => wpDropdown.openPanel())
                        })
                    }
                }

                // Keyboard focus ring
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "transparent"
                    border.color: settingsDrop._navFocus === 6
                        ? Qt.rgba(settingsDrop.accentColor.r, settingsDrop.accentColor.g, settingsDrop.accentColor.b, 0.60)
                        : "transparent"
                    border.width: 1.5
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }
            }
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
                                   : (settingsDrop._inSubNav && settingsDrop._navFocus === 7 && index === settingsDrop._monSubFocus)
                                     ? Qt.rgba(1, 1, 1, 0.16)
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
                                settingsDrop.closePanel()
                                config.barMonitor = _monDelegate.screenName
                            }
                        }
                    }
                }
            }

            // ── Keyboard focus ring ──────────────────────────────
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: "transparent"
                border.color: settingsDrop._navFocus === 7
                    ? Qt.rgba(settingsDrop.accentColor.r, settingsDrop.accentColor.g, settingsDrop.accentColor.b,
                              settingsDrop._inSubNav ? 0.80 : 0.60)
                    : "transparent"
                border.width: 1.5
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }
        }

        // LOCKSCREEN ACTION BUTTON
        Item {
            width: parent.width
            height: 48

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Qt.rgba(0, 0, 0, 0.18)
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1

                // Left icon circle
                Rectangle {
                    id: lockscreenIconCircle
                    anchors {
                        left: parent.left
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    width: 32; height: 32; radius: 16
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰌾"
                        font.family: settingsDrop.fontFamily
                        font.styleName: "Solid"
                        font.pixelSize: 15
                        color: settingsDrop.dimColor
                    }
                }

                // Label
                Column {
                    anchors {
                        left: lockscreenIconCircle.right
                        leftMargin: 10
                        right: lockscreenArrow.left
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        text: "Lock Screen"
                        font.family: settingsDrop.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: settingsDrop.textColor
                        elide: Text.ElideRight
                    }

                    Text {
                        text: "Lock the display immediately"
                        font.family: settingsDrop.fontFamily
                        font.pixelSize: 10
                        color: settingsDrop.dimColor
                        elide: Text.ElideRight
                    }
                }

                // Right arrow
                Text {
                    id: lockscreenArrow
                    anchors {
                        right: parent.right
                        rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: "󰅂"
                    font.family: settingsDrop.fontFamily
                    font.styleName: "Solid"
                    font.pixelSize: 12
                    color: settingsDrop.dimColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: settingsDrop.activateLockscreen()
                }

                // Keyboard focus ring
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "transparent"
                    border.color: settingsDrop._navFocus === 8
                        ? Qt.rgba(settingsDrop.accentColor.r, settingsDrop.accentColor.g, settingsDrop.accentColor.b, 0.60)
                        : "transparent"
                    border.width: 1.5
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }
            }
        }

    }
}
