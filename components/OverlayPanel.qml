import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// ============================================================
// OVERLAY PANEL — a generic floating panel at WlrLayer.Overlay.
//
// WlrLayer.Overlay sits above WlrLayer.Top (the main bar layer),
// so this panel always renders in front of the bar and its dropdowns.
//
// Usage in shell.qml:
//   OverlayPanel {
//       id: myOverlay
//       screen: root.screen
//
//       // Position & size (pixels, relative to screen top-left)
//       panelX:      (screen.width  - panelWidth)  / 2   // centred
//       panelY:      (screen.height - panelHeight) / 2
//       panelWidth:  400
//       panelHeight: 300
//
//       // Your UI goes here — injected into the inner content area
//       Text { anchors.centerIn: parent; text: "Hello, overlay!" }
//   }
//
// API:
//   myOverlay.show()    — open with fade+scale animation
//   myOverlay.hide()    — close with fade+scale animation
//   myOverlay.toggle()  — toggle open/closed
//   myOverlay.isOpen    — read-only bool
// ============================================================
PanelWindow {
    id: _overlay

    // ── z-order: Overlay > Top (main bar) > Bottom > Background ──
    WlrLayershell.layer: WlrLayer.Overlay

    // Never grab keyboard focus — the overlay is non-interactive by default.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // ── Window geometry ───────────────────────────────────────────
    // Full screen width+height so the inner panel can be placed anywhere.
    // exclusiveZone: 0 means the compositor does not reserve space for us.
    anchors.top:   true
    anchors.left:  true
    anchors.right: true
    implicitHeight: screen ? screen.height : 1080
    exclusiveZone: 0
    color: "transparent"

    // Shrink input mask to zero when closed — prevents this window
    // from swallowing pointer events that belong to windows below.
    mask: Region { item: _inputMask }
    Item {
        id: _inputMask
        x: panelX;   y: panelY
        width:  _panel.visible ? panelWidth  : 0
        height: _panel.visible ? panelHeight : 0
    }

    // ─── Geometry ────────────────────────────────────────────────
    // Default: centred on screen. Override per-instance as needed.
    property real panelX:      screen ? (screen.width  - panelWidth)  / 2 : 0
    property real panelY:      screen ? (screen.height - panelHeight) / 2 : 0
    property int  panelWidth:  360
    property int  panelHeight: 200

    // ─── Theme ───────────────────────────────────────────────────
    property string fontFamily:  config.fontFamily
    property color  panelColor:  colors.col_main
    property color  borderColor: "black"
    property real   borderWidth: 1
    property int    panelRadius: 12

    // ─── Animation tuning ────────────────────────────────────────
    property int animOpenMs:  180
    property int animCloseMs: 140

    // ─── Public API ───────────────────────────────────────────────
    readonly property bool isOpen: _panel.visible

    // Default property: child items declared inside OverlayPanel go
    // directly into the content slot of the inner rectangle.
    default property alias content: _contentSlot.data

    function show() {
        if (_panel.visible) return;
        _panel.opacity = 0;
        _panel.scale   = 0.96;
        _panel.visible = true;
        _openAnim.start();
    }

    function hide() {
        if (!_panel.visible) return;
        _closeAnim.start();
    }

    function toggle() {
        _panel.visible ? hide() : show();
    }

    // ─── Drop shadow (rendered behind the panel rect) ─────────────
    Rectangle {
        x:       _panel.x
        y:       _panel.y
        width:   panelWidth
        height:  panelHeight
        radius:  panelRadius
        color:   "#000000"
        visible: _panel.visible
        opacity: _panel.opacity * 0.55
        scale:   _panel.scale
        z:       0

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur:    0.8
            blurMax: 28
        }
    }

    // ─── Panel body ───────────────────────────────────────────────
    Rectangle {
        id: _panel
        x:       panelX
        y:       panelY
        width:   panelWidth
        height:  panelHeight
        radius:  panelRadius
        color:   panelColor
        visible: false
        z:       1

        border.color: borderColor
        border.width: borderWidth

        // Content injection point
        Item {
            id: _contentSlot
            anchors.fill: parent
        }

        // ── Open: fade in + scale up ──────────────────────────
        ParallelAnimation {
            id: _openAnim
            NumberAnimation {
                target: _panel; property: "opacity"
                from: 0; to: 1
                duration: _overlay.animOpenMs
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: _panel; property: "scale"
                from: 0.96; to: 1.0
                duration: _overlay.animOpenMs
                easing.type: Easing.OutCubic
            }
        }

        // ── Close: fade out + scale down, then hide ───────────
        SequentialAnimation {
            id: _closeAnim
            ParallelAnimation {
                NumberAnimation {
                    target: _panel; property: "opacity"
                    from: 1; to: 0
                    duration: _overlay.animCloseMs
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: _panel; property: "scale"
                    from: 1.0; to: 0.96
                    duration: _overlay.animCloseMs
                    easing.type: Easing.InCubic
                }
            }
            ScriptAction { script: _panel.visible = false }
        }
    }
}
