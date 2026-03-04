// components/HexSweepPanel.qml
// Animated hex-grid backlit bar. Call trigger() to run the sweep once.

import QtQuick

Rectangle {
    id: hexBox

    // ============================================================
    // PUBLIC PROPERTIES
    // ============================================================
    property color backgroundColor: "#000000"
    property color borderColor:     "black"
    property color glowColor:       "#ffffff"   // leading crest color (col_primary)
    property color trailColor:      "#C47FD5"   // trailing glow color (purple)
    property color ambientColor:    "#222222"   // resting hex color (col_on_secondary)
    property int   sweepDuration:   1000        // ms for one full sweep
    property bool  mirrored:        false       // true = sweep runs right to left

    // ============================================================
    // PUBLIC API
    // ============================================================
    function trigger() { hexAnim.restart() }

    // ============================================================
    // BOX STYLE
    // ============================================================
    radius:       7
    color:        backgroundColor
    border.color: borderColor
    border.width: 1

    // ============================================================
    // CANVAS
    // ============================================================
    Canvas {
        id: hexCanvas
        anchors.fill: parent

        layer.enabled: false
        layer.smooth: false

        property real sweepX:      -0.25
        property bool animRunning: false

        // ── Geometry cache ─────────────────────────────────────
        // All constants recomputed only when size changes, not every frame.
        readonly property real hexR:     12
        readonly property real hW:       hexR * Math.sqrt(3)   // pointy-top hex width
        readonly property real colStep:  hW
        readonly property real rowStep:  hexR * 2 * 0.75
        readonly property real rad47:    47 * Math.PI / 180
        readonly property real cos47:    Math.cos(rad47)
        readonly property real sin47:    Math.sin(rad47)

        // Size-dependent geometry – recomputed in recomputeGeometry()
        property int  gPad:  0
        property int  gCols: 0
        property int  gRows: 0
        property var  gVx:   []
        property var  gVy:   []

        // Pre-allocated lit-band arrays — avoids per-frame GC churn
        property var  litCxBuf:   new Array(32)
        property var  litCyBuf:   new Array(32)
        property var  litDiffBuf: new Array(32)

        // Pre-built ambient strokeStyle string (rebuilt when ambientColor changes)
        property string ambientStyle: {
            var r = Math.round(hexBox.ambientColor.r * 255)
            var g = Math.round(hexBox.ambientColor.g * 255)
            var b = Math.round(hexBox.ambientColor.b * 255)
            return "rgba(" + r + "," + g + "," + b + ",0.18)"
        }

        function recomputeGeometry() {
            var pad  = Math.ceil(Math.sqrt(width * width + height * height) * 0.5)
            gPad  = pad
            gCols = Math.ceil((width  + pad * 2) / colStep) + 2
            gRows = Math.ceil((height + pad * 2) / rowStep) + 2
            var vxTmp = [], vyTmp = []
            for (var vi = 0; vi < 6; vi++) {
                var va = Math.PI / 3 * vi - Math.PI / 6
                vxTmp[vi] = hexR * Math.cos(va)
                vyTmp[vi] = hexR * Math.sin(va)
            }
            gVx = vxTmp
            gVy = vyTmp
        }

        SequentialAnimation {
            id: hexAnim
            loops:   1
            running: false
            PropertyAction  { target: hexCanvas; property: "sweepX"; value: -0.25 }
            NumberAnimation { target: hexCanvas; property: "sweepX"; from: -0.25; to: 2.0; duration: hexBox.sweepDuration; easing.type: Easing.Linear }
        }

        Connections {
            target: hexAnim
            function onRunningChanged() {
                hexCanvas.animRunning = hexAnim.running
                paintTimer.running = hexAnim.running
                if (!hexAnim.running) hexCanvas.requestPaint()
            }
        }

        // ~20 fps cap during animation — halves CPU vs vsync-driven repaints
        Timer {
            id: paintTimer
            interval: 50
            repeat:   true
            running:  false
            onTriggered: hexCanvas.requestPaint()
        }

        onAmbientStyleChanged: requestPaint()
        function _onResize() { recomputeGeometry(); requestPaint() }
        onWidthChanged:  Qt.callLater(_onResize)
        onHeightChanged: Qt.callLater(_onResize)

        Component.onCompleted: recomputeGeometry()

        onPaint: {
            if (!animRunning && sweepX > 1.5) return

            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // ── Unpack cached geometry ──────────────────────────
            var tileW    = width
            var Rv       = hexR
            var c47      = cos47
            var s47      = sin47
            var cStep    = colStep
            var rStep    = rowStep
            var hWv      = hW
            var pad      = gPad
            var cols     = gCols
            var rows     = gRows
            var vxArr    = gVx
            var vyArr    = gVy

            // ── Color components ───────────────────────────────
            var cr  = hexBox.glowColor.r
            var cg  = hexBox.glowColor.g
            var cb  = hexBox.glowColor.b
            var tr  = hexBox.trailColor.r
            var tgc = hexBox.trailColor.g
            var tb  = hexBox.trailColor.b
            var br  = hexBox.ambientColor.r
            var bgc = hexBox.ambientColor.g
            var bb  = hexBox.ambientColor.b

            ctx.save()
            ctx.beginPath()
            ctx.rect(0, 0, tileW, height)
            ctx.clip()

            ctx.translate(tileW * 0.5, height * 0.5)
            ctx.rotate(rad47)
            ctx.translate(-tileW * 0.5, -height * 0.5)

            ctx.lineWidth = 0.9

            // Per-side thresholds:
            //   lead  (diff>0): exp(-dd/0.03) < 0.01 when dd > 0.138
            //   trail (diff<0): exp(-dd/0.15) < 0.01 when dd > 0.69
            var LeadThresh  = 0.138
            var TrailThresh = 0.69

            // Reuse pre-allocated buffers — no per-frame array allocation
            var litCx   = litCxBuf
            var litCy   = litCyBuf
            var litDiff = litDiffBuf
            var litLen  = 0

            // ── Single-path batch for all ambient hexes ─────────
            ctx.strokeStyle = ambientStyle
            ctx.beginPath()

            for (var row = -1; row < rows; row++) {
                for (var col = -1; col < cols; col++) {
                    var cx = col * cStep + (row % 2 === 0 ? 0 : hWv * 0.5) - pad
                    var cy = row * rStep - pad
                    var dx = cx - tileW * 0.5
                    var dy = cy - height * 0.5

                    // Screen-space cull
                    var screenX = dx * c47 - dy * s47 + tileW * 0.5
                    var screenY = dx * s47 + dy * c47 + height * 0.5
                    if (screenX < -Rv || screenX > tileW + Rv) continue
                    if (screenY < -Rv || screenY > height + Rv) continue

                    var nx   = (mirrored ? 1.0 - screenX / tileW : screenX / tileW)
                    var diff = nx - sweepX
                    var dd   = diff * diff
                    var thresh = (diff > 0) ? LeadThresh : TrailThresh

                    if (dd > thresh) {
                        // ── Ambient: add to batch path ──────────
                        ctx.moveTo(cx + vxArr[0], cy + vyArr[0])
                        for (var i = 1; i < 6; i++) ctx.lineTo(cx + vxArr[i], cy + vyArr[i])
                        ctx.closePath()
                    } else {
                        // ── Lit band: defer for individual draw ─
                        litCx[litLen]   = cx
                        litCy[litLen]   = cy
                        litDiff[litLen] = diff
                        litLen++
                    }
                }
            }
            ctx.stroke()  // one flush for all ambient hexes

            // ── Individual draws for the lit band (~5-10 hexes) ─
            // Lead: tight Gaussian at crest → primary (glowColor)
            // Trail: wide Gaussian, only behind crest → purple (trailColor)
            for (var j = 0; j < litLen; j++) {
                var dj    = litDiff[j]
                var ddj   = dj * dj
                var lAlpha = Math.exp(-ddj / 0.03)
                var tAlpha = (dj < 0) ? Math.exp(-ddj / 0.15) * (1.0 - lAlpha) : 0.0
                var aAlpha = 1.0 - lAlpha - tAlpha
                var ri  = Math.round((aAlpha*br  + lAlpha*cr  + tAlpha*tr)  * 255)
                var gi  = Math.round((aAlpha*bgc + lAlpha*cg  + tAlpha*tgc) * 255)
                var bi  = Math.round((aAlpha*bb  + lAlpha*cb  + tAlpha*tb)  * 255)
                ctx.strokeStyle = "rgba(" + ri + "," + gi + "," + bi + "," + (0.18 + Math.max(lAlpha, tAlpha) * 0.72).toFixed(2) + ")"
                ctx.beginPath()
                ctx.moveTo(litCx[j] + vxArr[0], litCy[j] + vyArr[0])
                for (var ii = 1; ii < 6; ii++) ctx.lineTo(litCx[j] + vxArr[ii], litCy[j] + vyArr[ii])
                ctx.closePath()
                ctx.stroke()
            }

            ctx.restore()
        }
    }
}
