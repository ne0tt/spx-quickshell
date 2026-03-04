import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland

import QtQuick
import QtQuick.Effects

import "components"
import "."

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
        // Register in hyprland.conf:
        //   bind = SUPER, Space, global, quickshell:toggleAppLauncher
        onPressed: {
            if (appLauncher.isOpen) {
                appLauncher.closeLauncher();
            } else {
                appLauncher.screen = root.focusedScreen;
                root.switchPanel(() => appLauncher.openLauncher());
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

    // ============================================================
    // TOP PANEL WINDOW
    // ============================================================
    PanelWindow {
        id: root
        reloadableId: "mainBar"
        screen: Quickshell.screens.find(s => s.name === "DP-1")

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
        property int fontSize: 11
        property int fontWeight: Font.Bold

        // Semi-transparent primary colour used for dim/inactive states
        readonly property color dimPrimary: Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.4)

        // Cached focused screen lookup (avoids repeated array searches)
        readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor.name) ?? root.screen

        // Close every open dropdown/drawer in one call
        function closeAllDropdowns() {
            const dropdowns = [
                calendarPanel, volumeDropdown, vlanDropdown, powerProfileDropdown,
                networkDropdown, vpnDropdown, bluetoothDropdown, wpDropdown, weatherDropdown
            ];
            for (const p of dropdowns) {
                if (p.isOpen) p.closePanel();
            }
            if (appLauncher.isOpen) appLauncher.closeLauncher();
        }

        // Returns true if any panel/dropdown is currently open
        function isAnyPanelOpen() {
            return [calendarPanel, volumeDropdown, vlanDropdown, powerProfileDropdown,
                    networkDropdown, vpnDropdown, bluetoothDropdown, wpDropdown,
                    weatherDropdown, appLauncher].some(p => p.isOpen);
        }

        // Close all open panels, then open the requested one after animation
        property var pendingOpen: null
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
        // BAR SHADOW — blurred black rect, same shape as bar
        // Must be a sibling of the container, NOT inside it,
        // so the blur can expand freely past the margins.
        // ========================================================
        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 15
                leftMargin: 15
                rightMargin: 15
            }
            height: 40
            radius: 13
            color: "#000000"

            z: 0
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 2
                blurMax: 12
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
                leftMargin: 17
                rightMargin: 17
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
                color: Qt.rgba(colors.col_main.r, colors.col_main.g, colors.col_main.b, 1.0)

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
                        width: 70
                        height: 24
                        radius: 7
                        color: colors.col_background
                        border.color: "black"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: root.fontFamily
                            font.pixelSize: 32
                            font.weight: Font.Bold
                            color: appLauncher.isOpen || launcherBtnArea.containsMouse ? colors.col_source_color : colors.col_primary
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
                                if (appLauncher.isOpen) {
                                    appLauncher.closeLauncher();
                                } else {
                                    root.closeAllDropdowns();
                                    appLauncher.screen = root.focusedScreen;
                                    appLauncher.openLauncher();
                                }
                            }
                        }
                    }

                    // ---------------- Wallpaper Button ----------------
                    Rectangle {
                        id: wallpaperButton
                        width: 32
                        height: 24
                        radius: 7
                        color: colors.col_background
                        border.color: "black"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰸉"
                            font.family: root.fontFamily
                            font.pixelSize: 20
                            color: wpDropdown.isOpen || wpBtnArea.containsMouse ? colors.col_source_color : colors.col_primary
                            Behavior on color {
                                ColorAnimation {
                                    duration: 160
                                }
                            }
                        }

                        MouseArea {
                            id: wpBtnArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                var pos = wallpaperButton.mapToItem(null, 0, 0);
                                wpDropdown.panelX = pos.x + wallpaperButton.width / 2 - wpDropdown.panelWidth / 2 - 16 + 250;
                                if (wpDropdown.isOpen) {
                                    wpDropdown.closePanel();
                                } else {
                                    root.switchPanel(() => wpDropdown.openPanel());
                                }
                            }
                        }
                    }
                }

                // CENTER SECTION – WORKSPACES
                WorkspacesPanel {
                    id: workspaceContainer
                    anchors.centerIn: parent
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

                    YayUpdatePanel {
                        accentColor: colors.col_source_color
                        backgroundColor: colors.col_background
                        fontFamily: root.fontFamily
                        fontSize: 13
                        fontWeight: root.fontWeight
                    }

                    // VLAN BUTTON — opens / closes VlanDropdown
                    Rectangle {
                        id: vlanButton
                        width: 32
                        height: 24
                        radius: 7
                        color: "transparent"
                        border.color: "transparent"
                        border.width: 0

                        Text {
                            anchors.centerIn: parent
                            text: "󰲝"
                            font.family: root.fontFamily
                            font.pixelSize: 22
                            color: vlanDropdown.isOpen || vlanBtnArea.containsMouse ? colors.col_source_color : colors.col_primary
                            Behavior on color {
                                ColorAnimation {
                                    duration: 160
                                }
                            }
                        }

                        MouseArea {
                            id: vlanBtnArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                var pos = vlanButton.mapToItem(null, 0, 0);
                                vlanDropdown.panelX = Math.max(0, pos.x + vlanButton.width / 2 - vlanDropdown.panelWidth / 2 - 16);
                                if (vlanDropdown.isOpen) {
                                    vlanDropdown.closePanel();
                                } else {
                                    root.switchPanel(() => vlanDropdown.openPanel());
                                }
                            }
                        }
                    }

                    // ETHERNET IP
                    Rectangle {
                        id: ethernetPanel
                        width: 120
                        height: 24
                        radius: 7
                        color: colors.col_background
                        border.color: "black"
                        border.width: 1
                        visible: networkDropdown.infoIp !== "—" && networkDropdown.infoIp !== ""
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "  " + networkDropdown.infoIp
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize
                            font.weight: root.fontWeight
                            color: networkDropdown.isOpen || ethernetBtnArea.containsMouse ? colors.col_source_color : colors.col_primary
                            Behavior on color {
                                ColorAnimation {
                                    duration: 160
                                }
                            }
                        }

                        MouseArea {
                            id: ethernetBtnArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                var pos = ethernetPanel.mapToItem(null, 0, 0);
                                var globalX = pos.x + ethernetPanel.width / 2;
                                networkDropdown.panelX = Math.max(0, globalX - networkDropdown.panelWidth / 2 - 16);
                                if (networkDropdown.isOpen) {
                                    networkDropdown.closePanel();
                                } else {
                                    root.switchPanel(() => networkDropdown.openPanel());
                                }
                            }
                        }
                    }

                    // VPN MODULE
                    VPNModule {
                        id: vpnModuleWidget
                        fontFamily: root.fontFamily
                        fontSize: root.fontSize
                        fontWeight: root.fontWeight
                        isActive: vpnDropdown.isOpen
                        backgroundColor: colors.col_background
                        accentColor: colors.col_primary
                        activeColor: colors.col_source_color
                        hoverColor: colors.col_source_color
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
                        height: parent.height

                        // BLUETOOTH TOGGLE
                        BluetoothPanel {
                            id: btPanel
                            fontFamily: root.fontFamily
                            btPowered: bluetoothDropdown.btPowered
                            isActive:  bluetoothDropdown.isOpen
                            accentColor: colors.col_primary
                            activeColor: colors.col_source_color
                            hoverColor:  colors.col_source_color
                            dimColor: root.dimPrimary
                            onClicked: function (clickX) {
                                bluetoothDropdown.panelX = Math.max(0, clickX - bluetoothDropdown.panelWidth / 2 - 16)
                                if (bluetoothDropdown.isOpen) {
                                    bluetoothDropdown.closePanel()
                                } else {
                                    root.switchPanel(() => bluetoothDropdown.openPanel())
                                }
                            }
                        }

                        VolumePanel {
                            id: volumeWidget
                            fontFamily: root.fontFamily
                            fontSize: root.fontSize
                            fontWeight: root.fontWeight
                            isActive: volumeDropdown.isOpen
                            accentColor: colors.col_primary
                            activeColor: colors.col_source_color
                            hoverColor: colors.col_source_color
                            volumeData: volumeState
                            onClicked: function (clickX) {
                                volumeDropdown.panelX = clickX - volumeDropdown.panelWidth / 2 - 16;
                                if (volumeDropdown.isOpen) {
                                    volumeDropdown.closePanel();
                                } else {
                                    root.switchPanel(() => volumeDropdown.openPanel());
                                }
                            }
                        }

                        PowerProfilePanel {
                            id: powerProfileWidget
                            isActive: powerProfileDropdown.isOpen
                            accentColor: colors.col_primary
                            activeColor: colors.col_source_color
                            hoverColor: colors.col_source_color
                            fontFamily: root.fontFamily
                            fontWeight: root.fontWeight
                            onClicked: function (clickX) {
                                powerProfileDropdown.panelX = Math.max(0, clickX - powerProfileDropdown.panelWidth / 2 - 16);
                                if (powerProfileDropdown.isOpen) {
                                    powerProfileDropdown.closePanel();
                                } else {
                                    root.switchPanel(() => powerProfileDropdown.openPanel());
                                }
                            }
                        }

                        TemperaturePanel {
                            fontFamily: root.fontFamily
                            fontSize: root.fontSize
                            fontWeight: root.fontWeight
                            accentColor: colors.col_primary
                        }

                        // WEATHER
                        WeatherPanel {
                            id: weatherWidget
                            fontFamily: root.fontFamily
                            fontSize: root.fontSize
                            fontWeight: root.fontWeight
                            isActive: weatherDropdown.isOpen
                            accentColor: colors.col_primary
                            activeColor: colors.col_source_color
                            hoverColor: colors.col_source_color
                            weatherData: weatherState
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

                    // SYSTEM TRAY (Solaar, Remmina, etc.)
                    SystemTrayPanel {}

                    ClockPanel {
                        id: clockWidget
                        fontFamily: root.fontFamily
                        fontSize: 13
                        fontBold: true
                        textColor: calendarPanel.isOpen ? colors.col_source_color : colors.col_primary
                        backgroundColor: colors.col_background
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


    // CalendarPanel — drops down from the clock
    CalendarPanel {
        id: calendarPanel
        screen: root.screen
    }

    // VolumeDropdown — drops down from the volume button
    VolumeDropdown {
        id: volumeDropdown
        screen: root.screen
        volumeData: volumeState
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
        weatherData: weatherState
    }

    // Shared weather state — single fetch source for WeatherPanel + WeatherDropdown
    WeatherState {
        id: weatherState
    }

    // Shared volume state — single source for VolumePanel + VolumeDropdown
    VolumeState {
        id: volumeState
    }

    // AppLauncher — centred rofi-style launcher (Super+Space or launcher button)
    AppLauncher {
        id: appLauncher
        screen: root.screen
    }
}
