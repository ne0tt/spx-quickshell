import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Fusion
import Quickshell.Wayland

Rectangle {
    id: root
    required property LockscreenContext context
    required property bool isPrimary  // True for primary monitor, false for others
    
    readonly property ColorGroup colors: Window.active ? palette.active : palette.inactive
    
    // Dynamic colors that update with theme changes (symlinked to main Colors.qml)
    Colors {
        id: themeColors
    }
    
    // Use theme colors for consistency
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
            topMargin: 50
        }

        spacing: 20

        // Username label
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "Enter password to unlock"
            font.pointSize: 16
            color: themeColors.col_primary
        }

        // Password input and unlock button
        RowLayout {
            spacing: 15
            
            TextField {
                id: passwordBox

                Layout.preferredWidth: 300
                Layout.preferredHeight: 50
                
                font.pointSize: 14
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
                    color: themeColors.col_main
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

            Button {
                id: unlockButton
                
                Layout.preferredWidth: 100
                Layout.preferredHeight: 50
                
                text: root.context.unlockInProgress ? "..." : "Unlock"
                font.pointSize: 12
                
                // Don't steal focus from text box
                focusPolicy: Qt.NoFocus
                
                enabled: !root.context.unlockInProgress && root.context.currentText !== ""
                
                // Custom styling
                background: Rectangle {
                    color: unlockButton.enabled ? (unlockButton.pressed ? themeColors.col_main : themeColors.col_source_color) : themeColors.col_primary
                    border.color: themeColors.col_background
                    border.width: 1
                    radius: 8
                    
                    opacity: unlockButton.enabled ? 1.0 : 0.6
                }
                
                contentItem: Text {
                    text: unlockButton.text
                    font: unlockButton.font
                    color: themeColors.col_background
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: root.context.tryUnlock()
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
        
        font.pointSize: 12
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
        if (showLoginForm) {
            passwordBox.forceActiveFocus()
        }
    }
}