import QtQuick
import QtQuick.Effects

// ============================================================
// FLARED-ARC CANVAS
// Draws the shared panel shape used by every dropdown:
//   • a rectangle whose top two corners flare outward (notch)
//   • rounded bottom corners
// Properties
//   fillColor   — solid fill (default "black")
//   borderColor — stroke colour (only drawn when borderWidth > 0)
//   borderWidth — stroke width (default 0 = no stroke)
//   blurShadow  — when true, applies a soft blur (use for drop-shadow layer)
// ============================================================
Canvas {
    property color fillColor:   "black"
    property color borderColor: "transparent"
    property real  borderWidth: 0
    property bool  blurShadow:  false

    onWidthChanged:       requestPaint()
    onHeightChanged:      requestPaint()
    onFillColorChanged:   requestPaint()
    onBorderColorChanged: requestPaint()
    onBorderWidthChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        var fl = 16, tri = 16, cr = 16
        var w  = width, h = height

        // ── Fill path ────────────────────────────────────
        ctx.beginPath()
        ctx.moveTo(0, 0)
        ctx.lineTo(w, 0)
        ctx.quadraticCurveTo(w - fl, 0, w - fl, tri)
        ctx.lineTo(w - fl, h - cr)
        ctx.arc(w - fl - cr, h - cr, cr, 0, Math.PI / 2, false)
        ctx.lineTo(fl + cr, h)
        ctx.arc(fl + cr,     h - cr, cr, Math.PI / 2, Math.PI, false)
        ctx.lineTo(fl, tri)
        ctx.quadraticCurveTo(fl, 0, 0, 0)
        ctx.closePath()
        ctx.fillStyle = Qt.rgba(fillColor.r, fillColor.g, fillColor.b, fillColor.a)
        ctx.fill()

        // ── Optional border stroke ────────────────────────
        if (borderWidth > 0) {
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.quadraticCurveTo(fl, 0, fl, tri)
            ctx.lineTo(fl, h - cr)
            ctx.arc(fl + cr,     h - cr, cr, Math.PI,     Math.PI / 2, true)
            ctx.lineTo(w - fl - cr, h)
            ctx.arc(w - fl - cr, h - cr, cr, Math.PI / 2, 0,           true)
            ctx.lineTo(w - fl, tri)
            ctx.quadraticCurveTo(w - fl, 0, w, 0)
            ctx.strokeStyle = Qt.rgba(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
            ctx.lineWidth   = borderWidth
            ctx.stroke()
        }
    }

    layer.enabled: blurShadow
    layer.effect: MultiEffect {
        blurEnabled: blurShadow
        blur:    0.3
        blurMax: 4
    }
}
