import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "../../base"

DropdownBase {
    id: powerDrop
    reloadableId: "powerDropdown"

    keyboardFocusEnabled: true

    Item { focus: true; Keys.onEscapePressed: powerDrop.closePanel() }

    implicitHeight: 340
    panelFullHeight: 186
    panelWidth: 260
    panelTitle: "Power"
    panelIcon: ""
    headerHeight: 34

    property var actions: [
        { id: "lockscreen", label: "Lockscreen", subtitle: "Lock this session", icon: "󰌾" },
        { id: "reboot", label: "Reboot", subtitle: "Restart system", icon: "󰜉" },
        { id: "shutdown", label: "Shutdown", subtitle: "Power off system", icon: "󰐥" }
    ]

    function triggerAction(actionId) {
        if (actionId === "lockscreen") {
            lockscreenProcess.startDetached()
        } else if (actionId === "reboot") {
            rebootProcess.startDetached()
        } else if (actionId === "shutdown") {
            shutdownProcess.startDetached()
        }
        powerDrop.closePanel()
    }

    Column {
        x: 16 + 14
        y: 16 + powerDrop.headerHeight + 8
        width: powerDrop.panelWidth - 28
        spacing: 8

        Repeater {
            model: powerDrop.actions

            Item {
                width: parent.width
                height: 48

                SelectableCard {
                    id: actionCard
                    width: parent.width
                    isActive: false
                    holdDuration: 3000
                    cardIcon: modelData.icon
                    label: modelData.label
                    subtitle: modelData.subtitle
                    isPanelOpen: powerDrop.isOpen
                    accentColor: powerDrop.accentColor
                    textColor: powerDrop.textColor
                    dimColor: powerDrop.dimColor
                    flashLoops: 1
                    flashOpacityLow: 0.45
                    flashDuration: 90
                    onClicked: {
                        actionCard.flash()
                        powerDrop.triggerAction(modelData.id)
                    }
                }
            }
        }
    }

    Process {
        id: lockscreenProcess
        running: false
        command: ["quickshell", "-p", Quickshell.env("HOME") + "/dotfiles/.config/quickshell/modules/lockscreen/LockscreenService.qml"]
    }

    Process {
        id: rebootProcess
        running: false
        command: ["bash", Quickshell.env("HOME") + "/dotfiles/.config/quickshell/modules/power/reboot.sh"]
    }

    Process {
        id: shutdownProcess
        running: false
        command: ["bash", Quickshell.env("HOME") + "/dotfiles/.config/quickshell/modules/power/shutdown.sh"]
    }
}
