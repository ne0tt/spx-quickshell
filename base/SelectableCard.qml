import QtQuick

// ============================================================
// SELECTABLE CARD — shared active-card widget used by
// VlanDropdown, VPNDropdown and PowerProfileDropdown.
//
// Props:
//   isActive         — highlight / selected state
//   isBusy           — disables click while a command is in-flight
//   cardIcon         — nerd-font / unicode glyph for the left circle
//   label            — primary text (bold, 13 px)
//   subtitle         — secondary text below label (10 px); hidden when ""
//   isPanelOpen      — drives the status-dot pulse animation
//   accentColor      — primary accent (from DropdownBase)
//   textColor        — primary text colour (from DropdownBase)
//   dimColor         — inactive / muted colour (from DropdownBase)
//   dotActiveColor   — dot colour when active (default: accentColor)
//
// Flash animation tuning (override per-instance if needed):
//   flashLoops       — default 3
//   flashOpacityLow  — default 0.25
//   flashDuration    — ms per step, default 120
//
// Signals:
//   clicked          — emitted when the (non-busy) card is clicked
//
// Methods:
//   flash()          — trigger the flash animation from outside
// ============================================================
Item {
    id: card
    width: parent ? parent.width : 0
    height: 48

    // ── Public API ────────────────────────────────────────────
    property bool   isActive:        false
    property bool   isBusy:          false
    property string cardIcon:        ""
    property string label:           ""
    property string subtitle:        ""
    property bool   isPanelOpen:     false
    property string fontFamily:      config.fontFamily

    property color  accentColor:     "white"
    property color  textColor:       "white"
    property color  dimColor:        "#888888"
    property color  dotActiveColor:  accentColor
    property int    holdDuration:    0
    property real   holdProgress:    0
    property real   _borderOpacity:  1.0
    property bool   _pendingClickAfterFlash: false
    property bool   _holdActive:     false

    readonly property bool holdEnabled: holdDuration > 0
    readonly property bool _selected:  isActive || _holdActive
    property bool   holdTriggered:   false

    // Flash tuning
    property int    flashLoops:      3
    property real   flashOpacityLow: 0.25
    property int    flashDuration:   120

    signal clicked

    onIsPanelOpenChanged: {
        if (!isPanelOpen) {
            _flashAnim.stop()
            card.opacity = 1.0
            resetHoldState()
        }
    }

    // Public: trigger the connect / activate flash
    function flash() { _flashAnim.start() }
    function resetHoldState() {
        _holdProgressAnim.stop()
        _borderFlashAnim.stop()
        _holdActiveTimer.stop()
        holdProgress = 0
        holdTriggered = false
        _pendingClickAfterFlash = false
        _holdActive = false
        _borderOpacity = 1.0
    }

    // ── Border flash animation (fires after hold completes) ────
    SequentialAnimation {
        id: _borderFlashAnim
        running: false
        loops: 3
        PropertyAnimation { target: card; property: "_borderOpacity"; to: 0.0; duration: 80 }
        PropertyAnimation { target: card; property: "_borderOpacity"; to: 1.0; duration: 80 }
        onStopped: {
            card._borderOpacity = 1.0
            if (card._pendingClickAfterFlash) {
                card._pendingClickAfterFlash = false
                card._holdActive = true
                card.clicked()
                _holdActiveTimer.start()
            }
        }
    }

    Timer {
        id: _holdActiveTimer
        interval: 1000
        repeat: false
        onTriggered: {
            card._holdActive = false
        }
    }

    // ── Flash animation ───────────────────────────────────────
    SequentialAnimation {
        id: _flashAnim
        running: false
        loops: card.flashLoops
        PropertyAnimation { target: card; property: "opacity"; to: card.flashOpacityLow; duration: card.flashDuration }
        PropertyAnimation { target: card; property: "opacity"; to: 1.0;                 duration: card.flashDuration }
        onStopped: card.opacity = 1.0
    }

    NumberAnimation {
        id: _holdProgressAnim
        target: card
        property: "holdProgress"
        from: 0
        to: 1
        duration: card.holdDuration
    }

    // ── Card background ───────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        clip: true
        radius: 10
        color: card._selected
            ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.13)
            : Qt.rgba(0, 0, 0, 0.18)
        border.color: card._selected
            ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.40)
            : Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        Behavior on color        { ColorAnimation { duration: 260 } }
        Behavior on border.color { ColorAnimation { duration: 260 } }

        Canvas {
            id: _holdBorder
            anchors.fill: parent
            visible: card.holdEnabled && card.holdProgress > 0
            opacity: card._borderOpacity
            antialiasing: true

            onVisibleChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            Connections {
                target: card

                function onHoldProgressChanged() { _holdBorder.requestPaint() }
                function onAccentColorChanged() { _holdBorder.requestPaint() }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()

                if (!visible)
                    return

                var strokeWidth = 2
                var radius = 10
                var inset = strokeWidth / 2
                var left = inset
                var top = inset
                var right = width - inset
                var bottom = height - inset
                var innerWidth = Math.max(0, right - left)
                var innerHeight = Math.max(0, bottom - top)
                var clampedRadius = Math.min(radius, innerWidth / 2, innerHeight / 2)
                var straightTop = Math.max(0, innerWidth - 2 * clampedRadius)
                var straightSide = Math.max(0, innerHeight - 2 * clampedRadius)
                var cornerLength = Math.PI * clampedRadius / 2
                var perimeter = 2 * straightTop + 2 * straightSide + 4 * cornerLength
                var remaining = perimeter * card.holdProgress

                function strokeCurrentPath() {
                    ctx.strokeStyle = Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.95)
                    ctx.lineWidth = strokeWidth
                    ctx.lineCap = "round"
                    ctx.stroke()
                }

                function arcPoint(cx, cy, angle) {
                    return {
                        x: cx + clampedRadius * Math.cos(angle),
                        y: cy + clampedRadius * Math.sin(angle)
                    }
                }

                function drawLine(x1, y1, x2, y2, length) {
                    if (remaining <= 0 || length <= 0)
                        return

                    var take = Math.min(remaining, length)
                    var ratio = take / length
                    ctx.beginPath()
                    ctx.moveTo(x1, y1)
                    ctx.lineTo(x1 + (x2 - x1) * ratio, y1 + (y2 - y1) * ratio)
                    strokeCurrentPath()
                    remaining -= take
                }

                function drawArc(cx, cy, startAngle, endAngle, length) {
                    if (remaining <= 0 || length <= 0)
                        return

                    var take = Math.min(remaining, length)
                    var ratio = take / length
                    var sweep = endAngle - startAngle
                    var currentEnd = startAngle + sweep * ratio
                    var startPoint = arcPoint(cx, cy, startAngle)
                    ctx.beginPath()
                    ctx.moveTo(startPoint.x, startPoint.y)
                    ctx.arc(cx, cy, clampedRadius, startAngle, currentEnd, false)
                    strokeCurrentPath()
                    remaining -= take
                }

                // Start from the vertical midpoint of the right edge, going clockwise
                var midRightY = top + clampedRadius + straightSide / 2

                drawLine(right, midRightY, right, bottom - clampedRadius, straightSide / 2)
                drawArc(right - clampedRadius, bottom - clampedRadius, 0, Math.PI / 2, cornerLength)
                drawLine(right - clampedRadius, bottom, left + clampedRadius, bottom, straightTop)
                drawArc(left + clampedRadius, bottom - clampedRadius, Math.PI / 2, Math.PI, cornerLength)
                drawLine(left, bottom - clampedRadius, left, top + clampedRadius, straightSide)
                drawArc(left + clampedRadius, top + clampedRadius, Math.PI, 3 * Math.PI / 2, cornerLength)
                drawLine(left + clampedRadius, top, right - clampedRadius, top, straightTop)
                drawArc(right - clampedRadius, top + clampedRadius, -Math.PI / 2, 0, cornerLength)
                drawLine(right, top + clampedRadius, right, midRightY, straightSide / 2)
            }
        }

        // ── Left circle icon ──────────────────────────────────
        Rectangle {
            id: _iconCircle
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            width: 32; height: 32; radius: 16
            color: card._selected
                ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.22)
                : Qt.rgba(1, 1, 1, 0.05)
            border.color: card._selected
                ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.55)
                : Qt.rgba(1, 1, 1, 0.10)
            border.width: 1
            Behavior on color        { ColorAnimation { duration: 260 } }
            Behavior on border.color { ColorAnimation { duration: 260 } }

            Text {
                anchors.centerIn: parent
                text: card.cardIcon
                font.family: card.fontFamily
                font.pixelSize: 19
                color: card._selected
                    ? card.accentColor
                    : Qt.rgba(card.dimColor.r, card.dimColor.g, card.dimColor.b, 0.40)
                Behavior on color { ColorAnimation { duration: 260 } }
            }
        }

        // ── Center: label + subtitle ──────────────────────────
        Column {
            anchors {
                left: _iconCircle.right
                right: _dot.left
                leftMargin: 12
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            spacing: 3

            Text {
                text: card.label
                width: parent.width
                font.pixelSize: 13
                font.bold: true
                wrapMode: Text.NoWrap
                maximumLineCount: 1
                elide: Text.ElideRight
                color: card._selected
                    ? card.textColor
                    : Qt.rgba(card.dimColor.r, card.dimColor.g, card.dimColor.b, 0.55)
                Behavior on color { ColorAnimation { duration: 260 } }
            }
            Text {
                visible: card.subtitle !== ""
                text:    card.subtitle
                width: parent.width
                font.pixelSize: 12
                wrapMode: Text.NoWrap
                maximumLineCount: 1
                elide: Text.ElideRight
                color: card._selected
                    ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.85)
                    : Qt.rgba(card.dimColor.r,    card.dimColor.g,    card.dimColor.b,    0.30)
                Behavior on color { ColorAnimation { duration: 260 } }
            }
        }

        // ── Right: status dot ─────────────────────────────────
        Rectangle {
            id: _dot
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            width: 8; height: 8; radius: 4
            color: card._selected ? card.dotActiveColor : Qt.rgba(1, 1, 1, 0.10)
            Behavior on color { ColorAnimation { duration: 260 } }

            SequentialAnimation {
                running: card._selected && card.isPanelOpen && !card.holdEnabled
                loops: Animation.Infinite
                NumberAnimation { target: _dot; property: "opacity"; to: 0.25; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { target: _dot; property: "opacity"; to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                onStopped: _dot.opacity = 1.0
            }

            SequentialAnimation {
                running: card.holdEnabled && card.holdProgress > 0 && !card.holdTriggered
                loops: Animation.Infinite
                PropertyAction  { target: _dot; property: "color"; value: card.accentColor }
                ColorAnimation  { target: _dot; property: "color"; to: Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.15); duration: 300; easing.type: Easing.InOutSine }
                ColorAnimation  { target: _dot; property: "color"; to: card.accentColor; duration: 300; easing.type: Easing.InOutSine }
                onStopped: _dot.color = card._selected ? card.dotActiveColor : Qt.rgba(1, 1, 1, 0.10)
            }
        }

        // ── Click handler ─────────────────────────────────────
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            enabled: !card.isBusy
            pressAndHoldInterval: card.holdEnabled ? card.holdDuration : 800
            onPressed: {
                if (!card.holdEnabled)
                    return

                card.holdTriggered = false
                card.holdProgress = 0
                _holdProgressAnim.restart()
            }
            onReleased: {
                if (!card.holdEnabled)
                    return

                card.resetHoldState()
            }
            onCanceled: card.resetHoldState()
            onClicked: {
                if (!card.holdEnabled)
                    card.clicked()
            }
            onPressAndHold: {
                if (!card.holdEnabled)
                    return

                card.holdTriggered = true
                card.holdProgress = 1
                card._pendingClickAfterFlash = true
                _borderFlashAnim.start()
            }
        }
    }
}
