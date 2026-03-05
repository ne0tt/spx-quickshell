import QtQuick
import Quickshell.Hyprland
import QtQuick.Effects

Item {
    id: workspacesPanel

    // The Hyprland output name for the monitor this bar lives on
    property string monitorName: "DP-1"

    // Workspaces that belong to this monitor, sorted by id
    readonly property var monitorWorkspaces: {
        var mon = Hyprland.monitors.values.find(m => m.name === monitorName)
        if (!mon) return []
        return Hyprland.workspaces.values
            .filter(ws => ws.monitor === mon)
            .sort((a, b) => a.id - b.id)
    }

    readonly property int wsCount: monitorWorkspaces.length > 0 ? monitorWorkspaces.length : 1

    // Index of the focused workspace within this monitor's list (-1 if not on this monitor)
    readonly property int focusedLocalIndex: {
        var fid = Hyprland.focusedWorkspace?.id ?? -1
        return monitorWorkspaces.findIndex(ws => ws.id === fid)
    }

    width: wsCount * 50 + (wsCount - 1) * 5
    height: 20

    // Inactive workspace rectangles
    Repeater {
    id: wsRepeater
    model: wsCount

    Item {
        width: 50
        height: 20
        x: index * (width + 5)

        readonly property int wsId: monitorWorkspaces[index] ? monitorWorkspaces[index].id : -1

        Rectangle {
            id: wsRect
            anchors.fill: parent
            radius: 8
            border.color: "black"
            border.width: 1
            color: Hyprland.focusedWorkspace?.id === parent.wsId
                   ? colors.col_source_color
                   : colors.col_background

            // Animate color changes smoothly
            Behavior on color {
                ColorAnimation {
                    duration: 350  // fade duration in ms
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
        width: 50
        height: 20
        z: 1

        // Reactive bindings to always follow the active workspace
        visible: focusedLocalIndex >= 0
        x: focusedLocalIndex >= 0 ? focusedLocalIndex * (50 + 5) : 0

        Rectangle {
            id: glowSource
            anchors.fill: parent
            radius: height / 2  // true pill / capsule shape
            color: colors.col_source_color
            visible: true
        }

        MultiEffect {
            source: glowSource
            // Padding well beyond blurMax so blur feathers to zero before the edge
            anchors.centerIn: glowSource
            width: glowSource.width + 15
            height: glowSource.height
            blurEnabled: true
            blur: 0.9
            blurMax: 45
            brightness: 0.3
            shadowEnabled: false
        }
    }
}