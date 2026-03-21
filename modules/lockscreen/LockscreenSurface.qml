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
    
    // Keyboard breathing effect process for failure state (red theme)
    Process {
        id: keyboardBreathingProc
        running: false
        command: ["python3", "/home/sispx/.config/hypr/scripts/keyboard-breathing-toggle.py", "#ff0000", "75"]
        
        onStarted: {
            console.log("Lockscreen: Keyboard breathing process started")
        }
        
        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("Lockscreen: Keyboard breathing effect activated (red)")
            } else {
                console.log("Lockscreen: Failed to activate keyboard breathing, exit code:", exitCode)
            }
        }
    }
    
    // Keyboard RGB restoration process for normal state 
    Process {
        id: keyboardRgbProc
        running: false
        command: ["python3", "/home/sispx/.config/hypr/scripts/keyboard-rgb.py"]
        
        onStarted: {
            console.log("Lockscreen: Keyboard RGB restoration process started")
        }
        
        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("Lockscreen: Keyboard RGB restored to normal")
            } else {
                console.log("Lockscreen: Failed to restore keyboard RGB, exit code:", exitCode)
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
    property string originalWallpaper: ""
    property string errorWallpaper: "/home/sispx/wallpaper/red/onyx-flow-red.jpg"
    
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
                    root.originalWallpaper = settings.currentWallpaper
                }
            } catch (e) {
                console.warn("Failed to parse settings.json:", e)
            }
        }
    }
    
    // Wallpaper background with layered approach to avoid black flash
    // Red error wallpaper (bottom layer - loaded after main wallpaper)
    Image {
        id: errorWallpaperImage
        anchors.fill: parent
        source: ""  // Initially empty, loaded after main wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: root.context.showFailure ? 0.8 : 0.0
        
        onStatusChanged: {
            if (status === Image.Error) {
                console.warn("Failed to load error wallpaper:", source)
            }
        }
        
        // Smooth wallpaper transition
        Behavior on opacity {
            PropertyAnimation {
                duration: 400
                easing.type: Easing.InOutCubic
            }
        }
    }
    
    // Normal wallpaper (top layer - hides/shows red layer)
    Image {
        id: wallpaperImage
        anchors.fill: parent
        source: root.currentWallpaper || ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: root.context.showFailure ? 0.0 : 1.0
        
        onStatusChanged: {
            if (status === Image.Error) {
                console.warn("Failed to load wallpaper:", source)
            } else if (status === Image.Ready) {
                // Once main wallpaper is loaded, preload the red wallpaper behind it
                errorWallpaperImage.source = root.errorWallpaper
            }
        }
        
        // Smooth wallpaper transition
        Behavior on opacity {
            PropertyAnimation {
                duration: 400
                easing.type: Easing.InOutCubic
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
            topMargin: 160
        }

        // Native font rendering for large sizes
        renderType: Text.NativeRendering
        font.pointSize: 80
        color: root.context.showFailure ? "#ff4444" : themeColors.col_primary
        
        // Smooth color transition
        Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }

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
    //Label {
    //    id: dateLabel
    //    visible: showLoginForm
    //    
    //    anchors {
    //        horizontalCenter: parent.horizontalCenter
    //        top: clock.bottom
    //        topMargin: 20
    //    }
    //    
    //    font.pointSize: 18
    //    color: root.context.showFailure ? "#ff4444" : themeColors.col_primary
    //    
    //    // Smooth color transition
    //    Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    //    
    //    text: {
    //        const date = clock.date
    //        const day = date.getDate().toString().padStart(2, '0')
    //        const month = (date.getMonth() + 1).toString().padStart(2, '0') // getMonth() is 0-based
    //        const year = date.getFullYear()
    //        return `${day}/${month}/${year}`
    //    }
    //}

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
            id: loginContainer
            Layout.alignment: Qt.AlignHCenter
            width: 500
            height: 200
            opacity: 0.8
            
            color: root.context.showFailure ? "#4d1f1f" : themeColors.col_main  // Dark red when error
            border.color: root.context.showFailure ? "#ff4444" : themeColors.col_source_color  // Bright red border when error
            border.width: 2
            radius: 12
            
            // Smooth color transitions
            Behavior on color { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
            
            // Shake animation for password errors
            SequentialAnimation {
                id: shakeAnimation
                running: false
                
                PropertyAnimation { target: loginContainer; property: "x"; to: loginContainer.x + 5; duration: 50 }
                PropertyAnimation { target: loginContainer; property: "x"; to: loginContainer.x - 8; duration: 100 }
                PropertyAnimation { target: loginContainer; property: "x"; to: loginContainer.x + 8; duration: 100 }
                PropertyAnimation { target: loginContainer; property: "x"; to: loginContainer.x - 8; duration: 100 }
                PropertyAnimation { target: loginContainer; property: "x"; to: loginContainer.x + 8; duration: 100 }
                PropertyAnimation { target: loginContainer; property: "x"; to: loginContainer.x - 5; duration: 200 }
                PropertyAnimation { target: loginContainer; property: "x"; to: loginContainer.x; duration: 50 }
                
                // Start delay timer when shake animation completes
                onStopped: {
                    redDelayTimer.start()
                }
            }
            
            // Timer to delay shake animation by 1 second
            Timer {
                id: shakeDelayTimer
                interval: 600  // 0.6 second delay
                repeat: false
                onTriggered: {
                    shakeAnimation.start()
                }
            }
            
            // Timer to keep box red for 3 additional seconds after shake
            Timer {
                id: redDelayTimer
                interval: 2500  // 2.5 seconds
                repeat: false
                onTriggered: {
                    root.context.showFailure = false
                }
            }
            
            // Trigger shake when authentication fails
            Connections {
                target: root.context
                function onShowFailureChanged() {
                    console.log("Lockscreen: showFailure changed to:", root.context.showFailure)
                    if (root.context.showFailure) {
                        // Stop any running timers when new error occurs
                        redDelayTimer.stop()
                        shakeDelayTimer.stop()
                        // Start delay timer to shake after 1 second
                        shakeDelayTimer.start()
                        // Activate keyboard breathing effect (red)
                        console.log("Lockscreen: Triggering keyboard breathing (red)")
                        keyboardBreathingProc.running = true
                    } else {
                        // If failure is cleared (e.g., user started typing), stop all timers
                        redDelayTimer.stop()
                        shakeDelayTimer.stop()
                        // Restore keyboard to normal RGB
                        console.log("Lockscreen: Triggering keyboard RGB restoration")
                        keyboardRgbProc.running = true
                    }
                }
            }
            
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
                    id: headerBox
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 0
                    anchors.leftMargin: 0
                    anchors.rightMargin: 0
                    height: 50
                    
                    color: root.context.showFailure ? "#ff4444" : themeColors.col_source_color  // Red header when error
                    radius: 12
                    
                    // Smooth color transition
                    Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    
                    // Clip bottom corners to make them square
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 12
                        color: root.context.showFailure ? "#ff4444" : themeColors.col_source_color  // Match header color
                        
                        // Smooth color transition
                        Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
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
                            text: root.context.showFailure ? "ACCESS DENIED" : "Enter password to unlock"
                            font.pointSize: 12
                            font.weight: Font.Medium
                            color: themeColors.col_background
                            
                            // Smooth text transition
                            Behavior on text { }
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
                        border.color: root.context.showFailure ? "#ff4444" : (passwordBox.focus ? themeColors.col_source_color : themeColors.col_primary)
                        border.width: 2
                        radius: 8
                        
                        // Smooth border color transition
                        Behavior on border.color { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
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
        //Label {
        //    visible: root.context.showFailure
        //    Layout.alignment: Qt.AlignHCenter
        //    text: "ACCESS DENIED"
        //    font.pointSize: 14
        //    color: "#ff6b6b"  // Red for error - keep this fixed as it's not part of theme
        //}
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
        color: root.context.showFailure ? "#ff4444" : themeColors.col_primary
        opacity: 0.7
        
        // Smooth color transition
        Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
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
    
    // Also restore keyboard when lockscreen is unlocked
    Connections {
        target: root.context
        function onUnlocked() {
            console.log("Lockscreen: Successfully unlocked, restoring keyboard RGB")
            keyboardRgbProc.running = true
        }
    }
}