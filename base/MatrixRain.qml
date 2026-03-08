// base/MatrixRain.qml
// Animated Matrix-style digital rain canvas.
//
// Usage:
//   MatrixRain {
//       width:  400
//       height: 200
//       running: true    // toggle the animation on/off
//   }
//
// Public API:
//   running        — start/stop the animation (default true)
//   charColor      — leading character color  (default col_source_color)
//   tailMin        — shortest trail length in rows (default 6)
//   tailMax        — longest  trail length in rows (default 28)
//   cascadeSpeed   — base rows advanced per tick (default 0.8)
//   speedVariation — max random deviation from cascadeSpeed (default 0.4)
//   fontSize       — glyph size in px         (default 12)
//   speed          — ms per frame             (default 50 = ~20 fps)
//   density        — fraction of columns active (0.0–1.0, default 1.0)

import QtQuick

Item {
    id: root

    // ============================================================
    // PUBLIC PROPERTIES
    // ============================================================
    property bool   running:        true
    property color  charColor:      colors.col_source_color   // bright leading glyph
    property int    tailMin:        26           // shortest trail (rows)
    property int    tailMax:        48          // longest  trail (rows)
    property real   cascadeSpeed:   0.5      // base rows advanced per tick
    property real   speedVariation: 0.4         // ± random deviation per column
    property int    fontSize:       11
    property int    speed:          50          // ms per tick (~20 fps)
    property real   density:        1.0         // 0.0 = no columns, 1.0 = all columns active

    // ============================================================
    // INTERNALS
    // ============================================================

    // Katakana + ASCII block used in the film
    readonly property string _glyphs:
        "\u30A2\u30A4\u30A6\u30A8\u30AA\u30AB\u30AC\u30AD\u30AE\u30AF" +
        "\u30B3\u30B5\u30B6\u30B7\u30B8\u30B9\u30BA\u30BB\u30BC\u30BD" +
        "\u30BF\u30C0\u30C1\u30C2\u30C3\u30C4\u30C5\u30C6\u30C7\u30C8" +
        "\u30CB\u30CC\u30CD\u30CE\u30CF\u30D0\u30D1\u30D2\u30D3\u30D4" +
        "\u30D8\u30D9\u30DA\u30DB\u30DC\u30DD\u30DE\u30DF\u30E0\u30E1" +
        "\u30E2\u30E4\u30E6\u30E8\u30E9\u30EA\u30EB\u30EC\u30ED\u30EF" +
        "\u30F2\u30F3" +
        "012345789:Z"

    // drops[i]    = current row index for column i (fractional)
    // _speeds[i]  = per-column speed multiplier
    // _tailLens[i]= per-column trail length in rows
    // _fades[i]   = per-column destination-out opacity per frame
    property var _drops:    []
    property var _speeds:   []
    property var _tailLens: []
    property var _fades:    []

    // ============================================================
    // CANVAS
    // ============================================================
    Canvas {
        id: canvas
        anchors.fill: parent

        // Reinitialise columns whenever size changes
        onWidthChanged:  root._initDrops()
        onHeightChanged: root._initDrops()

        onPaint: {
            var ctx = getContext("2d")
            var cols = Math.floor(width  / root.fontSize)
            var rows = Math.floor(height / root.fontSize)

            if (root._drops.length !== cols) {
                root._initDrops()
                return
            }

            var fs    = root.fontSize
            var gl    = root._glyphs
            var glLen = gl.length

            var drops    = root._drops
            var tailLens = root._tailLens
            var fades    = root._fades
            var cy       = root.charColor
            var cr = Math.round(cy.r * 255)
            var cg = Math.round(cy.g * 255)
            var cb = Math.round(cy.b * 255)

            // ── Pass 1: per-column fade strips + hard tail erase ─────
            ctx.globalCompositeOperation = "destination-out"
            for (var i = 0; i < cols; i++) {
                if (root._speeds[i] === 0) continue
                ctx.fillStyle = "rgba(0,0,0," + fades[i] + ")"
                ctx.fillRect(i * fs, 0, fs, height)
                // Hard erase at the tail boundary so it fully disappears
                var tailY = (Math.floor(drops[i]) - tailLens[i]) * fs
                if (tailY >= 0) ctx.clearRect(i * fs, tailY, fs, fs + 1)
            }

            // ── Pass 2: draw characters ───────────────────────────────
            ctx.globalCompositeOperation = "source-over"
            ctx.font         = "bold " + fs + "px monospace"
            ctx.textAlign    = "center"
            ctx.textBaseline = "top"

            for (var j = 0; j < cols; j++) {
                if (root._speeds[j] === 0) continue

                var row = drops[j]
                var x   = j * fs + fs * 0.5
                var y   = row * fs

                // Leading character — bright white-green flash
                ctx.fillStyle = "rgba(200, 255, 200, 0.95)"
                ctx.fillText(gl.charAt(Math.floor(Math.random() * glLen)), x, y)

                // Second character — primary accent color
                if (row > 0) {
                    ctx.fillStyle = "rgba(" + cr + "," + cg + "," + cb + ", 0.85)"
                    ctx.fillText(gl.charAt(Math.floor(Math.random() * glLen)), x, (row - 1) * fs)
                }

                // Advance the drop; reset randomly once past the bottom
                drops[j] = (y > height && Math.random() > 0.975) ? 0 : row + root._speeds[j]
            }

            root._drops = drops
        }
    }

    // ============================================================
    // TIMER — drives repaints at `speed` ms intervals
    // ============================================================
    Timer {
        id: ticker
        interval: root.speed
        repeat:   true
        running:  root.running && root.visible && root.width > 0 && root.height > 0
        onTriggered: canvas.requestPaint()
    }

    // ============================================================
    // HELPERS
    // ============================================================
    function _initDrops() {
        if (width <= 0 || height <= 0) return
        var cols = Math.floor(width  / fontSize)
        var rows = Math.floor(height / fontSize)
        var arr      = new Array(cols)
        var speeds   = new Array(cols)
        var tailLens = new Array(cols)
        var fades    = new Array(cols)
        for (var i = 0; i < cols; i++) {
            if (Math.random() >= root.density) {
                // Inactive column — parked far above screen, never advances
                arr[i]      = -(rows * 10)
                speeds[i]   = 0
                tailLens[i] = root.tailMin
                fades[i]    = 0
            } else {
                arr[i]    = -Math.floor(Math.random() * rows)
                speeds[i] = Math.max(0.1, root.cascadeSpeed + (Math.random() * 2 - 1) * root.speedVariation)
                // Random tail length; fade speed inversely proportional so longer tails fade slower
                var tl      = root.tailMin + Math.floor(Math.random() * (root.tailMax - root.tailMin + 1))
                tailLens[i] = tl
                fades[i]    = Math.max(0.04, 2.5 / tl)
            }
        }
        _drops    = arr
        _speeds   = speeds
        _tailLens = tailLens
        _fades    = fades
        // Clear canvas to fully transparent before the first tick
        if (canvas.available) {
            var ctx = canvas.getContext("2d")
            if (ctx) ctx.clearRect(0, 0, width, height)
        }
    }

    Component.onCompleted: _initDrops()

    // Re-init once the canvas context becomes available (fires after Component.onCompleted)
    Connections {
        target: canvas
        function onAvailableChanged() { if (canvas.available) root._initDrops() }
    }

    // Re-init if properties that affect column layout change
    onFontSizeChanged: _initDrops()
    onDensityChanged:  _initDrops()
    onTailMinChanged:  _initDrops()
    onTailMaxChanged:  _initDrops()
}
