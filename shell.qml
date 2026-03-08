//@ pragma UseQApplication

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland

import QtQuick
import QtQuick.Effects

import qs.state
import qs.base
import qs.modules.appLauncher
import qs.modules.bluetooth
import qs.modules.calendar
import qs.modules.clock
import qs.modules.network
import qs.modules.power
import qs.modules.settings
import qs.modules.systemTray
import qs.modules.vpn
import qs.modules.volume
import qs.modules.wallpaper
import qs.modules.weather
import qs.modules.workspaces
import qs.modules.yayUpdate
import qs.modules.rightPanelSlider
//import qs.modules.chat
//import "."

ShellRoot {

    // ============================================================
    // CONFIG — THEME COLORS (written by matugen on wallpaper change)
    // ============================================================
    Colors {
        id: colors
    }

    // ============================================================
    // CONFIG — SHELL-WIDE SETTINGS (font family, etc.)
    // ============================================================
    Config {
        id: config
    }

    // ============================================================
    // KEYBINDS — GLOBAL KEYBOARD SHORTCUTS
    // Register in hyprland.conf:
    //   bind = , escape,       global, quickshell:closeAllDropdowns
    //   bind = SUPER CTRL, W,  global, quickshell:toggleWallpaperDropdown
    //   bind = SUPER, Space,   global, quickshell:toggleAppLauncher
    //   bind = SUPER, R,       global, quickshell:toggleRightPanel
    // ============================================================
    GlobalShortcut {
        name: "toggleRightPanel"
        description: "Open/close the right panel slider"
        onPressed: {
            if (rightPanel.isOpen) {
                rightPanel.closePanel()
            } else {
                rightPanel.openPanel()
            }
        }
    }

    GlobalShortcut {
        name: "closeAllDropdowns"
        description: "Close any open dropdown or panel"
        onPressed: root.closeAllDropdowns()
    }

    GlobalShortcut {
        name: "toggleWallpaperDropdown"
        description: "Open/close the wallpaper picker"
        onPressed: {
            var pos = wallpaperButton.mapToItem(null, 0, 0);
            wpDropdown.panelX = pos.x + wallpaperButton.width / 2 - wpDropdown.panelWidth / 2 - 16 + 250;
            if (wpDropdown.isOpen) {
                wpDropdown.closePanel();
            } else {
                root.switchPanel(() => wpDropdown.openPanel());
            }
        }
    }

    GlobalShortcut {
        name: "toggleAppLauncher"
        description: "Open/close the app launcher"
        onPressed: {
            if (settingsDropdown.launcherFloating) {
                if (appLauncher.isOpen) {
                    appLauncher.closeLauncher();
                } else {
                    appLauncher.screen = root.focusedScreen;
                    root.switchPanel(() => appLauncher.openLauncher());
                }
            } else {
                if (appLaunchDropdown.isOpen) {
                    appLaunchDropdown.closePanel();
                } else {
                    appLaunchDropdown.panelX = Math.max(0, (root.screen.width / 2) - (appLaunchDropdown.panelWidth / 2) - 16);
                    root.switchPanel(() => appLaunchDropdown.openPanel());
                }
            }
        }
    }

    // ============================================================
    // LIFECYCLE
    // ============================================================
    Component.onCompleted: Quickshell.inhibitReloadPopup()

    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup();
        }
    }

    // Close all dropdowns when the active workspace changes
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            root.closeAllDropdowns();
        }
    }

    // ============================================================
    // TOP PANEL WINDOW
    // ============================================================
    PanelWindow {
        id: root
        reloadableId: "mainBar"
        screen: Quickshell.screens.find(s => s.name === config.barMonitor) ?? Quickshell.screens[0]

        anchors.top: true
        anchors.left: true
        anchors.right: true

        implicitHeight: 70
        exclusiveZone: 50
        color: "transparent"

        // --------------------------------------------------------
        // GLOBAL PROPERTIES
        // --------------------------------------------------------

        property string fontFamily: config.fontFamily
        property int fontSize: config.fontSize
        property int fontWeight: config.fontWeight

        // Semi-transparent primary colour used for dim/inactive states
        readonly property color dimPrimary: Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.4)

        // Cached focused screen lookup (avoids repeated array searches)
        readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? root.screen

        // State for sequenced panel switching (used by switchPanel)
        property var pendingOpen: null

        // Single source of truth for all panels that use closePanel()
        // appLauncher is excluded here because it uses closeLauncher() instead
        readonly property var dropdowns: [calendarPanel, volumeDropdown, vlanDropdown, powerProfileDropdown, networkDropdown, vpnDropdown, bluetoothDropdown, wpDropdown, weatherDropdown, settingsDropdown, appLaunchDropdown, trayMenu]

        // Close every open dropdown/drawer in one call
        function closeAllDropdowns() {
            for (const p of dropdowns) {
                if (p.isOpen)
                    p.closePanel();
            }
            if (appLauncher.isOpen)
                appLauncher.closeLauncher();
        }

        // Returns true if any panel/dropdown is currently open
        function isAnyPanelOpen() {
            return dropdowns.some(p => p.isOpen) || appLauncher.isOpen;
        }

        // Close all open panels, then open the requested one after animation
        Timer {
            id: openAfterClose
            interval: 300   // just after the 220 ms close animation
            repeat: false
            onTriggered: {
                if (root.pendingOpen) {
                    root.pendingOpen();
                    root.pendingOpen = null;
                }
            }
        }
        function switchPanel(openFn) {
            const anyOpen = root.isAnyPanelOpen();
            root.closeAllDropdowns();
            if (anyOpen) {
                root.pendingOpen = openFn;
                openAfterClose.restart();
            } else {
                openFn();
            }
        }

        // ========================================================
        // BAR GLOW — colored outer glow, same shape as bar,
        // mimics Hyprland's window outer shadow/glow.
        // Must be a sibling of the container, NOT inside it,
        // so the blur can expand freely past the margins.
        // ========================================================
        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 16
                leftMargin: 12
                rightMargin: 12
            }
            height: 38
            radius: 12
            color: "#000000"

            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.8
                blurMax: 32
                brightness: 0.05
            }
        }

        // ========================================================
        // BAR CONTAINER (POSITIONING + MARGINS)
        // ========================================================
        Item {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 18
                leftMargin: 15
                rightMargin: 15
            }
            height: 32

            // ====================================================
            // MAIN BAR BACKGROUND
            // ====================================================
            Rectangle {
                id: mainBar
                anchors.fill: parent
                radius: 10
                // Qt.rgba keeps children fully opaque — unlike `opacity` which cascades
                color: colors.col_main
                opacity: 1

                // Close any open dropdown when the bare bar is clicked
                MouseArea {
                    anchors.fill: parent
                    z: 0
                    propagateComposedEvents: true
                    onClicked: mouse => {
                        mouse.accepted = false;   // let button clicks through
                        root.closeAllDropdowns();
                    }
                }

                // ##################################################
                // LEFT SECTION
                // ##################################################
                Row {
                    id: leftRow
                    anchors {
                        left: parent.left
                        leftMargin: 4
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 10

                    // ---------------- App Launcher Button ----------------
                    Rectangle {
                        id: launcherButton
                        width: 75
                        height: 24
                        radius: 7
                        color: colors.col_background
                        border.color: "black"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 0
                            text: ""
                            font.family: root.fontFamily
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: appLaunchDropdown.isOpen || appLauncher.isOpen || launcherBtnArea.containsMouse ? colors.col_source_color : colors.col_primary
                            Behavior on color {
                                ColorAnimation {
                                    duration: 160
                                }
                            }
                        }

                        MouseArea {
                            id: launcherBtnArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                if (settingsDropdown.launcherFloating) {
                                    if (appLauncher.isOpen) {
                                        appLauncher.closeLauncher();
                                    } else {
                                        root.closeAllDropdowns();
                                        appLauncher.screen = root.focusedScreen;
                                        appLauncher.openLauncher();
                                    }
                                } else {
                                    if (appLaunchDropdown.isOpen) {
                                        appLaunchDropdown.closePanel();
                                    } else {
                                        appLaunchDropdown.panelX = Math.max(0, (root.screen.width / 2) - (appLaunchDropdown.panelWidth / 2) - 16);
                                        root.switchPanel(() => appLaunchDropdown.openPanel());
                                    }
                                }
                            }
                        }
                    }

                    // ---------------- Wallpaper Button ----------------
                    WallpaperButton {
                        id: wallpaperButton
                        anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 1
                        isActive: wpDropdown.isOpen
                        onClicked: function (clickX) {
                            wpDropdown.panelX = clickX - wpDropdown.panelWidth / 2 - 16 + 250;
                            if (wpDropdown.isOpen) {
                                wpDropdown.closePanel();
                            } else {
                                root.switchPanel(() => wpDropdown.openPanel());
                            }
                        }
                    }

                    YayUpdateButton {
                        fontSize: 15
                    }
                }

                // CENTER SECTION – WORKSPACES
                WorkspacesPanel {
                    id: workspaceContainer
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 1
                    monitorName: config.barMonitor
                }

                // ##################################################
                // RIGHT SECTION
                // ##################################################
                Row {
                    id: rightRow
                    anchors {
                        right: parent.right
                        rightMargin: 4
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 10

                    // VLAN BUTTON — opens / closes VlanDropdown
                    VlanButton {
                        id: vlanButton
                        isActive: vlanDropdown.isOpen
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 1
                        onClicked: function (clickX) {
                            vlanDropdown.panelX = Math.max(0, clickX - vlanDropdown.panelWidth / 2 - 16);
                            if (vlanDropdown.isOpen) {
                                vlanDropdown.closePanel();
                            } else {
                                root.switchPanel(() => vlanDropdown.openPanel());
                            }
                        }
                    }

                    // ETHERNET IP
                    NetworkButton {
                        id: networkButton
                        ip: networkDropdown.infoIp
                        isActive: networkDropdown.isOpen
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 0
                        onClicked: function (clickX) {
                            networkDropdown.panelX = Math.max(0, clickX - networkDropdown.panelWidth / 2 - 16);
                            if (networkDropdown.isOpen) {
                                networkDropdown.closePanel();
                            } else {
                                root.switchPanel(() => networkDropdown.openPanel());
                            }
                        }
                    }

                    // VPN MODULE
                    VPNModule {
                        id: vpnModuleWidget
                        isActive: vpnDropdown.isOpen
                        onClicked: function (clickX) {
                            vpnDropdown.panelX = Math.max(0, clickX - vpnDropdown.panelWidth / 2 - 16);
                            if (vpnDropdown.isOpen) {
                                vpnDropdown.closePanel();
                            } else {
                                root.switchPanel(() => vpnDropdown.openPanel());
                            }
                        }
                    }

                    // SYSTEM INFO GROUP
                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 0
                        height: parent.height

                        // BLUETOOTH TOGGLE
                        BluetoothButton {
                            id: btButton
                            btPowered: AppState.btPowered
                            isActive: bluetoothDropdown.isOpen
                            onClicked: function (clickX) {
                                bluetoothDropdown.panelX = Math.max(0, clickX - bluetoothDropdown.panelWidth / 2 - 16);
                                if (bluetoothDropdown.isOpen) {
                                    bluetoothDropdown.closePanel();
                                } else {
                                    root.switchPanel(() => bluetoothDropdown.openPanel());
                                }
                            }
                        }

                        VolumeButton {
                            id: volumeWidget
                            isActive: volumeDropdown.isOpen
                            onClicked: function (clickX) {
                                volumeDropdown.panelX = clickX - volumeDropdown.panelWidth / 2 - 16;
                                if (volumeDropdown.isOpen) {
                                    volumeDropdown.closePanel();
                                } else {
                                    root.switchPanel(() => volumeDropdown.openPanel());
                                }
                            }
                        }

                        PowerProfileButton {
                            id: powerProfileWidget
                            isActive: powerProfileDropdown.isOpen
                            onClicked: function (clickX) {
                                powerProfileDropdown.panelX = Math.max(0, clickX - powerProfileDropdown.panelWidth / 2 - 16);
                                if (powerProfileDropdown.isOpen) {
                                    powerProfileDropdown.closePanel();
                                } else {
                                    root.switchPanel(() => powerProfileDropdown.openPanel());
                                }
                            }
                        }

                        TemperatureButton {
                        }

                        // WEATHER
                        WeatherButton {
                            id: weatherWidget
                            isActive: weatherDropdown.isOpen
                            onClicked: function (clickX) {
                                weatherDropdown.panelX = Math.max(0, clickX - weatherDropdown.panelWidth / 2 - 16);
                                if (weatherDropdown.isOpen) {
                                    weatherDropdown.closePanel();
                                } else {
                                    root.switchPanel(() => weatherDropdown.openPanel());
                                }
                            }
                        }
                    }

                    // SETTINGS BUTTON
                    SettingsButton {
                        id: settingsButton
                        isActive: settingsDropdown.isOpen
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 0
                        onClicked: function (clickX) {
                            settingsDropdown.panelX = Math.max(0, clickX - settingsDropdown.panelWidth / 2 - 16);
                            if (settingsDropdown.isOpen) {
                                settingsDropdown.closePanel();
                            } else {
                                root.switchPanel(() => settingsDropdown.openPanel());
                            }
                        }
                    }

                    // SYSTEM TRAY (Solaar, Remmina, etc.)
                    SystemTrayPanel {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 0
                        menuWindow: trayMenu
                    }                    

                    RightPanelButton {
                        id: rightPanelBtn
                        isActive: rightPanel.isOpen
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            if (rightPanel.isOpen) {
                                rightPanel.closePanel()
                            } else {
                                root.closeAllDropdowns()
                                rightPanel.openPanel()
                            }
                        }
                    }

                    ClockPanel {
                        id: clockWidget
                        fontSize: 13
                        fontBold: true
                        textColor: calendarPanel.isOpen ? colors.col_source_color : colors.col_primary
                        borderColor: "black"
                        onClicked: function (clickX, clickY) {
                            // Right-align the calendar under the clock's right edge
                            calendarPanel.panelX = clickX + clockWidget.width - calendarPanel.panelWidth - 32;
                            if (calendarPanel.isOpen) {
                                calendarPanel.closePanel();
                            } else {
                                root.switchPanel(() => calendarPanel.openPanel());
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Dropdown scrim ────────────────────────────────────────────
    // Full-screen transparent catch-all on WlrLayer.Overlay.
    // Declared BEFORE all dropdown PanelWindows so the compositor
    // stacks it below them while still intercepting out-of-panel clicks.
    // The mask shrinks to 0×0 when nothing is open, so it is fully
    // click-through at rest and never eats normal desktop input.
    PanelWindow {
        id: _dropdownScrim
        reloadableId: "dropdownScrim"
        screen: root.screen
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: screen ? screen.height : 1080
        exclusiveZone: 0
        color: "transparent"

        // Reactive: becomes true the moment any dropdown opens.
        // QML resolves the IDs lazily, so forward refs (calendarPanel etc.) are fine.
        readonly property bool anyOpen: (typeof calendarPanel !== "undefined" && calendarPanel.isOpen) || (typeof volumeDropdown !== "undefined" && volumeDropdown.isOpen) || (typeof vlanDropdown !== "undefined" && vlanDropdown.isOpen) || (typeof powerProfileDropdown !== "undefined" && powerProfileDropdown.isOpen) || (typeof networkDropdown !== "undefined" && networkDropdown.isOpen) || (typeof vpnDropdown !== "undefined" && vpnDropdown.isOpen) || (typeof bluetoothDropdown !== "undefined" && bluetoothDropdown.isOpen) || (typeof wpDropdown !== "undefined" && wpDropdown.isOpen) || (typeof weatherDropdown !== "undefined" && weatherDropdown.isOpen) || (typeof settingsDropdown !== "undefined" && settingsDropdown.isOpen) || (typeof appLaunchDropdown !== "undefined" && appLaunchDropdown.isOpen) || (typeof appLauncher !== "undefined" && appLauncher.isOpen)

        mask: Region {
            item: _scrimMask
        }
        Item {
            id: _scrimMask
            x: 0; y: 0
            // Always 0×0 — keeps the scrim permanently click-through at the Wayland
            // input-region level so it never intercepts events destined for dropdowns.
            // Click-outside-to-close is handled elsewhere when re-enabled.
            width: 0
            height: 0
        }

        MouseArea {
            anchors.fill: parent
            enabled: false   // click-outside-to-close disabled
            onClicked: root.closeAllDropdowns()
        }
    }

    // CalendarPanel — drops down from the clock
    CalendarPanel {
        id: calendarPanel
        screen: root.screen
    }

    // VolumeDropdown — drops down from the volume button
    VolumeDropdown {
        id: volumeDropdown
        screen: root.screen
    }

    // VlanDropdown — drops down from the VLAN panel
    VlanDropdown {
        id: vlanDropdown
        screen: root.screen
    }

    // PowerProfileDropdown — drops down from the power profile icon
    PowerProfileDropdown {
        id: powerProfileDropdown
        screen: root.screen
        currentProfile: powerProfileWidget.currentProfile
    }

    // NetworkDropdown — drops down from the Ethernet IP pill
    NetworkDropdown {
        id: networkDropdown
        screen: root.screen
    }

    // VPNDropdown — drops down from the VPN module pill
    VPNDropdown {
        id: vpnDropdown
        screen: root.screen
    }

    // BluetoothDropdown — drops down from the bluetooth icon
    BluetoothDropdown {
        id: bluetoothDropdown
        screen: root.screen
    }

    // WallpaperDropdown — drops down from the wallpaper button
    WallpaperDropdown {
        id: wpDropdown
        screen: root.screen
    }

    // WeatherDropdown — drops down from the weather pill
    WeatherDropdown {
        id: weatherDropdown
        screen: root.screen
    }

    // SettingsDropdown — drops down from the settings gear icon
    SettingsDropdown {
        id: settingsDropdown
        screen: root.screen
    }

    // AppLauncher — centred rofi-style launcher (Super+Space or launcher button)
    AppLauncher {
        id: appLauncher
        screen: root.screen
    }

    // AppLaunchDropdown — centred under the workspace switcher
    AppLaunchDropdown {
        id: appLaunchDropdown
        screen: root.screen
    }

    // TrayMenu — custom themed context menu for system tray icons
    TrayMenu {
        id: trayMenu
        screen: root.screen
        // Close all other open dropdowns whenever the tray context menu opens
        onAboutToOpen: root.closeAllDropdowns()
    }

    // RightPanelSlider — slides in from the right edge
    RightPanelSlider {
        id: rightPanel
        screen: root.screen
    }

    // WorkspaceGlowOverlay — declared last so it renders above all other surfaces.

    WorkspaceGlowOverlay {
        screen: root.screen
        monitorName: config.barMonitor
        //visible: appLaunchDropdown.isOpen
    }

}
