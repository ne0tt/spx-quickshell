import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// ============================================================
// VOLUME DROPDOWN — extends DropdownBase (no boilerplate duplication)
// ============================================================
DropdownBase {
    id: volDrop
    reloadableId: "volumeDropdown"

    implicitHeight:  396
    panelFullHeight: 292
    panelWidth:      260
    panelTitle:      "Master volume"
    panelTitleRight: volDrop.muted ? "󰖁  Muted" : volDrop.volume + "%"
    panelIcon:       "󰕾"
    headerHeight:    34

    // ── Shared state (from VolumeState singleton) ─────────────
    property QtObject volumeData: null

    // _dragVolume overrides volume display while the slider is being dragged
    property int _dragVolume: -1
    readonly property int  volume: _dragVolume >= 0 ? _dragVolume : (volumeData ? volumeData.volume : 0)
    readonly property bool muted:  volumeData ? volumeData.muted : false

    // ── Media state ─────────────────────────────────────────
    property string mediaTitle: "No media playing"
    property string mediaArtist: ""
    property string mediaArtUrl: ""
    property string mediaStatus: "Stopped"  // Playing, Paused, Stopped
    property bool   mediaAvailable: false
    property bool   mediaIsBrowser: false   // true when player is a browser (MPRIS via Chrome etc)
    property int    mediaSinkId:    -1      // pactl sink-input id when mediaIsBrowser
    property int    mediaVolume:    100
    property int    _dragMediaVol:  -1
    property bool   _mediaVolPending: false  // true while write+confirm cycle is in-flight
    readonly property int displayMediaVol: _dragMediaVol >= 0 ? _dragMediaVol : mediaVolume

    // Refresh on open
    onAboutToOpen: {
        if (volDrop.volumeData) volDrop.volumeData.refresh()
        refreshMedia()
        refreshMediaVol()
    }

    // Poll while open so the slider stays in sync with external changes
    Timer {
        interval: 500
        running: volDrop.isOpen
        repeat: true
        onTriggered: {
            if (volDrop.volumeData) volDrop.volumeData.refresh()
            refreshMedia()
            refreshMediaVol()
        }
    }

    // ── Media control functions ────────────────────────────
    function refreshMedia() {
        if (!volDrop.isOpen) return
        mediaProc.running = true
    }

    function mediaControl(action) {
        var cmd = ["playerctl", action]
        controlProc.command = cmd
        controlProc.running = true
        Qt.callLater(refreshMedia)
    }

    function refreshMediaVol() {
        if (!volDrop.isOpen || volDrop._mediaVolPending) return
        if (volDrop.mediaIsBrowser) {
            mediaVolProc.command = ["bash", "-c",
                "SINK=$(pactl -f json list sink-inputs | python3 -c " +
                "\"import json,sys;[print(s['index']) for s in json.load(sys.stdin) " +
                "if any(b in (s.get('properties',{}).get('application.name','')+" +
                "s.get('properties',{}).get('application.process.binary','')).lower() " +
                "for b in ['chrom','firefox','brave','vivaldi','opera'])]\") && " +
                "pactl -f json list sink-inputs | python3 -c " +
                "\"import json,sys;[print(str(s['index'])+'|'+str(round(list(s.get('volume',{}).values())[0].get('value',65536)/65536*100))) " +
                "for s in json.load(sys.stdin) if str(s['index'])==('$SINK' or '-1')]\""
            ]
        } else {
            mediaVolProc.command = ["bash", "-c",
                "python3 -c \"import subprocess; r=subprocess.run(['playerctl','volume'],capture_output=True,text=True); print(round(float(r.stdout.strip())*100)) if r.returncode==0 else print(100)\""]
        }
        mediaVolProc.running = true
    }

    function setMediaVolume(v) {
        volDrop._mediaVolPending = true
        // Always detect browser sink at call time — no cached state dependency
        setMediaVolProc.command = ["bash", "-c",
            "SINK=$(pactl -f json list sink-inputs | python3 -c " +
            "\"import json,sys;[print(s['index']) for s in json.load(sys.stdin) " +
            "if any(b in (s.get('properties',{}).get('application.name','')+" +
            "s.get('properties',{}).get('application.process.binary','')).lower() " +
            "for b in ['chrom','firefox','brave','vivaldi','opera'])]\"); " +
            "if [ -n \"$SINK\" ]; then " +
            "  pactl set-sink-input-volume \"$SINK\" " + String(v) + "% && echo \"$SINK|" + String(v) + "\"; " +
            "else " +
            "  playerctl volume " + (v / 100).toFixed(2) + "; " +
            "fi"
        ]
        setMediaVolProc.running = true
    }

    // ── Processes ───────────────────────────────────────────
    // Get current media info
    Process {
        id: mediaProc
        running: false
        command: ["bash", "-c", "playerctl -a metadata --format '{{status}}|{{title}}|{{artist}}|{{mpris:artUrl}}|{{xesam:url}}' 2>/dev/null | awk -F'|' '$1==\"Playing\"{print;found=1;exit} {last=$0} END{if(!found && NR>0)print last}' || echo 'Stopped||||'"]
        
        stdout: SplitParser {
            onRead: data => {
                var i1 = data.indexOf("|"), i2 = data.indexOf("|", i1+1),
                    i3 = data.indexOf("|", i2+1), i4 = data.indexOf("|", i3+1)
                if (i1 >= 0 && i2 >= 0 && i3 >= 0) {
                    volDrop.mediaStatus = data.substring(0,    i1)   || "Stopped"
                    volDrop.mediaTitle  = data.substring(i1+1, i2)   || "No media playing"
                    volDrop.mediaArtist = data.substring(i2+1, i3)   || ""
                    var artUrl  = (i4 >= 0 ? data.substring(i3+1, i4) : data.substring(i3+1)).trim()
                    var pageUrl = (i4 >= 0 ? data.substring(i4+1) : "").trim()

                    // No album art but it's a YouTube URL — build thumbnail from video ID
                    if (!artUrl && pageUrl) {
                        var ytId = pageUrl.match(/[?&]v=([A-Za-z0-9_-]{11})/)
                        if (ytId) artUrl = "https://img.youtube.com/vi/" + ytId[1] + "/hqdefault.jpg"
                    }

                    volDrop.mediaArtUrl    = artUrl
                    volDrop.mediaIsBrowser = pageUrl.startsWith("http://") || pageUrl.startsWith("https://")
                    volDrop.mediaAvailable = volDrop.mediaStatus !== "Stopped" && volDrop.mediaTitle !== ""
                    // Trigger volume read now that mediaIsBrowser is known
                    Qt.callLater(() => { if (!volDrop._mediaVolPending) refreshMediaVol() })
                } else {
                    volDrop.mediaStatus    = "Stopped"
                    volDrop.mediaTitle     = "No media playing"
                    volDrop.mediaArtist    = ""
                    volDrop.mediaArtUrl    = ""
                    volDrop.mediaIsBrowser = false
                    volDrop.mediaSinkId    = -1
                    volDrop.mediaAvailable = false
                }
            }
        }
        // NOTE: do NOT clear command — mediaProc uses a static command
    }

    // Control playback
    Process {
        id: controlProc
        running: false
        command: []
        onRunningChanged: if (!running) command = []
    }

    // Get media player volume (command set dynamically by refreshMediaVol())
    Process {
        id: mediaVolProc
        running: false
        command: []
        stdout: SplitParser {
            onRead: data => {
                var trimmed = data.trim()
                var pipeIdx = trimmed.indexOf("|")
                var vol, sinkId = -1
                if (pipeIdx >= 0) {
                    // browser pactl format: SINKID|VOLUME
                    sinkId = parseInt(trimmed.substring(0, pipeIdx))
                    vol    = parseInt(trimmed.substring(pipeIdx + 1))
                    if (!isNaN(sinkId)) volDrop.mediaSinkId = sinkId
                } else {
                    // playerctl format: plain integer 0-100
                    vol = parseInt(trimmed)
                }
                if (!isNaN(vol)) {
                    volDrop.mediaVolume      = Math.max(0, Math.min(100, vol))
                    volDrop._dragMediaVol    = -1
                    volDrop._mediaVolPending = false
                }
            }
        }
    }

    // Set media player volume
    Process {
        id: setMediaVolProc
        running: false
        command: []

        // Capture SINKID|VOL echoed by the browser combined find+set script
        stdout: SplitParser {
            onRead: data => {
                var trimmed = data.trim()
                var pipeIdx = trimmed.indexOf("|")
                if (pipeIdx >= 0) {
                    var sid = parseInt(trimmed.substring(0, pipeIdx))
                    if (!isNaN(sid)) volDrop.mediaSinkId = sid
                }
            }
        }

        onRunningChanged: if (!running) {
            command = []
            mediaVolRefreshDelay.restart()
        }
    }

    Timer {
        id: mediaVolRefreshDelay
        interval: 300
        repeat: false
        onTriggered: refreshMediaVol()
    }


    // --------------------------------------------------------
    // VOLUME UI
    // Children land in DropdownBase's _wrapper via default alias.
    // --------------------------------------------------------
    Item {
        x: 16 + 14
        y: 16 + volDrop.headerHeight + 6
        width:  volDrop.panelWidth - 28
        height: 48


        // Volume slider
        Item {
            y: 8
            width: parent.width
            height: 40

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: volDrop.dimColor

                Rectangle {
                    width: parent.width * (volDrop.muted ? 0 : volDrop.volume / 100)
                    height: parent.height
                    radius: 3
                    color: volDrop.muted ? volDrop.dimColor : volDrop.accentColor
                }
            }

            Rectangle {
                id: handle
                width: 18
                height: 18
                radius: 9
                color: volDrop.accentColor
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(
                       parent.width - width,
                       (volDrop.muted ? 0 : volDrop.volume / 100) * (parent.width - width)
                   ))
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                function setFromX(mx) {
                    var newVol = Math.round(Math.max(0, Math.min(100,
                        mx / (parent.width - handle.width) * 100
                    )))
                    volDrop._dragVolume = newVol
                    if (volDrop.volumeData) volDrop.volumeData.setVolume(newVol)
                }

                onPressed:         mouse => setFromX(mouse.x)
                onPositionChanged: mouse => { if (pressed) setFromX(mouse.x) }
                onReleased: { volDrop._dragVolume = -1; Qt.callLater(() => { if (volDrop.volumeData) volDrop.volumeData.refresh() }) }
            }
        }
    }

    // ────────────────────────────────────────────────────────
    // MEDIA CONTROLS
    // ────────────────────────────────────────────────────────
    Rectangle {
        x: 30
        y: 104 + 8
        width:  volDrop.panelWidth - 28
        height: 1
        color: Qt.rgba(volDrop.dimColor.r, volDrop.dimColor.g, volDrop.dimColor.b, 0.2)
    }

    Item {
        x: 16 + 14
        y: 104 + 8 + 14
        width:  volDrop.panelWidth - 28
        height: 216

        // Header
        Row {
            id: mediaHeader
            width: parent.width
            height: 24
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: volDrop.mediaStatus === "Playing" ? "󰝚" : "󰝛"
                font.family: fontFamily
                font.pixelSize: 22
                color: Qt.rgba(volDrop.accentColor.r,
                               volDrop.accentColor.g,
                               volDrop.accentColor.b, 0.7)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "MEDIA"
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 2
                color: Qt.rgba(volDrop.dimColor.r,
                               volDrop.dimColor.g,
                               volDrop.dimColor.b, 0.55)
            }
        }

        // Album art + track info
        Row {
            id: artRow
            y: mediaHeader.height + 8
            width: parent.width
            height: 72
            spacing: 12

            // Album art square
            Rectangle {
                id: artBox
                width: 74
                height: 74
                radius: 10
                color: Qt.rgba(volDrop.dimColor.r, volDrop.dimColor.g, volDrop.dimColor.b, 0.15)

                // Hidden rounded mask — layer.enabled forces it to render even when invisible
                Rectangle {
                    id: artImageMask
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: artBox.radius - 1
                    color: "white"
                    layer.enabled: true
                    visible: false
                }

                Image {
                    id: artImage
                    anchors.fill: parent
                    anchors.margins: 2
                    source: volDrop.mediaArtUrl
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    cache: false
                    asynchronous: true
                    visible: volDrop.mediaArtUrl !== "" && status === Image.Ready
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: artImageMask
                    }
                }

                // Placeholder icon when no art available
                Text {
                    anchors.centerIn: parent
                    text: "󰝚"
                    font.family: fontFamily
                    font.pixelSize: 28
                    color: Qt.rgba(volDrop.accentColor.r, volDrop.accentColor.g, volDrop.accentColor.b, 0.4)
                    visible: artImage.status !== Image.Ready || volDrop.mediaArtUrl === ""
                }

                // Rotating gradient border overlay
                property real _artAngle: 0
                Timer {
                    id: __artAngleTimer
                    running: volDrop.mediaAvailable
                    interval: 40    // ~20 fps — throttled to reduce CPU load
                    repeat: true
                    onTriggered: parent._artAngle -= Math.PI * 2 / 48
                }

                Canvas {
                    id: _artBorderCanvas
                    anchors.fill: parent

                    property real angle: parent._artAngle
                    onAngleChanged: { if (opacity > 0) requestPaint() }

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var bw = 2; var r = artBox.radius
                        var x = bw/2; var y = bw/2
                        var w = width - bw; var h = height - bw
                        var cx = width/2; var cy = height/2
                        var grad = ctx.createConicalGradient(cx, cy, angle)
                        var sc = volDrop.accentColor
                        var c1 = Qt.rgba(sc.r, sc.g, sc.b, 1.0).toString()
                        grad.addColorStop(0,    c1)        // source_color half
                        grad.addColorStop(0.5,  "#C47FD5") // purple half — chasing
                        grad.addColorStop(1.0,  c1)        // wraps back seamlessly
                        ctx.strokeStyle = grad
                        ctx.lineWidth   = bw
                        ctx.beginPath()
                        ctx.moveTo(x+r, y)
                        ctx.lineTo(x+w-r, y)
                        ctx.arcTo(x+w, y,   x+w, y+r,   r)
                        ctx.lineTo(x+w, y+h-r)
                        ctx.arcTo(x+w, y+h, x+w-r, y+h, r)
                        ctx.lineTo(x+r, y+h)
                        ctx.arcTo(x, y+h,   x, y+h-r,   r)
                        ctx.lineTo(x, y+r)
                        ctx.arcTo(x, y,     x+r, y,     r)
                        ctx.closePath()
                        ctx.stroke()
                    }
                }
            }

            // Title + artist stacked
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - artBox.width - artRow.spacing
                spacing: 5

                Text {
                    width: parent.width
                    text: volDrop.mediaTitle
                    elide: Text.ElideRight
                    color: volDrop.mediaAvailable ? volDrop.textColor : volDrop.dimColor
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    width: parent.width
                    text: volDrop.mediaArtist || (volDrop.mediaAvailable ? "Unknown Artist" : "")
                    elide: Text.ElideRight
                    color: Qt.rgba(volDrop.dimColor.r, volDrop.dimColor.g, volDrop.dimColor.b, 0.7)
                    font.pixelSize: 12
                    visible: volDrop.mediaArtist !== "" || volDrop.mediaAvailable
                }
            }
        }

        // Playback controls
        Row {
            y: artRow.y + artRow.height + 10
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: prevHover.containsMouse 
                       ? Qt.rgba(volDrop.accentColor.r, volDrop.accentColor.g, volDrop.accentColor.b, 0.15)
                       : Qt.rgba(volDrop.dimColor.r, volDrop.dimColor.g, volDrop.dimColor.b, 0.1)
                opacity: volDrop.mediaAvailable ? 1.0 : 0.3

                Text {
                    anchors.centerIn: parent
                    text: "󰒮"
                    font.family: fontFamily
                    font.pixelSize: 18
                    color: volDrop.accentColor
                }

                MouseArea {
                    id: prevHover
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    enabled: volDrop.mediaAvailable
                    onClicked: volDrop.mediaControl("previous")
                }
            }

            Rectangle {
                width: 50
                height: 50
                radius: 25
                color: playHover.containsMouse
                       ? Qt.rgba(volDrop.accentColor.r, volDrop.accentColor.g, volDrop.accentColor.b, 0.25)
                       : Qt.rgba(volDrop.accentColor.r, volDrop.accentColor.g, volDrop.accentColor.b, 0.15)
                opacity: volDrop.mediaAvailable ? 1.0 : 0.3

                Text {
                    anchors.centerIn: parent
                    text: volDrop.mediaStatus === "Playing" ? "󰏤" : "󰐊"
                    font.family: fontFamily
                    font.pixelSize: 22
                    color: volDrop.accentColor
                }

                MouseArea {
                    id: playHover
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    enabled: volDrop.mediaAvailable
                    onClicked: volDrop.mediaControl("play-pause")
                }
            }

            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: nextHover.containsMouse
                       ? Qt.rgba(volDrop.accentColor.r, volDrop.accentColor.g, volDrop.accentColor.b, 0.15)
                       : Qt.rgba(volDrop.dimColor.r, volDrop.dimColor.g, volDrop.dimColor.b, 0.1)
                opacity: volDrop.mediaAvailable ? 1.0 : 0.3

                Text {
                    anchors.centerIn: parent
                    text: "󰒭"
                    font.family: fontFamily
                    font.pixelSize: 18
                    color: volDrop.accentColor
                }

                MouseArea {
                    id: nextHover
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    enabled: volDrop.mediaAvailable
                    onClicked: volDrop.mediaControl("next")
                }
            }
        }  // end controls Row

        // Media player volume
        Row {
            y: artRow.y + artRow.height + 10 + 50 + 12
            width: parent.width
            height: 40
            spacing: 10
            opacity: volDrop.mediaAvailable ? 1.0 : 0.3

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: volDrop.displayMediaVol <= 0 ? "󰕿" : (volDrop.displayMediaVol > 50 ? "󰕾" : "󰖀")
                font.family: fontFamily
                font.pixelSize: 18
                color: volDrop.accentColor
            }

            Item {
                id: mediaVolSlider
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28
                height: 40

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 5
                    radius: 3
                    color: volDrop.dimColor

                    Rectangle {
                        width: parent.width * (volDrop.displayMediaVol / 100)
                        height: parent.height
                        radius: 3
                        color: volDrop.accentColor
                    }
                }

                Rectangle {
                    id: mediaVolHandle
                    width: 16; height: 16; radius: 8
                    color: volDrop.accentColor
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(
                           parent.width - width,
                           (volDrop.displayMediaVol / 100) * (parent.width - width)
                       ))
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    enabled: volDrop.mediaAvailable

                    function volFromX(mx) {
                        return Math.round(Math.max(0, Math.min(100,
                            mx / (parent.width - mediaVolHandle.width) * 100
                        )))
                    }

                    onPressed:         mouse => { volDrop._dragMediaVol = volFromX(mouse.x) }
                    onPositionChanged: mouse => { if (pressed) volDrop._dragMediaVol = volFromX(mouse.x) }
                    onReleased: {
                        var v = volDrop._dragMediaVol >= 0 ? volDrop._dragMediaVol : volDrop.mediaVolume
                        // do NOT clear _dragMediaVol here — keep it pinned so display
                        // doesn't snap back before the 300 ms re-read confirms the new value
                        volDrop.setMediaVolume(v)
                    }
                }
            }
        }  // end media volume Row
    }
}
