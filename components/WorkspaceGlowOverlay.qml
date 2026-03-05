import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects

// ============================================================
// WORKSPACE GLOW OVERLAY — re-renders the active workspace glow
// on the wlr-layer-shell Overlay layer so it is always visible
// above every Top-layer surface (dropdowns, app launcher, etc.).
//
// Must match the bar's geometry constants:
//   barTopMargin  = 18 (container topMargin in shell.qml)
//   barHeight     = 32 (container height in shell.qml)
//   wsItemW       = 50
//   wsItemH       = 20
//   wsGap         = 5
//
// Usage:
//   WorkspaceGlowOverlay { screen: root.screen }
// ============================================================
PanelWindow {
    id: overlay
    reloadableId: "workspaceGlowOverlay"
    anchors.left:  true
    anchors.right: true
    implicitHeight: 80        // same as the main bar window
    exclusiveZone:  0
    color: "transparent"

    // Sit above every Top-layer surface (bars, dropdowns, etc.)
    WlrLayershell.layer: WlrLayer.Overlay
    // No keyboard interaction needed — pass all input through
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Empty mask = fully click-through; the overlay only draws, never consumes input
    mask: Region {}

    // ── Bar geometry constants (must mirror shell.qml) ──────
    readonly property int _barTopMargin: -32    // container topMargin (mirrors shell.qml topMargin: 18)
    readonly property int _barHeight:    32    // container height
    readonly property int _wsItemW:      50
    readonly property int _wsItemH:      20
    readonly property int _wsGap:        5

    // ── Workspace state ──────────────────────────────────────
    property string monitorName: "DP-1"

    readonly property var monitorWorkspaces: {
        var mon = Hyprland.monitors.values.find(m => m.name === overlay.monitorName)
        if (!mon) return []
        return Hyprland.workspaces.values
            .filter(ws => ws.monitor === mon)
            .sort((a, b) => a.id - b.id)
    }

    readonly property int wsCount: monitorWorkspaces.length > 0 ? monitorWorkspaces.length : 1

    readonly property int focusedLocalIndex: {
        var fid = Hyprland.focusedWorkspace?.id ?? -1
        return monitorWorkspaces.findIndex(ws => ws.id === fid)
    }

    // Total width of the workspace row
    readonly property int _panelW: wsCount * _wsItemW + (wsCount - 1) * _wsGap

    // Absolute screen-x of the workspace row (centered on screen, same as WorkspacesPanel)
    readonly property real _panelScreenX: (overlay.width - _panelW) / 2

    // Absolute screen-y of the workspace row center
    readonly property real _panelScreenY: _barTopMargin + (_barHeight - _wsItemH) / 2

    // ── Glow item ────────────────────────────────────────────
    // Sized and positioned so the MultiEffect blur has room to expand.
    // Kept at 1×1 (invisible) when no workspace is focused.
    Item {
        id: _glowItem
        visible: overlay.focusedLocalIndex >= 0

        // Extra padding so blur feathers to zero before the item edge
        readonly property int _pad: 30

        width:  overlay._wsItemW + _pad * 2
        height: overlay._wsItemH + _pad * 2

        x: overlay._panelScreenX
           + overlay.focusedLocalIndex * (overlay._wsItemW + overlay._wsGap)
           - _pad
        y: overlay._panelScreenY - _pad

        Rectangle {
            id: _glowSrc
            anchors.centerIn: parent
            width:  overlay._wsItemW
            height: overlay._wsItemH
            radius: height / 2
            color:  colors.col_source_color
        }

        MultiEffect {
            source: _glowSrc
            anchors.centerIn: _glowSrc
            width:  _glowSrc.width + 15
            height: _glowSrc.height
            blurEnabled: true
            blur:        0.9
            blurMax:     45
            brightness:  0.3
            shadowEnabled: false
        }
    }
}
