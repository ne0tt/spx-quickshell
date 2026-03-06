import QtQuick
import Quickshell.Hyprland
import QtQuick.Effects

Item {
    id: workspacesPanel

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

    // Tracks the highest workspace id ever seen on this monitor.
    // This prevents dots from disappearing when Hyprland removes empty
    // workspaces from its list as you scroll through them.
    property int _highWaterMark: 1

    onMonitorWorkspacesChanged: {
        for (var i = 0; i < monitorWorkspaces.length; i++) {
            if (monitorWorkspaces[i].id > _highWaterMark)
                _highWaterMark = monitorWorkspaces[i].id
        }
    }

    Component.onCompleted: {
        for (var i = 0; i < monitorWorkspaces.length; i++) {
            if (monitorWorkspaces[i].id > _highWaterMark)
                _highWaterMark = monitorWorkspaces[i].id
        }
        var fws = Hyprland.focusedWorkspace
        if (fws) {
            var mon = Hyprland.monitors.values.find(m => m.name === monitorName)
            if (mon && fws.monitor === mon && fws.id > _highWaterMark)
                _highWaterMark = fws.id
        }
    }

    // Bump the high water mark whenever focus moves to a higher workspace on this monitor.
    // The focused workspace is always present in Hyprland's workspace list, so we can
    // safely read its monitor association here.
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            var fws = Hyprland.focusedWorkspace
            if (!fws) return
            var mon = Hyprland.monitors.values.find(m => m.name === workspacesPanel.monitorName)
            if (!mon) return
            if (fws.monitor === mon && fws.id > workspacesPanel._highWaterMark)
                workspacesPanel._highWaterMark = fws.id
        }
    }

    // Stable dot list: always 1 through _highWaterMark.
    // Unlike monitorWorkspaces this never shrinks, so dots remain visible
    // even after Hyprland destroys the empty workspace on navigation.
    readonly property var displayWorkspaceIds: {
        var ids = []
        for (var i = 1; i <= _highWaterMark; i++) ids.push(i)
        return ids
    }

    readonly property int wsCount: _highWaterMark

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
                radius: 8
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
        width: 50
        height: 20
        z: 1

        visible: focusedLocalIndex >= 0
        x: focusedLocalIndex >= 0 ? focusedLocalIndex * (50 + 5) : 0

        Rectangle {
            id: glowSource
            anchors.fill: parent
            radius: height / 2
            color: colors.col_source_color
            visible: true
        }

        MultiEffect {
            source: glowSource
            anchors.centerIn: glowSource
            width: glowSource.width + 10
            height: glowSource.height
            blurEnabled: true
            blur: 0.6
            blurMax: 64
            brightness: 0.3
            shadowEnabled: false
        }
    }
}