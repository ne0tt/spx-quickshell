import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import ".."
// ============================================================
// DROPDOWN BASE — shared boilerplate for all drop-down panels.
//
// Layout (top → bottom, all inside the animated _wrapper):
//
//   ┌─────────────────────────────────────────────────────┐  ← y: barHeight-16
//   │  [ears]  DropdownTopFlare  (16 px, full wrapper w)   │
//   ├──────────────[inner panel body]─────────────────────┤  ← ear height
//   │  _panelHeader — icon + title row (headerHeight px)  │
//   │  (hidden when headerHeight == 0, default)           │
//   ├─────────────────────────────────────────────────────┤
//   │  _contentArea — dynamic height, clips children      │
//   │  panelContent alias → place your UI here            │
//   ├─────────────────────────────────────────────────────┤
//   │  _footerArea — footerHeight px, no margin/padding   │
//   │  Footer canvas (rounded bottom corners) + HexSweep  │
//   └─────────────────────────────────────────────────────┘
//
// Usage:
//   DropdownBase {
//       id: myDrop
//       reloadableId: "myDropdown"
//       implicitHeight: 400
//       panelFullHeight: 280   // content area height only
//       panelWidth: 270
//
//       // Optional panel header
//       panelTitle:       "My Panel"
//       panelIcon:        "󰌘"         // nerd-font glyph shown left of title
//       headerHeight:     36   // set > 0 to show the header row
//       // NOTE: add headerHeight to implicitHeight when using the panel header!
//
//       onAboutToOpen: myDrop.refresh()   // optional pre-fetch hook
//
//       // UI content — injected into _contentArea
//       Item { ... }
//       Process { id: myProc; ... }
//   }
//
// Subclasses that must defer the open animation (async fetch):
//   1.  override openPanel(), set panelVisible = true to arm isOpen
//   2.  call startOpenAnim() once the data is ready
// ============================================================
PanelWindow {
    id: _base

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    exclusiveZone: 0
    color: "transparent"

    // Sit above the Top-layer main bar so dropdowns always render over it
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: keyboardFocusEnabled && isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // When a panel is open the mask covers only below the bar so bar buttons
    // remain clickable. When closed, restrict to _wrapper (height 0).
    Item {
        id: _windowMask
        x: 0; y: _base.barHeight
        width: parent.width
        height: parent.height - _base.barHeight
    }
    mask: Region {
        item: _wrapper.visible ? _windowMask : _wrapper
    }

    // ─── Configurable props ───────────────────────────────
    // Theme defaults mirror shell.qml's colors object — override per-instance
    // only when a dropdown genuinely differs from the shell theme.
    property bool keyboardFocusEnabled: false
    property int barHeight: 50
    property int openDuration: 280   // roll-up animation speed (ms)
    property int closeDuration: 280  // roll-down animation speed (ms)
    property string fontFamily: config.fontFamily
    property color panelColor: Colors.col_main
    property int panelFullHeight: 200
    property int panelWidth: 260
    property int panelZ: 2000  // above the main bar (1000) but below the workspace glow (3000)
    property real panelX: 0
    property bool isOpen: _wrapper.visible
    property color borderColor: "black"
    property real borderWidth: 0
    property color accentColor: Colors.col_source_color
    property color textColor: Colors.col_primary
    property color dimColor: Qt.rgba(Colors.col_source_color.r, Colors.col_source_color.g, Colors.col_source_color.b, 0.45)

    // Lets subclasses that control animation timing arm isOpen
    property alias panelVisible: _wrapper.visible

    // ─── Panel header ─────────────────────────────────────
    // Set headerHeight > 0 to reveal the shared title/icon row.
    // Defaults to 0 so existing subclasses are unaffected.
    property int    headerHeight:      0
    property string panelTitle:        ""
    property string panelTitleRight:   ""  // optional right-aligned label in the header row
    property string panelIcon:         ""  // nerd-font / unicode glyph shown left of title
    property alias  headerContent: _panelHeader.data

    // ─── Footer ───────────────────────────────────────────
    // Always-visible zone at the very bottom — no margin or padding.
    // Default 32 = enough for just the hex sweep bar.
    property int footerHeight: 28
    property alias footerContent: _footerArea.data

    // ─── Content injection ────────────────────────────────
    // Children land in _contentArea (dynamic height).
    // Total open height = 16 (ears) + headerHeight + panelFullHeight + footerHeight.
    default property alias panelContent: _contentArea.data

    // ─── Signal: fired before open animation starts ───────
    signal aboutToOpen

    // ─── Hex sweep public API ─────────────────────────────
    function triggerHex() { _hexBar.trigger() }

    // ─── Open / Close API ────────────────────────────────
    function openPanel() {
        aboutToOpen();
        startOpenAnim();
    }

    function closePanel() {
        _openAnim.stop();
        _contentFadeIn.stop();
        _contentFadeDelay.stop();
        _contentFadeOut.restart();  // fade content out before the panel shrinks
        _hexFadeOut.restart();
        _closeAnim.from = _wrapper.height;
        _closeAnim.start();
    }

    // Subclasses with async open call this when data is ready
    function startOpenAnim() {
        _closeAnim.stop();
        _openAnim.stop();
        _hexFadeOut.stop();
        _hexBar.opacity      = 0;  // reset before first frame so no stale opacity flashes
        _contentArea.opacity = 0;  // content + header fade in partway through the expansion
        _contentFadeOut.stop();
        _contentFadeDelay.restart();  // fires ~160 ms in, overlaps the tail of _openAnim
        _hexFadeIn.restart();
        _wrapper.height = 0;
        _wrapper.visible = true;
        _openAnim.start();
    }

    // ─── Animations ──────────────────────────────────────
    NumberAnimation {
        id: _openAnim
        target: _wrapper
        property: "height"
        from: 0
        to: 16 + _base.headerHeight + _base.panelFullHeight + _base.footerHeight
        duration: _base.openDuration
        //easing.type: Easing.OutBack
        easing.type: Easing.OutCubic
        onFinished: {
            _hexBar.trigger()
        }
    }

    Timer {
        id: _contentFadeDelay
        interval: openDuration / 3 
        repeat: false
        onTriggered: _contentFadeIn.restart()
    }

    NumberAnimation {
        id: _hexFadeIn
        target: _hexBar
        property: "opacity"
        from: 0; to: 1
        duration: _base.openDuration
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: _hexFadeOut
        target: _hexBar
        property: "opacity"
        from: 1; to: 0
        duration: _base.closeDuration
        easing.type: Easing.InOutCubic
    }

    NumberAnimation {
        id: _contentFadeIn
        target: _contentArea
        property: "opacity"
        from: 0; to: 1
        duration: openDuration
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: _contentFadeOut
        target: _contentArea
        property: "opacity"
        from: 1; to: 0
        duration: closeDuration
        easing.type: Easing.InOutCubic
    }

    // Live resize when panelFullHeight or footerHeight changes while the panel is open
    onPanelFullHeightChanged: {
        if (_wrapper.visible && !_closeAnim.running)
            _base.resizePanel()
    }
    onFooterHeightChanged: {
        if (_wrapper.visible && !_closeAnim.running)
            _base.resizePanel()
    }
    onHeaderHeightChanged: {
        if (_wrapper.visible && !_closeAnim.running)
            _base.resizePanel()
    }

    // Public API — call this from subclasses to force an immediate resize
    function resizePanel() {
        _openAnim.stop()
        _resizeAnim.stop()
        _resizeAnim.from = _wrapper.height
        _resizeAnim.to   = 16 + _base.headerHeight + _base.panelFullHeight + _base.footerHeight
        _resizeAnim.start()
    }

    NumberAnimation {
        id: _resizeAnim
        target: _wrapper
        property: "height"
        duration: 200
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: _closeAnim
        target: _wrapper
        property: "height"
        to: 0
        duration: _base.closeDuration
        easing.type: Easing.InOutCubic
        onFinished: _wrapper.visible = false
    }

    // ─── Close-outside overlay ────────────────────────────
    MouseArea {
        anchors.fill: parent
        z: _base.panelZ - 1
        visible: _wrapper.visible
        propagateComposedEvents: true
        onClicked: {
            if (!_wrapper.containsMouse)
                _base.closePanel();
        }
    }

    // ─── Drop shadow (sibling so blur escapes _wrapper clip) ─
    Item {
        id: _shadowItem
        visible: _wrapper.visible
        // Fade with the hex bar so MultiEffect has time to initialize
        // before the shadow is visible — prevents the 1-frame black flash.
        opacity: _hexBar.opacity
        x: _wrapper.x
        y: _wrapper.y +3
        z: _base.panelZ - 1
        width: _wrapper.width
        height: _wrapper.height

        // Shadow: unified body (header + content + footer) — flat top, rounded bottom
        Rectangle {
            x: 14; y: 6
            width: _base.panelWidth +4
            height: Math.max(0, parent.height - 6)
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: 19
            bottomRightRadius: 19
            color: "black"
            opacity: 0.6
            layer.enabled: !_openAnim.running && !_closeAnim.running
            layer.effect: MultiEffect {
                blurEnabled: true
                blur:    0.6
                blurMax: 16
            }
        }
    }

    // ─── Content wrapper ─────────────────────────────────
    Item {
        id: _wrapper
        property bool containsMouse: false
        visible: false

        x: _base.panelX
        y: _base.barHeight
        z: _base.panelZ
        width: _base.panelWidth + 32
        height: 0
        clip: true

        // Hover tracking — containsMouse guards the close-outside overlay
        MouseArea {
            x: 16
            y: 16
            width: _base.panelWidth
            height: Math.max(0, _wrapper.height)
            hoverEnabled: true
            onEntered: _wrapper.containsMouse = true
            onExited: _wrapper.containsMouse = false
            onClicked: event => event.accepted = true
        }

        // ── 1. TOP EARS ──────────────────────────────────────
        // Flared ear strip: full wrapper width, 16 px tall.
        DropdownTopFlare {
            id: _earsCanvas
            x: 0; y: 0
            width: parent.width
            height: 16
            fillColor: _base.panelColor
            borderColor: _base.borderColor
            borderWidth: _base.borderWidth
            clip: true
        }

        // ── 2. UNIFIED BODY BACKGROUND ───────────────────────
        // Flat top (connects flush with ears), rounded bottom corners.
        // Rectangle avoids Canvas requestPaint() deferral that caused flicker.
        Rectangle {
            id: _bodyBg
            x: 16; y: 0
            width:  _base.panelWidth
            height: _wrapper.height
            z: 0
            color: _base.panelColor
            topLeftRadius:     0
            topRightRadius:    0
            bottomLeftRadius:  16
            bottomRightRadius: 16
            // Optional border overlay
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 16 //drop it down to bottom of ears, so border doesn't draw over them
                topLeftRadius:     0
                topRightRadius:    0
                bottomLeftRadius:  16
                bottomRightRadius: 16
                color: "transparent"
                border.color: _base.borderColor
                border.width: _base.borderWidth
                visible: _base.borderWidth > 0
            }
        }

        // ── 3. PANEL HEADER ──────────────────────────────────
        // Icon + title row. Hidden (height 0) by default.
        // 10 px left/right margin applied to inner content.
        Item {
            id: _panelHeader
            x: 16; y: 16
            z: 1
            width: _base.panelWidth
            height: _base.headerHeight
            visible: _base.headerHeight > 0
            clip: true
            opacity: 1

            // Icon glyph — shown when panelIcon is set
            Text {
                id: _headerIcon
                anchors.left: parent.left
                anchors.leftMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                text: _base.panelIcon
                font.pixelSize: 24
                color: Qt.rgba(_base.accentColor.r, _base.accentColor.g, _base.accentColor.b, 1.0)
                visible: _base.panelIcon !== ""
            }

            Text {
                id: _headerTitle
                anchors.left: _headerIcon.visible ? _headerIcon.right : parent.left
                anchors.leftMargin: 10
                anchors.right: _headerTitleRight.visible ? _headerTitleRight.left : parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: _base.panelTitle
                color: _base.textColor
                font.pixelSize: 18
                font.weight: Font.Medium
                elide: Text.ElideRight
                visible: _base.panelTitle !== ""
                
            }

            Text {
                id: _headerTitleRight
                anchors.right: parent.right
                anchors.rightMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                text: _base.panelTitleRight
                color: _base.textColor
                font.pixelSize: 18
                font.weight: Font.Medium
                visible: _base.panelTitleRight !== ""
            }
        }

        // ── 4. CONTENT WRAPPER ───────────────────────────────
        // Starts at y:0 — same origin as the original layout.
        // Subclasses use y: 16+N in their children to clear the ear zone
        // (and y: 16+headerHeight+N when a header is active).
        // Height reserves the footer at the bottom, identical to old formula.
        Item {
            id: _contentArea
            x: 0
            y: 0
            z: 1
            width: _wrapper.width
            height: Math.max(0, _wrapper.height - _base.footerHeight)
            clip: true
        }

        // ── 5. FOOTER ────────────────────────────────────────
        // Fixed height, anchored to wrapper bottom.
        // Sits within the unified body background — no separate fill.
        // Hex sweeper has 10 px left/right margin.
        // Clicking anywhere in the footer rolls up the panel.
        Item {
            id: _footerArea
            x: 16
            anchors.bottom: parent.bottom
            z: 1
            width: _base.panelWidth
            height: _base.footerHeight

            HexSweepPanel {
                id: _hexBar
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -5
                width: parent.width - 30
                height: 12
                z: 100
                backgroundColor: Colors.col_background
                borderColor: "black"
                glowColor: _base.accentColor
                trailColor: _base.accentColor
                ambientColor: Colors.col_main
                sweepDuration: 1000
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                z: 101
                onClicked: _base.closePanel()
            }
        }
    }

}
