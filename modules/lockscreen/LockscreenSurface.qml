import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Fusion
import Qt5Compat.GraphicalEffects
import Quickshell.Wayland
import Quickshell.Io

Rectangle {
    id: root
    required property LockscreenContext context
    required property bool isPrimary  // True for primary monitor, false for others
    
    readonly property ColorGroup colors: Window.active ? palette.active : palette.inactive
    
    // Media control process for pausing all players when lockscreen activates
    Process {
        id: mediaControlProc
        running: false
        command: ["playerctl", "-a", "pause"]
        
        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("Lockscreen: All media players paused")
            } else {
                console.log("Lockscreen: Failed to pause media players, exit code:", exitCode)
            }
        }
    }
    
    // Function to pause all currently playing media
    function pauseAllMedia() {
        console.log("Lockscreen: Pausing all media players")
        mediaControlProc.running = true
    }
    
    // Dynamic colors that update with theme changes (symlinked to main Colors.qml)
    Colors {
        id: themeColors
    }
    
    // Settings file reader
    property string currentWallpaper: ""
    
    FileView {
        id: settingsFile
        path: "/home/sispx/dotfiles/.config/quickshell/modules/settings/settings.json"
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            try {
                var settings = JSON.parse(text())
                if (typeof settings.currentWallpaper === "string") {
                    root.currentWallpaper = settings.currentWallpaper
                }
            } catch (e) {
                console.warn("Failed to parse settings.json:", e)
            }
        }
    }
    
    // Wallpaper background
    Image {
        id: wallpaperImage
        anchors.fill: parent
        source: root.currentWallpaper || ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        
        onStatusChanged: {
            if (status === Image.Error) {
                console.warn("Failed to load wallpaper:", source)
            }
        }
        
        // Dark overlay for text readability
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.4
        }
    }
    
    // Use theme colors for consistency (fallback color)
    color: themeColors.col_background

    // Show login form only on primary monitor, others stay black
    property bool showLoginForm: isPrimary

    // Clock displayed only on primary monitor
    Label {
        id: clock
        property var date: new Date()
        
        visible: showLoginForm  // Only show on primary monitor

        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: 100
        }

        // Native font rendering for large sizes
        renderType: Text.NativeRendering
        font.pointSize: 80
        color: themeColors.col_primary

        // Update clock every second
        Timer {
            running: clock.visible  // Only run timer when clock is visible
            repeat: true
            interval: 1000
            onTriggered: clock.date = new Date()
        }

        // Format time as HH:MM
        text: {
            const hours = this.date.getHours().toString().padStart(2, '0')
            const minutes = this.date.getMinutes().toString().padStart(2, '0')
            return `${hours}:${minutes}`
        }
    }

    // Date display (only on primary)
    Label {
        id: dateLabel
        visible: showLoginForm
        
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: clock.bottom
            topMargin: 20
        }
        
        font.pointSize: 18
        color: themeColors.col_primary
        
        text: {
            const date = clock.date
            const day = date.getDate().toString().padStart(2, '0')
            const month = (date.getMonth() + 1).toString().padStart(2, '0') // getMonth() is 0-based
            const year = date.getFullYear()
            return `${day}/${month}/${year}`
        }
    }

    // Login form (only on primary monitor)
    ColumnLayout {
        visible: showLoginForm
        
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.verticalCenter
            topMargin: -150
        }

        spacing: 20

        // Login container box
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 500
            height: 200
            opacity: 0.8
            
            color: themeColors.col_main
            border.color: themeColors.col_source_color
            border.width: 2
            radius: 12
            
            // Black glow effect
            layer.enabled: true
            layer.effect: DropShadow {
                transparentBorder: true
                horizontalOffset: 0
                verticalOffset: 0
                radius: 20
                samples: 41
                color: "#000000"
                opacity: 1
            }
            
            // Container content with header and login form
            Item {
                anchors.fill: parent
                
                // Header box anchored to top with 0px margin
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 0
                    anchors.leftMargin: 0
                    anchors.rightMargin: 0
                    height: 50
                    
                    color: themeColors.col_source_color
                    radius: 12
                    
                    // Clip bottom corners to make them square
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 12
                        color: themeColors.col_source_color
                    }
                    
                    RowLayout {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 20
                        spacing: 10
                        
                        Text {
                            text: ""
                            font.pointSize: 14
                            color: themeColors.col_background
                        }
                        
                        Label {
                            text: "Enter password to unlock"
                            font.pointSize: 12
                            font.weight: Font.Medium
                            color: themeColors.col_background
                        }
                    }
                }
                
                // Password input centered in remaining space
                TextField {
                    id: passwordBox
                    
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 25
                    
                    width: 300
                    height: 45
                    
                    font.pointSize: 12
                    padding: 15
                    
                    // Theme colors for input field
                    color: themeColors.col_source_color
                    
                    focus: true
                    enabled: !root.context.unlockInProgress
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData
                    placeholderText: "Password"
                    placeholderTextColor: themeColors.col_background

                    // Custom styling for better appearance
                    background: Rectangle {
                        color: themeColors.col_background
                        border.color: passwordBox.focus ? themeColors.col_source_color : themeColors.col_primary
                        border.width: 2
                        radius: 8
                    }

                    // Update context when text changes
                    onTextChanged: root.context.currentText = this.text

                    // Try to unlock on Enter
                    onAccepted: root.context.tryUnlock()

                    // Sync with context text
                    Connections {
                        target: root.context
                        function onCurrentTextChanged() {
                            passwordBox.text = root.context.currentText
                        }
                    }
                }
            }
        }

        // Error message
        Label {
            visible: root.context.showFailure
            Layout.alignment: Qt.AlignHCenter
            text: "Incorrect password"
            font.pointSize: 14
            color: "#ff6b6b"  // Red for error - keep this fixed as it's not part of theme
        }
    }

    // Bypass button for testing (only visible when not in production) - positioned in top right
    Button {
        id: bypassButton
        
        visible: showLoginForm
        
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 20
            rightMargin: 20
        }
        
        width: 100
        height: 30
        
        text: "Bypass"
        font.pointSize: 10
        
        // Custom styling for bypass button
        background: Rectangle {
            color: bypassButton.pressed ? themeColors.col_main : "transparent"
            border.color: themeColors.col_primary
            border.width: 1
            radius: 6                
            opacity: 0.0
        }
        
        contentItem: Text {
            text: bypassButton.text
            font: bypassButton.font
            color: themeColors.col_primary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: 0.0
        }
        
        onClicked: {
            console.log("Lockscreen: Bypass button clicked")
            root.context.enableBypass()
            root.context.tryUnlock()
        }
    }

    // System info (only on primary)
    Label {
        visible: showLoginForm
        
        anchors {
            horizontalCenter: parent.horizontalCenter 
            bottom: parent.bottom
            bottomMargin: 50
        }
        
        text: "Hyprland on Arch Linux • Screen Locked"
        
        font.pointSize: 10
        color: themeColors.col_primary
        opacity: 0.7
    }


    // Make sure the password box gets focus when the surface becomes active
    onActiveFocusChanged: {
        if (activeFocus && showLoginForm) {
            passwordBox.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        // Pause all media when lockscreen becomes active
        pauseAllMedia()
        
        if (showLoginForm) {
            passwordBox.forceActiveFocus()
        }
    }
}