//@ pragma UseQApplication
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

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
import qs.modules.lockscreen
import qs.modules.power
import qs.modules.settings
import qs.modules.systemTray
import qs.modules.vpn
import qs.modules.volume
import qs.modules.wallpaper
import qs.modules.workspaces
import qs.modules.systemUpdates
import qs.modules.notifications
import qs.modules.dashboard

ShellRoot {

    // ============================================================
    // CONFIG — SHELL-WIDE SETTINGS (font family, etc.)
    // ============================================================
    Config {
        id: config
    }

    // ============================================================
    // UTILITY — NUMBER TO WORDS CONVERTER
    // ============================================================
    NumbersToText {
        id: numbersToText
    }

    // ============================================================
    // KEYBINDS — GLOBAL KEYBOARD SHORTCUTS
    // Register in hyprland.conf:
    //   bind = , escape,       global, quickshell:closeAllDropdowns
    //   bind = SUPER CTRL, W,  global, quickshell:toggleWallpaperDropdown
    //   bind = SUPER, Space,   global, quickshell:toggleAppLauncher
    //   bind = SUPER, L,       global, quickshell:lockScreen
    //   bind = SUPER CTRL, S,  global, quickshell:toggleSettingsDropdown
    //   bind = SUPER CTRL, V,  global, quickshell:toggleVolumeDropdown
    //   bind = SUPER CTRL, N,  global, quickshell:toggleNotifDropdown
    //   bind = SUPER CTRL, D,  global, quickshell:toggleDashboardDropdown
    // ============================================================

    GlobalShortcut {
        name: "closeAllDropdowns"
        description: "Close any open dropdown or panel"
        onPressed: root.closeAllDropdowns()
    }

    GlobalShortcut {
        name: "toggleWallpaperDropdown"
        description: "Open/close the wallpaper picker"
        onPressed: {
            wpDropdown.panelX = Math.max(0, (root.screen.width / 2) - (wpDropdown.panelWidth / 2) - 16);
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
            if (config.launcherFloating) {
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

    GlobalShortcut {
        name: "lockScreen"
        description: "Lock the screen"
        onPressed: {
            lockscreenProcess.startDetached();
        }
    }

    GlobalShortcut {
        name: "triggerSystemUpdate"
        description: "Launch the system update terminal"
        onPressed: {
            systemUpdatesButton.triggerUpdate();
        }
    }

    GlobalShortcut {
        name: "toggleSettingsDropdown"
        description: "Open/close the settings dropdown"
        onPressed: {
            var pos = settingsButton.mapToItem(null, settingsButton.width / 2, 0);
            settingsDropdown.panelX = Math.max(0, pos.x - settingsDropdown.panelWidth / 2 - 16);
            if (settingsDropdown.isOpen) {
                settingsDropdown.closePanel();
            } else {
                root.switchPanel(() => settingsDropdown.openPanel());
            }
        }
    }

    GlobalShortcut {
        name: "toggleVolumeDropdown"
        description: "Open/close the volume dropdown"
        onPressed: {
            var pos = volumeWidget.mapToItem(null, volumeWidget.width / 2, 0);
            volumeDropdown.panelX = pos.x - volumeDropdown.panelWidth / 2 - 16;
            if (volumeDropdown.isOpen) {
                volumeDropdown.closePanel();
            } else {
                root.switchPanel(() => volumeDropdown.openPanel());
            }
        }
    }

    GlobalShortcut {
        name: "toggleNotifDropdown"
        description: "Open/close the notification dropdown"
        onPressed: {
            var pos = notifButton.mapToItem(null, notifButton.width / 2, 0);
            notifDropdown.panelX = Math.max(0, pos.x - notifDropdown.panelWidth / 2 - 16);
            if (notifDropdown.isOpen) {
                notifDropdown.closePanel();
            } else {
                root.switchPanel(() => notifDropdown.openPanel());
            }
        }
    }

    GlobalShortcut {
        name: "toggleDashboardDropdown"
        description: "Open/close the dashboard dropdown"
        onPressed: {
            dashboardDropdown.panelX = Math.max(0, (root.screen.width / 2) - (dashboardDropdown.panelWidth / 2) - 16);
            if (dashboardDropdown.isOpen) {
                dashboardDropdown.closePanel();
            } else {
                root.switchPanel(() => dashboardDropdown.openPanel());
            }
        }
    }

    // Process object for launching lockscreen via global shortcut
    Process {
        id: lockscreenProcess
        running: false
        command: ["quickshell", "-p", Quickshell.env("HOME") + "/dotfiles/.config/quickshell/modules/lockscreen/LockscreenService.qml"]

        onExited: (exitCode, exitStatus) => {
            console.log("Lockscreen process exited with code:", exitCode);
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
        readonly property color dimPrimary: Qt.rgba(Colors.col_primary.r, Colors.col_primary.g, Colors.col_primary.b, 0.4)

        // Cached focused screen lookup (avoids repeated array searches)
        readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? root.screen

        // State for sequenced panel switching (used by switchPanel)
        property var pendingOpen: null

        // Single source of truth for all panels that use closePanel()
        // appLauncher is excluded here because it uses closeLauncher() instead
        readonly property var dropdowns: [calendarPanel, volumeDropdown, vlanDropdown, powerProfileDropdown,
            vpnDropdown, bluetoothDropdown, wpDropdown, settingsDropdown, appLaunchDropdown, 
            trayMenu, notifDropdown, dashboardDropdown]

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
                color: Colors.col_main
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
                        color: Colors.col_background
                        border.color: "black"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 0
                            text: ""
                            font.family: root.fontFamily
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: appLaunchDropdown.isOpen || appLauncher.isOpen || launcherBtnArea.containsMouse ? Colors.col_source_color : Colors.col_primary
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
                                if (config.launcherFloating) {
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
                }

                // CENTER SECTION – WORKSPACES
                WorkspacesPanel {
                    id: workspaceContainer
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 0
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
                    spacing: 12

                    // SYSTEM UPDATES BUTTON
                    SystemUpdatesButton {
                        id: systemUpdatesButton
                        numberToText: false
                    }

                    // BLUETOOTH BUTTON
                    BluetoothButton {
                        id: btButton
                        anchors.verticalCenterOffset: 1
                        visible: BluetoothState.btPowered
                        btPowered: BluetoothState.btPowered
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

                    // VOLUME BUTTON
                    VolumeButton {
                        id: volumeWidget
                        anchors.verticalCenterOffset: 1
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

                    // POWER PROFILE BUTTON
                    PowerProfileButton {
                        id: powerProfileWidget
                        anchors.verticalCenterOffset: 1
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

                    // TEMPERATURE BUTTON
                    TemperatureButton {
                        anchors.verticalCenterOffset: 1
                    }

                    // NOTIFICATION BUTTON
                    NotifButton {
                        id: notifButton
                        anchors.verticalCenterOffset: 1
                        isActive: notifDropdown.isOpen
                        onClicked: function (clickX) {
                            notifDropdown.panelX = Math.max(0, clickX - notifDropdown.panelWidth / 2 - 16);
                            if (notifDropdown.isOpen) {
                                notifDropdown.closePanel();
                            } else {
                                root.switchPanel(() => notifDropdown.openPanel());
                            }
                        }
                    }

                    // SETTINGS BUTTON
                    SettingsButton {
                        id: settingsButton
                        anchors.verticalCenterOffset: 1
                        isActive: settingsDropdown.isOpen
                        onClicked: function (clickX) {
                            settingsDropdown.panelX = Math.max(0, clickX - settingsDropdown.panelWidth / 2 - 16);
                            if (settingsDropdown.isOpen) {
                                settingsDropdown.closePanel();
                            } else {
                                root.switchPanel(() => settingsDropdown.openPanel());
                            }
                        }
                    }

                    // LOCKSCREEN BUTTON
                    //LockscreenButton {
                    //    id: lockscreenButton
                    //    anchors.verticalCenterOffset: 1
                    //    // No dropdown state needed since it launches a separate process
                    //    isActive: false
                    //}

                    // VLAN BUTTON
                    VlanButton {
                        id: vlanButton
                        anchors.verticalCenterOffset: 1
                        isActive: vlanDropdown.isOpen
                        onClicked: function (clickX) {
                            vlanDropdown.panelX = Math.max(0, clickX - vlanDropdown.panelWidth / 2 - 16);
                            if (vlanDropdown.isOpen) {
                                vlanDropdown.closePanel();
                            } else {
                                root.switchPanel(() => vlanDropdown.openPanel());
                            }
                        }
                    }

                    // VPN MODULE
                    VPNModule {
                        id: vpnModuleWidget
                        anchors.verticalCenterOffset: 0
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

                    // SYSTEM TRAY
                    SystemTrayPanel {
                        anchors.verticalCenterOffset: 0
                        menuWindow: trayMenu
                    }

                    // CLOCK
                    ClockPanel {
                        id: clockWidget
                        anchors.verticalCenterOffset: 0
                        fontSize: 12
                        fontBold: true
                        textColor: calendarPanel.isOpen ? Colors.col_source_color : Colors.col_primary
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
        readonly property bool anyOpen: (typeof calendarPanel !== "undefined" && calendarPanel.isOpen) || (typeof volumeDropdown !== "undefined" && volumeDropdown.isOpen) || (typeof vlanDropdown !== "undefined" && vlanDropdown.isOpen) || (typeof powerProfileDropdown !== "undefined" && powerProfileDropdown.isOpen) || (typeof vpnDropdown !== "undefined" && vpnDropdown.isOpen) || (typeof bluetoothDropdown !== "undefined" && bluetoothDropdown.isOpen) || (typeof wpDropdown !== "undefined" && wpDropdown.isOpen) || (typeof settingsDropdown !== "undefined" && settingsDropdown.isOpen) || (typeof appLaunchDropdown !== "undefined" && appLaunchDropdown.isOpen) || (typeof appLauncher !== "undefined" && appLauncher.isOpen)

        mask: Region {
            item: _scrimMask
        }
        Item {
            id: _scrimMask
            x: 0
            y: 0
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

    // DashboardDropdown — tabbed dashboard panel
    DashboardDropdown {
        id: dashboardDropdown
        screen: root.screen
        onAboutToOpen: systemUpdatesButton.recheckUpdates()
        onUpgradeCompleted: systemUpdatesButton.recheckUpdates()
    }

    // NotifDropdown — notification history panel
    NotifDropdown {
        id: notifDropdown
        screen: root.screen
        systemUpdateCount: systemUpdatesButton.systemUpdateCount
        onUpgradeRequested: {
            notifDropdown.closePanel();
            _systemUpdateLaunchDelay.start();
        }
    }

    Timer {
        id: _systemUpdateLaunchDelay
        interval: notifDropdown.closeDuration + 20
        repeat: false
        onTriggered: systemUpdatesButton.triggerUpdate()
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

        // Use proper coordination like other dropdowns
        property var pendingMenuData: null
        property real pendingPosX: 0

        function openWithCoordination(menuData, posX) {
            pendingMenuData = menuData;
            pendingPosX = posX;

            const anyOpen = root.isAnyPanelOpen();
            root.closeAllDropdowns();

            if (anyOpen) {
                // Wait for close animation to complete before opening
                openDelayedTimer.restart();
            } else {
                // Open immediately if nothing was open
                openAt(pendingMenuData, pendingPosX);
            }
        }

        Timer {
            id: openDelayedTimer
            interval: 300  // Same as root.openAfterClose
            repeat: false
            onTriggered: {
                if (trayMenu.pendingMenuData) {
                    trayMenu.openAt(trayMenu.pendingMenuData, trayMenu.pendingPosX);
                    trayMenu.pendingMenuData = null;
                }
            }
        }
    }

    // WorkspaceGlowOverlay — glow effect that sits above all other layers
    WorkspaceGlowOverlay {
        id: workspaceGlow
        screen: root.screen
        visible: config.workspaceGlow
    }

    // NotifPopups — floating overlay for D-Bus notification popups
    NotifPopups {
        screen: root.screen
    }
}
