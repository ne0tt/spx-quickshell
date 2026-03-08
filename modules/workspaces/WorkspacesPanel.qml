import QtQuick
import Quickshell.Hyprland
import QtQuick.Effects

Item {
    id: workspacesPanel

    // Toggle the glow effect on the active workspace dot
    property bool glowEnabled: false

    // The Hyprland output name for the monitor this bar lives on
    property string monitorName: config.barMonitor

    // Workspaces that belong to this monitor, sorted by id
    readonly property var monitorWorkspaces: {
        var mon = Hyprland.monitors.values.find(m => m.name === monitorName)
        if (!mon) return []
        return Hyprland.workspaces.values
            .filter(ws => ws.monitor === mon)
            .sort((a, b) => a.id - b.id)
    }

    // Live dot list: exactly the workspaces currently on this monitor, sorted by id.
    // Derived directly from monitorWorkspaces so the count is always accurate.
    readonly property var displayWorkspaceIds: monitorWorkspaces.map(ws => ws.id)
    readonly property int wsCount: monitorWorkspaces.length

    // Index of the focused workspace within the display list (-1 if not on this monitor).
    // Uses the live workspace list to verify monitor affinity, falling back to -1 for
    // workspaces focused on other monitors.
    readonly property int focusedLocalIndex: {
        var fid = Hyprland.focusedWorkspace?.id ?? -1
        if (fid < 1) return -1
        var mon = Hyprland.monitors.values.find(m => m.name === monitorName)
        if (!mon) return -1
        var fws = Hyprland.workspaces.values.find(ws => ws.id === fid)
        if (!fws || fws.monitor !== mon) return -1
        return displayWorkspaceIds.indexOf(fid)
    }

    width: wsCount * 50 + (wsCount - 1) * 5
    height: 20

    // Workspace dot rectangles
    Repeater {
        id: wsRepeater
        model: displayWorkspaceIds

        Item {
            width: 50
            height: 20
            x: index * (width + 5)

            readonly property int wsId: modelData

            Rectangle {
                id: wsRect
                anchors.fill: parent
                radius: 10
                border.color: "black"
                border.width: 1
                color: Hyprland.focusedWorkspace?.id === parent.wsId
                       ? colors.col_source_color
                       : colors.col_background

                Behavior on color {
                    ColorAnimation {
                        duration: 350
                        easing.type: Easing.InOutQuad
                    }
                }

            }

            MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("workspace " + parent.wsId)
            }
        }
    }

    // Active workspace glow always on top
    Item {
        id: activeGlow
        readonly property int _pad: 32
        width: 50 + _pad * 2
        height: 20 + _pad * 2
        z: 1

        visible: glowEnabled && focusedLocalIndex >= 0
        x: (focusedLocalIndex >= 0 ? focusedLocalIndex * (50 + 5) : 0) - _pad
        y: -_pad

        Rectangle {
            id: glowSource
            anchors.centerIn: parent
            width:  50
            height: 20
            radius: height / 2
            color: colors.col_source_color
            visible: true
        }

        MultiEffect {
            source: glowSource
            anchors.centerIn: glowSource
            width: glowSource.width
            height: glowSource.height
            blurEnabled: true
            blur: 0.6
            blurMax: 64
            brightness: 0.3
            shadowEnabled: false
        }
    }
}