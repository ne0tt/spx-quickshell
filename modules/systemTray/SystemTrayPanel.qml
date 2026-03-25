// components/SystemTrayPanel.qml
// System tray using the StatusNotifierItem protocol (Solaar, Remmina, etc.)

import Quickshell
import Quickshell.Services.SystemTray

import QtQuick
import QtQuick.Controls

Item {
    id: root

    implicitWidth: trayRow.implicitWidth > 0 ? trayRow.implicitWidth + 12 : 0
    implicitHeight: 24
    visible: trayRow.visibleChildren.length > 0 || SystemTray.items.count > 0
    
    // Debug: monitor system tray items  
    // Component.onCompleted: {
    //     console.log("SystemTray items count:", SystemTray.items.count)
    //     console.log("Visible children:", trayRow.visibleChildren.length)
    // }

    property string fontFamily: config.fontFamily
    property int    iconSize:   15  // Match other panel icons
    property color  accentColor: colors.col_primary
    property color  hoverColor:  colors.col_source_color
    property var    menuWindow:  null  // set to TrayMenu instance from shell.qml

    // ============================================================
    // NERD FONT ICON MAPPING
    // Map application IDs to nerd font icons
    // ============================================================
    property var friendlyNames: ({
        "chrome_status_icon": "Discord",
        "nm-applet": "Network Manager",
        "networkmanager": "Network Manager",
        "blueman": "Bluetooth",
        "solaar": "Logitech",
        "pavucontrol": "Volume Control",
        "pulseaudio": "PulseAudio",
        "spotify": "Spotify",
        "slack": "Slack",
        "discord": "Discord",
        "telegram": "Telegram",
        "signal": "Signal",
        "zoom": "Zoom",
        "teams": "Teams",
        "dropbox": "Dropbox",
        "nextcloud": "Nextcloud",
        "syncthing": "Syncthing",
        "remmina": "Remote Desktop",
        "clipman": "Clipboard",
        "keepassxc": "KeePassXC",
        "1password": "1Password",
        "bitwarden": "Bitwarden",
        "pamac": "Package Manager",
        "flameshot": "Screenshot",
        "steam": "Steam",
        "docker": "Docker",
        "virtualbox": "VirtualBox",
        "obs": "OBS"
    })
    
    property var nerdFontIcons: ({
        // Network & Connectivity
        "nm-applet": "󰛳",              // Network
        "networkmanager": "󰛳",
        "network-manager": "󰛳",
        "blueman-tray": "󰂯",            // Bluetooth
        "blueman": "󰂯",                 
        "bluetooth": "󰂯",
        "solaar": "󰍽",                  // Logitech (mouse/keyboard)
        
        // Audio & Media
        "pavucontrol": "\ufc58",             // Volume
        "pulseaudio": "\ufc58",
        "spotify": "\uf1bc",                 // Spotify
        "rhythmbox": "\uf025",               // Music note
        "obs": "󰃽",                         // OBS
        
        // Communication
        "slack": "\uf198",                   // Slack
        "discord": "\uf392",                 // Discord 
        "discordcanary": "\uf392",           // Discord Canary
        "discord-canary": "\uf392",          // Discord Canary
        "discordptb": "\uf392",              // Discord PTB
        "discord-ptb": "\uf392",             // Discord PTB
        "chrome_status_icon": "\uf392",      // Discord (Electron apps)
        "telegram": "\uf2c6",                // Telegram
        "signal": "\uf4ac",                  // Chat
        "zoom": "\uf03d",                    // Video
        "teams": "\uf4f8",                   // Teams
        
        // Cloud Storage
        "dropbox": "\uf16b",                 // Dropbox
        "google-drive": "\uebc3",            // Google Drive
        "nextcloud": "\uf0c2",               // Cloud
        "syncthing": "\uf0c2",
        
        // System Tools
        "remmina": "󰢹",                 // Remote desktop
        "clipman": "\uf0ea",                 // Clipboard
        "keepassxc": "\uf023",               // Lock (password manager)
        "1password": "\uf023",
        "bitwarden": "\uf023",
        
        // Updates & Package Managers
        "pamac": "\uf4b7",                   // Package
        "yay": "\uf187",                     // Archive
        "update-manager": "\uf21e",          // Download
        
        // Power & Battery
        "upower": "\uf240",                  // Battery
        "battery": "\uf240",
        "redshift": "\uf185",                // Sun/moon
        
        // Misc
        "flameshot": "\ue21e",               // Screenshot
        "steam": "\uf1b6",                   // Steam
        "docker": "\uf308",                  // Docker
        "virtualbox": "\uf6a6"               // VM
    })

    // Function to get nerd font icon for an app
    function getNerdFontIcon(item) {
        if (!item) return null
        
        // Try matching against item ID (preferred)
        var id = item.id ? item.id.toLowerCase() : ""
        
        // Debug: log the ID and title to help identify apps
        // console.log("Tray item - ID:", item.id, "Title:", item.title)
        
        if (id && nerdFontIcons[id]) {
            return nerdFontIcons[id]
        }
        
        // Try matching against title
        var title = item.title ? item.title.toLowerCase() : ""
        
        // Try partial matching for both ID and title
        for (var key in nerdFontIcons) {
            if (id && id.includes(key)) {
                return nerdFontIcons[key]
            }
            if (title && title.includes(key)) {
                return nerdFontIcons[key]
            }
        }
        
        return null
    }

    // ============================================================
    // TRAY ROW
    // ============================================================
    Rectangle {
        id: trayBg
        anchors.verticalCenter: parent.verticalCenter
        width: trayRow.implicitWidth + 12
        height: 24
        radius: 7
        color: colors.col_background
        border.color: "black"
        border.width: 1

        Row {
            id: trayRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            spacing: 4

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: trayDelegate
                required property SystemTrayItem modelData

                width: 24
                height: 24

                property string nerdIcon: root.getNerdFontIcon(modelData)
                property bool useNerdFont: nerdIcon !== null && nerdIcon !== ""
                
                // Get tooltip text with fallbacks
                function getTooltipText() {
                    var tt = modelData.tooltip
                    var title = modelData.title || ""
                    
                    if (tt) {
                        var ttTitle = tt.title || ""
                        var ttDesc = tt.description || ""
                        
                        if (ttTitle && ttDesc) {
                            return ttTitle + "\n" + ttDesc
                        } else if (ttTitle) {
                            return ttTitle
                        } else if (ttDesc) {
                            return ttDesc
                        }
                    }
                    
                    // Check if title is available
                    if (title) return title
                    
                    // Try to find a friendly name for recognized apps
                    var id = modelData.id ? modelData.id.toLowerCase() : ""
                    if (id) {
                        // Check for exact match
                        if (root.friendlyNames[id]) {
                            return root.friendlyNames[id]
                        }
                        
                        // Check for partial match
                        for (var key in root.friendlyNames) {
                            if (id.includes(key)) {
                                return root.friendlyNames[key]
                            }
                        }
                    }
                    
                    // Final fallback to ID or generic name
                    return modelData.id || "System Tray Item"
                }

                // ------------------------------------------------
                // NERD FONT ICON (if available)
                // ------------------------------------------------
                Text {
                    anchors.centerIn: parent
                    visible: trayDelegate.useNerdFont
                    text: trayDelegate.nerdIcon
                    font.family: root.fontFamily
                    font.pixelSize: root.iconSize
                    color: area.containsMouse ? root.hoverColor : root.accentColor
                    
                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }

                // ------------------------------------------------
                // TRAY ICON (fallback)
                // ------------------------------------------------
                Image {
                    anchors.centerIn: parent
                    visible: !trayDelegate.useNerdFont
                    source: trayDelegate.modelData.icon
                    width: root.iconSize
                    height: root.iconSize
                    smooth: true
                    mipmap: true
                    fillMode: Image.PreserveAspectFit
                }

                // ------------------------------------------------
                // MOUSE INTERACTION
                // Left-click  → activate (show/hide context menu)
                // ------------------------------------------------
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor

                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            if (root.menuWindow && trayDelegate.modelData.menu) {
                                if (root.menuWindow.isOpen) {
                                    root.menuWindow.closePanel();
                                } else {
                                    var localPos = trayDelegate.mapToItem(null, 0, 0);
                                    // Use the tray menu's coordination function
                                    if (root.menuWindow.openWithCoordination) {
                                        root.menuWindow.openWithCoordination(trayDelegate.modelData.menu, localPos.x);
                                    } else {
                                        root.menuWindow.openAt(trayDelegate.modelData.menu, localPos.x);
                                    }
                                }
                            } else {
                                trayDelegate.modelData.activate();
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            trayDelegate.modelData.secondaryActivate();
                        }
                    }
                }
            }
        }
    }
    }
}
