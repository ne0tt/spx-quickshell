import QtQuick
import QtQuick.Effects

// ============================================================
// PANEL EARS CANVAS
// Draws the flared "ear" strip at the very top of a dropdown
// panel — the zone that tapers from the full wrapper width at
// y=0 down to the inner panel body width at y=height.
//
// Properties
//   fillColor   — solid fill (should match body panelColor)
//   borderColor — stroke colour (only drawn when borderWidth > 0)
//   borderWidth — stroke width (default 0)
//   blurShadow  — when true applies a soft blur for drop-shadow use
//
// Geometry constants match FlaredArcCanvas so shapes line up:
//   fl  = 16  (horizontal flare offset)
//   When width == panelWidth+32, the "inner" body starts at x=fl
//   and ends at x=width-fl, matching the body sections below.
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

        var fl = 16
        var w  = width
        var h  = height

        // ── Ear + bridge fill ───────────────────────────────
        // Full width at y=0, tapers to inner width [fl .. w-fl] at y=h
        // Quadratic curves give the same "flared" look as FlaredArcCanvas.
        ctx.beginPath()
        ctx.moveTo(0, 0)
        ctx.lineTo(w, 0)
        ctx.quadraticCurveTo(w - fl, 0, w - fl, h)   // right ear curves inward
        ctx.lineTo(fl, h)
        ctx.quadraticCurveTo(fl, 0, 0, 0)            // left ear curves inward
        ctx.closePath()
        ctx.fillStyle = Qt.rgba(fillColor.r, fillColor.g, fillColor.b, fillColor.a)
        ctx.fill()

        // ── Optional border ─────────────────────────────────
        if (borderWidth > 0) {
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(w, 0)
            ctx.quadraticCurveTo(w - fl, 0, w - fl, h)
            ctx.lineTo(fl, h)
            ctx.quadraticCurveTo(fl, 0, 0, 0)
            ctx.strokeStyle = Qt.rgba(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
            ctx.lineWidth   = borderWidth
            ctx.stroke()
        }
    }

    layer.enabled: blurShadow
    layer.effect: MultiEffect {
        blurEnabled: blurShadow
        blur:    0.8
        blurMax: 32
    }
}
