import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import qs.base
import "../.."

// ============================================================
// RIGHT PANEL SLIDER — a panel that slides in from the right edge.
//
// Usage in shell.qml:
//   RightPanelSlider {
//       id: rightPanel
//       screen: root.screen
//   }
//
// API:
//   rightPanel.openPanel()
//   rightPanel.closePanel()
//   rightPanel.isOpen   — read-only bool
//
// To add content, use the panelContent alias:
//   RightPanelSlider {
//       Item { ... }   ← lands in the content area
//   }
// ============================================================
PanelWindow {
    id: _panel
    reloadableId: "rightPanelSlider"

    // Full-screen coverage so the mask and click-outside area work correctly
    // Anchored to right+top+bottom (not left) so the compositor reserves
    // space on the right edge rather than the top.
    anchors.top:    true
    anchors.bottom: true
    anchors.right:  true
    implicitWidth:  screen ? screen.width : 1920
    exclusiveZone:  _reserveSpace ? panelWidth + panelMarginRight : 0
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay

    // ─── Fullscreen detection — hide panel when app is fullscreen ───
    visible: !hasFullscreenWindow
    
    readonly property bool hasFullscreenWindow: {
        var currentMonitor = Hyprland.monitorFor(_panel.screen)
        if (!currentMonitor) return false
        
        return Hyprland.toplevels.values.some(window => {
            return window.monitor === currentMonitor && 
                   window.lastIpcObject?.fullscreen === true
        })
    }
    
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "fullscreen" || event.name === "activewindow") {
                _panel.hasFullscreenWindowChanged()  // Force property re-evaluation
            }
        }
    }

    // Shrink input mask to the panel body when open, 0×0 when closed
    mask: Region { item: _maskItem }
    Item {
        id: _maskItem
        x: _panel.width - _panel.panelWidth - _panel.panelMarginRight
        y: _panel.panelMarginTop
        width:  _wrapper.visible ? _panel.panelWidth  : 0
        height: _wrapper.visible ? _panel.panelHeight : 0
    }

    // ─── Configurable props ───────────────────────────────
    property int    panelWidth:      400
    property int    panelMarginRight: 17
    property int    panelMarginTop:   16
    property int    panelMarginBottom: 17
    readonly property var _configScreen: Quickshell.screens.find(s => s.name === config.barMonitor) ?? Quickshell.screens[0]
    readonly property int _screenHeight: _configScreen ? _configScreen.height : 1080
    property int    panelHeight: _screenHeight - 83 // below the bar, with some breathing room
    //property int    panelHeight: _screenHeight - 32 // next to the bar, for a more seamless look
    property int    openDuration:  300
    property int    closeDuration: 220
    property color  panelColor:    Colors.col_background
    property color  accentColor:   Colors.col_source_color
    property color  textColor:     Colors.col_primary
    property string panelTitle:    "Panel"
    property string panelIcon:     "󰹍"
    property string fontFamily:    config.fontFamily

    // ─── Active-monitor tracking — dims panel when monitor loses focus ───
    readonly property bool _screenActive:
        screen ? (Hyprland.focusedMonitor?.name === screen.name) : true

    // ─── Content injection ────────────────────────────────
    default property alias panelContent: _contentArea.data

    // ─── Internal state tracking ──────────────────────────
    property bool _panelFullyOpen: false  // true when slide animation completes
    property bool _reserveSpace: false    // true when exclusiveZone should be active

    // ─── Public API ───────────────────────────────────────
    readonly property bool isOpen: _wrapper.visible

    function openPanel() {
        _slideOut.stop()
        _body.x = panelWidth   // start off-screen right
        _panelFullyOpen = false
        _reserveSpace = true   // trigger window resize
        _wrapper.visible = true // show panel immediately
        _slideIn.start()       // start sliding in sync with window resize
    }

    function closePanel() {
        _slideIn.stop()
        _panelFullyOpen = false
        // Keep _reserveSpace = true during slide out
        _slideOut.start()
    }

    // ─── Click-outside to close ───────────────────────────
    MouseArea {
        anchors.fill: parent
        z: 0
        visible: _wrapper.visible
        propagateComposedEvents: true
        onClicked: {
            if (!_wrapper.containsMouse)
                _panel.closePanel()
        }
    }

    // ─── Drop shadow on left edge ─────────────────────────
    Rectangle {
        visible: _wrapper.visible && !_slideIn.running && !_slideOut.running
        opacity: _body.x === 0 ? 0.7 : 0
        Behavior on opacity { NumberAnimation { duration: _panel.openDuration } }
        x: _panel.width - _panel.panelWidth - 18 - _panel.panelMarginRight
        y: _panel.panelMarginTop
        width:  18
        height: _panel.panelHeight
        color:  "transparent"
        layer.enabled: !_slideIn.running && !_slideOut.running
        layer.effect: MultiEffect {
            blurEnabled: true
            blur:    0.9
            blurMax: 24
        }
        Rectangle {
            anchors.right: parent.right
            y: 0
            width:  4
            height: parent.height
            color:  "black"
            opacity: 0.5
        }
    }

    // ─── Glow halo — matches Hyprland active-window border style ─────
    Rectangle {
        visible: _wrapper.visible && !_slideIn.running && !_slideOut.running
        x: _panel.width - _panel.panelWidth - _panel.panelMarginRight - 20 + _body.x
        y: _panel.panelMarginTop - 20
        width:  _panel.panelWidth + 40
        height: _panel.panelHeight + 40
        color:  "transparent"

        layer.enabled: !_slideIn.running && !_slideOut.running
        layer.effect: MultiEffect {
            blurEnabled: true
            blur:        0.6
            blurMax:     32
        }

        // Thin border at panel coords — blurred outward to form the glow
        Rectangle {
            x: 20; y: 20
            width:  _panel.panelWidth
            height: _panel.panelHeight
            radius: 10
            color:  "transparent"
            border.width: 4
            border.color: Qt.rgba(0, 0, 0, 0.85)
        }
    }

    // ─── Clip container at right edge ─────────────────────
    Item {
        id: _wrapper
        property bool containsMouse: false
        visible: false

        x: _panel.width - _panel.panelWidth - _panel.panelMarginRight
        y: _panel.panelMarginTop
        width:  _panel.panelWidth
        height: _panel.panelHeight
        clip:   true

        // Hover guard — containsMouse prevents click-outside firing inside panel
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            z: 0
            onEntered: _wrapper.containsMouse = true
            onExited:  _wrapper.containsMouse = false
            onClicked: event => event.accepted = true
        }

        // ── Panel body ────────────────────────────────────
        Rectangle {
            id: _body
            y: 0
            width:  _panel.panelWidth
            height: _panel.panelHeight
            color:  _panel.panelColor
            radius: 8
            border.width: 2
            border.color: _wrapper.containsMouse ? _panel.accentColor : Colors.col_main
            Behavior on border.color { ColorAnimation { duration: 200 } }
            opacity: _wrapper.containsMouse ? 0.95 : 0.85
            Behavior on opacity { NumberAnimation { duration: 200 } }

            // ── Content area ──────────────────────────────
            Item {
                id: _contentArea
                x: 0
                y: 0
                width:  parent.width
                height: parent.height
                clip:   true
            }
        }

        // ─── Slide animations ─────────────────────────────
        NumberAnimation {
            id: _slideIn
            target: _body
            property: "x"
            from: _panel.panelWidth
            to:   0
            duration: _panel.openDuration
            easing.type: Easing.OutCubic
            onFinished: _panel._panelFullyOpen = true
        }

        NumberAnimation {
            id: _slideOut
            target: _body
            property: "x"
            from: 0
            to:   _panel.panelWidth
            duration: _panel.closeDuration
            easing.type: Easing.InCubic
            onFinished: {
                _wrapper.visible = false
                _panel._reserveSpace = false  // Reset exclusiveZone after slide completes
            }
        }
    }
}
