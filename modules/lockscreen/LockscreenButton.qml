import Quickshell
import Quickshell.Io
import QtQuick

Rectangle {
    id: lockscreenButton

    property string fontFamily:      config.fontFamily
    property int    iconSize:        17
    property int    fontWeight:      config.fontWeight

    property bool   isActive:        false
    property color  accentColor:     colors.col_primary
    property color  activeColor:     colors.col_source_color
    property color  hoverColor:      colors.col_source_color
    property color  dimColor:        Qt.rgba(1, 1, 1, 0.4)

    property color  backgroundColor: "transparent"
    property color  borderColor:     "transparent"
    property bool   _hovered:        false

    // Lock icon (using Font Awesome or Nerd Font lock icon)
    readonly property string lockIcon: "󰌾"  // Lock icon

    signal clicked()

    width: 15
    height: 24
    radius: 7
    color: backgroundColor
    border.color: borderColor
    border.width: 1

    // Lock icon text
    Text {
        id: iconText
        anchors.centerIn: parent
        color: lockscreenButton.isActive ? 
               lockscreenButton.activeColor : 
               lockscreenButton._hovered ? 
               lockscreenButton.hoverColor : 
               lockscreenButton.accentColor
        font.family: fontFamily
        font.pixelSize: iconSize
        font.weight: fontWeight
        text: lockIcon
    }

    // Mouse interaction
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        
        onEntered: {
            lockscreenButton._hovered = true
        }
        
        onExited: {
            lockscreenButton._hovered = false
        }
        
        onClicked: {
            console.log("Lockscreen button clicked")
            lockscreenButton.clicked()
        }
    }

    // Hover animations
    Behavior on color {
        ColorAnimation {
            duration: 150
            easing.type: Easing.OutQuart
        }
    }

    // Process object for launching lockscreen
    Process {
        id: lockscreenProcess
        running: false
        command: ["quickshell", "-p", Quickshell.env("HOME") + "/dotfiles/.config/quickshell/modules/lockscreen/LockscreenService.qml"]
        
        onExited: (exitCode, exitStatus) => {
            console.log("Lockscreen process exited with code:", exitCode)
        }
    }

    // Function to activate the lockscreen
    function activateLockscreen() {
        console.log("Activating lockscreen...")
        lockscreenProcess.startDetached()
    }

    Component.onCompleted: {
        // Connect the click signal to the activation function
        clicked.connect(activateLockscreen)
    }
}