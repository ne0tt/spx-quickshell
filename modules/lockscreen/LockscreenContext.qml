import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: root
    
    // Signals
    signal unlocked()
    signal failed()
    
    // Shared state properties for all lock surfaces
    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property bool bypassMode: false  // For testing purposes
    
    // Clear the failure text once the user starts typing
    onCurrentTextChanged: showFailure = false

    function tryUnlock() {
        if (bypassMode) {
            // Bypass authentication for testing
            console.log("Lockscreen: Bypassing authentication (test mode)")
            root.unlocked()
            return
        }
        
        if (currentText === "") return

        root.unlockInProgress = true
        pam.start()
    }

    // Enable bypass mode for testing
    function enableBypass() {
        root.bypassMode = true
        console.log("Lockscreen: Bypass mode enabled for testing")
    }

    PamContext {
        id: pam

        // Custom PAM config directory with absolute path
        configDirectory: Quickshell.env("HOME") + "/dotfiles/.config/quickshell/modules/lockscreen/pam"
        config: "password.conf"

        // Handle PAM authentication requests
        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root.currentText)
            }
        }

        // Handle authentication completion
        onCompleted: result => {
            if (result == PamResult.Success) {
                console.log("Lockscreen: Authentication successful")
                root.unlocked()
            } else {
                console.log("Lockscreen: Authentication failed")
                root.currentText = ""
                root.showFailure = true
            }

            root.unlockInProgress = false
        }

        // Handle authentication errors
        onError: error => {
            console.error("Lockscreen PAM error:", error)
            root.currentText = ""
            root.showFailure = true
            root.unlockInProgress = false
        }
    }
}