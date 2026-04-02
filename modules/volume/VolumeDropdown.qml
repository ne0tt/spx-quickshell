import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../base"
import "../../state"
import "../.."

// ============================================================
// VOLUME DROPDOWN — extends DropdownBase (no boilerplate duplication)
// ============================================================
DropdownBase {
    id: volDrop
    reloadableId: "volumeDropdown"

    keyboardFocusEnabled: true

    Item { focus: true; Keys.onEscapePressed: volDrop.closePanel() }

    implicitHeight:  volDrop.mediaAvailable ? 410 : 120  // 120 for volume slider only
    panelFullHeight: volDrop.mediaAvailable ? 296 : 120  // unified container for volume + media  
    panelWidth:      460
    panelTitle:      "Master volume"
    panelTitleRight: volDrop.muted ? "󰖁  Muted" : volDrop.volume + "%"
    panelIcon:       "󰕾"
    headerHeight:    34

    // ── Shared state (AppState singleton) ──────────────────────
    // _dragVolume overrides volume display while the slider is being dragged
    property int _dragVolume: -1
    readonly property int  volume: _dragVolume >= 0 ? _dragVolume : VolumeState.volume
    readonly property bool muted:  VolumeState.muted

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
    property int    _mediaPosition:  0      // playback position in seconds
    property int    _mediaDuration:  0      // track duration in seconds

    // Refresh on open
    onAboutToOpen: {
        // Ensure clean state on open
        volDrop.mediaAvailable = false
        refreshMedia()
        refreshMediaVol()
    }
    
    // Control CAVA process based on dropdown state and media availability
    onIsOpenChanged: {
        Audio.cava.visualizationVisible = volDrop.isOpen && volDrop.mediaAvailable
    }
    onMediaAvailableChanged: {
        Audio.cava.visualizationVisible = volDrop.isOpen && volDrop.mediaAvailable
    }

    // Poll while open so the slider stays in sync with external changes
    Timer {
        interval: 800  // reduced polling for better performance
        running: volDrop.isOpen
        repeat: true
        onTriggered: {
            refreshMedia()
            refreshMediaVol()
        }
    }

    // Progress bar updates - 1-second refresh when media is available
    Timer {
        interval: 1000
        running: volDrop.isOpen && volDrop.mediaAvailable
        repeat: true
        onTriggered: positionProc.running = true
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
                "pactl -f json list sink-inputs | python3 -c \"" +
                "import json,sys;" +
                "d=json.load(sys.stdin);" +
                "bl=['chrom','firefox','brave','vivaldi','opera'];" +
                "s=next((s for s in d if any(b in (s.get('properties',{}).get('application.name','')+s.get('properties',{}).get('application.process.binary','')).lower() for b in bl)),None);" +
                "s and print(str(s['index'])+'|'+str(round(list(s.get('volume',{}).values())[0].get('value',65536)/65536*100)))" +
                "\""
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
    // Get current media position and duration
    Process {
        id: positionProc
        running: false
        command: ["bash", "-c", "playerctl metadata --format '{{position}}|{{mpris:length}}' 2>/dev/null || echo '0|0'"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split('|')
                if (parts.length === 2) {
                    // Parse and validate position (microseconds to seconds)
                    // Ensure values are reasonable (max 24 hours = 86400 seconds)
                    var posStr = parts[0] && parts[0].trim() !== "" ? parts[0].trim() : "0"
                    var pos = parseInt(posStr)
                    var posSeconds = (!isNaN(pos) && pos >= 0) ? Math.floor(pos / 1000000) : 0
                    volDrop._mediaPosition = (posSeconds >= 0 && posSeconds < 86400) ? posSeconds : 0
                    
                    // Parse and validate duration (microseconds to seconds)
                    var durStr = parts[1] && parts[1].trim() !== "" ? parts[1].trim() : "0"
                    var dur = parseInt(durStr)
                    var durSeconds = (!isNaN(dur) && dur >= 0) ? Math.floor(dur / 1000000) : 0
                    volDrop._mediaDuration = (durSeconds >= 0 && durSeconds < 86400) ? durSeconds : 0
                }
            }
        }
    }

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

                    volDrop.mediaIsBrowser = pageUrl.startsWith("http://") || pageUrl.startsWith("https://")
                    
                    // Media is available only if we have actual playing/paused content with a real title
                    volDrop.mediaAvailable = (volDrop.mediaStatus === "Playing" || volDrop.mediaStatus === "Paused") && 
                                             volDrop.mediaTitle !== "" && 
                                             volDrop.mediaTitle !== "No media playing"

                    if (volDrop.mediaAvailable) {
                        volDrop.mediaArtUrl = artUrl
                    } else {
                        // Media is stopped — clear stale metadata so old track info isn't shown
                        volDrop.mediaTitle     = "No media playing"
                        volDrop.mediaArtist    = ""
                        volDrop.mediaArtUrl    = ""
                        volDrop.mediaIsBrowser = false
                        volDrop.mediaSinkId    = -1
                    }
                    // Trigger volume read now that mediaIsBrowser is known
                    Qt.callLater(() => { if (!volDrop._mediaVolPending) refreshMediaVol() })
                } else {
                    // Parsing failed or no data - definitely no media available
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


    // ────────────────────────────────────────────────────────
    // UNIFIED VOLUME + MEDIA CONTAINER
    // ────────────────────────────────────────────────────────
    Item {
        x: 16 + 20
        y: 16 + volDrop.headerHeight + 6
        width: volDrop.panelWidth - 40
        height: volDrop.mediaAvailable ? 216 : 60  // 60px volume area or 60+156 for volume+media

        // Volume slider at the top
        Item {
            id: volumeSliderArea
            y: 0
            width: parent.width
            height: 60

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 40

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Colors.col_background

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
                    border.width: 1
                    border.color: Colors.col_background
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
                        VolumeState.setVolume(newVol)
                    }

                    onPressed:         mouse => setFromX(mouse.x)
                    onPositionChanged: mouse => { if (pressed) setFromX(mouse.x) }
                    onReleased: volDrop._dragVolume = -1
                }
            }
        }

        // Divider between volume and media
        Rectangle {
            y: 68
            width: parent.width + 40  // extend to edges
            x: -20
            height: 1
            color: Qt.rgba(volDrop.dimColor.r, volDrop.dimColor.g, volDrop.dimColor.b, 0.2)
            visible: volDrop.mediaAvailable
        }

        // Media section below volume slider
        Item {
            y: 78
            width: parent.width
            height: 138
            visible: volDrop.mediaAvailable

        // Album art + track info
        Row {
            id: artRow
            y: 8    // removed mediaHeader, so start at top with small margin
            width: parent.width
            height: 100     // increased from 80 to match larger album art
            spacing: 16     // increased spacing for better proportion

            // Album art square
            Rectangle {
                id: artBox
                width: 100    // increased from 80 by 25%
                height: 100   // increased from 80 by 25%
                radius: 12    // slightly more rounded for modern look
                color: Qt.rgba(volDrop.dimColor.r, volDrop.dimColor.g, volDrop.dimColor.b, 0.15)
                
                // Animated border that changes color
                border.width: volDrop.mediaStatus === "Playing" ? 2 : 0
                border.color: {
                    if (volDrop.mediaStatus !== "Playing") return "transparent"
                    
                    // Create chase effect by interpolating between colors based on angle
                    var normalizedAngle = (_artAngle % 360) / 360
                    var t = (Math.sin(normalizedAngle * Math.PI * 4) + 1) / 2 // 0-1 oscillation, faster cycle
                    
                    // Interpolate between source_color and #C47FD5 (0xC4/255, 0x7F/255, 0xD5/255)
                    var r = volDrop.accentColor.r * (1 - t) + 0.769 * t
                    var g = volDrop.accentColor.g * (1 - t) + 0.498 * t
                    var b = volDrop.accentColor.b * (1 - t) + 0.835 * t
                    return Qt.rgba(r, g, b, 1.0)
                }

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

                // Animation property and timer
                property real _artAngle: 0
                Timer {
                    interval: 50  // Faster for smoother color transitions
                    running: volDrop.mediaStatus === "Playing" && volDrop.isOpen
                    repeat: true
                    onTriggered: artBox._artAngle = (artBox._artAngle + 3) % 360 // Faster rotation
                }
            }

            Column {
                anchors.top: parent.top    // align with top of album art instead of center
                width: parent.width - artBox.width - artRow.spacing
                spacing: 5

                // Scrolling media title
                Item {
                    width: parent.width
                    height: 20  // font.pixelSize(14) + some padding
                    clip: true
                    
                    Text {
                        id: scrollingTitle
                        text: volDrop.mediaTitle
                        color: volDrop.mediaAvailable ? volDrop.textColor : volDrop.dimColor
                        font.pixelSize: 14
                        font.bold: true
                        
                        property real textWidth: paintedWidth
                        property real containerWidth: parent.width
                        property bool needsScroll: textWidth > containerWidth
                        
                        // Scroll animation
                        SequentialAnimation {
                            id: scrollAnim
                            running: scrollingTitle.needsScroll && volDrop.isOpen && volDrop.mediaAvailable
                            loops: Animation.Infinite
                            
                            PauseAnimation { duration: 2000 }  // pause at start
                            NumberAnimation {
                                target: scrollingTitle
                                property: "x"
                                from: 0
                                to: scrollingTitle.containerWidth - scrollingTitle.textWidth - 10
                                duration: Math.max(3000, scrollingTitle.textWidth * 20)  // slower for longer text
                                easing.type: Easing.InOutQuad
                            }
                            PauseAnimation { duration: 1500 }  // pause at end
                            NumberAnimation {
                                target: scrollingTitle
                                property: "x"
                                from: scrollingTitle.containerWidth - scrollingTitle.textWidth - 10
                                to: 0
                                duration: Math.max(3000, scrollingTitle.textWidth * 20)
                                easing.type: Easing.InOutQuad
                            }
                        }
                        
                        // Reset position when text changes or scrolling stops
                        onNeedsScrollChanged: if (!needsScroll) x = 0
                        Component.onCompleted: if (!needsScroll) x = 0
                    }
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

        // Media controls and progress bar - horizontal layout
        Row {
            id: mediaControlsRow
            x: artBox.width + artRow.spacing
            y: artRow.y + 50
            width: parent.width - artBox.width - artRow.spacing
            spacing: 16

            // Playback controls (left side)
            Row {
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
                        font.pixelSize: 16
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
                    width: 40
                    height: 40
                    radius: 20
                    color: playHover.containsMouse
                           ? Qt.rgba(volDrop.accentColor.r, volDrop.accentColor.g, volDrop.accentColor.b, 0.25)
                           : Qt.rgba(volDrop.accentColor.r, volDrop.accentColor.g, volDrop.accentColor.b, 0.15)
                    opacity: volDrop.mediaAvailable ? 1.0 : 0.3

                    Text {
                        anchors.centerIn: parent
                        text: volDrop.mediaStatus === "Playing" ? "󰏤" : "󰐊"
                        font.family: fontFamily
                        font.pixelSize: 18
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
                        font.pixelSize: 16
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
            }  // end playback controls Row

            // Progress bar and time (right side)
            Column {
                width: mediaControlsRow.width - 168  // parent width - (120px buttons + 32px internal spacing + 16px external spacing)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                // Time labels
                Item {
                    width: parent.width
                    height: 12

                    Text {
                        anchors.left: parent.left
                        text: {
                            var pos = volDrop._mediaPosition || 0
                            var sec = Math.floor(pos)
                            var h = Math.floor(sec / 3600)
                            var m = Math.floor((sec % 3600) / 60)
                            var s = sec % 60
                            return String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0")
                        }
                        font.family: fontFamily
                        font.pixelSize: 10
                        color: volDrop.dimColor
                    }

                    Text {
                        anchors.right: parent.right
                        text: {
                            var dur = volDrop._mediaDuration || 0
                            var sec = Math.floor(dur)
                            var h = Math.floor(sec / 3600)
                            var m = Math.floor((sec % 3600) / 60)
                            var s = sec % 60
                            return String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0")
                        }
                        font.family: fontFamily
                        font.pixelSize: 10
                        color: volDrop.dimColor
                    }
                }

                // Progress bar
                Item {
                    width: parent.width
                    height: 18

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Colors.col_background

                        Rectangle {
                            width: volDrop._mediaDuration > 0 
                                   ? parent.width * (volDrop._mediaPosition / volDrop._mediaDuration) 
                                   : 0
                            height: parent.height
                            radius: 3
                            color: volDrop.accentColor
                        }
                    }

                    Rectangle {
                        id: progressHandle
                        width: 14
                        height: 14
                        radius: 7
                        color: volDrop.accentColor
                        border.width: 1
                        border.color: Colors.col_background
                        anchors.verticalCenter: parent.verticalCenter
                        x: volDrop._mediaDuration > 0
                           ? Math.max(0, Math.min(
                                 parent.width - width,
                                 (volDrop._mediaPosition / volDrop._mediaDuration) * (parent.width - width)
                             ))
                           : 0
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: volDrop.mediaAvailable && volDrop._mediaDuration > 0

                        function seekToX(mx) {
                            if (volDrop._mediaDuration <= 0) return
                            var seekPos = Math.max(0, Math.min(volDrop._mediaDuration,
                                Math.floor((mx / (parent.width - progressHandle.width)) * volDrop._mediaDuration)
                            ))
                            volDrop.mediaControl("position " + seekPos)
                            volDrop._mediaPosition = seekPos
                            Qt.callLater(() => positionProc.running = true)
                        }

                        onPressed:         mouse => seekToX(mouse.x)
                        onPositionChanged: mouse => { if (pressed) seekToX(mouse.x) }
                    }
                }
            }  // end progress Column
        }  // end media controls Row
        }  // end media section Item

        // ────────────────────────────────────────────────────────
        // AUDIO VISUALIZER (CAVA) - positioned below media within container
        // ────────────────────────────────────────────────────────
        Item {
            y: 226  // positioned below media section (78 + 138 + 10 spacing)
            width: parent.width
            height: 60
            visible: volDrop.mediaAvailable && volDrop.isOpen  // only show and process when dropdown is open
        
        // Visualizer bars container
        Item {
            id: visualizerContent
            anchors.fill: parent
            anchors.bottomMargin: 20
            
            Row {
                id: barsRow
                anchors.centerIn: parent
                height: parent.height - 10
                spacing: 3
                
                // Using 24 bars for a good balance of detail and performance
                property int barCount: 20
                
                Repeater {  
                    model: barsRow.barCount
                    
                    Rectangle {
                        id: bar
                        
                        required property int index  
                        property real value: (volDrop.isOpen && volDrop.mediaAvailable) ? 
                            Math.max(0, Math.min(1, 
                                Audio.cava.values?.[Math.floor((index / (barsRow.barCount - 1)) * (Audio.cava.values?.length - 1 || 0))] || 0
                            )) : 0
                        
                        width: (visualizerContent.width - (barsRow.spacing * (barsRow.barCount - 1))) / barsRow.barCount
                        height: Math.max(2, bar.value * barsRow.height * 1.8)
                        
                        anchors.bottom: parent.bottom
                        
                        color: Qt.rgba(volDrop.accentColor.r, volDrop.accentColor.g, volDrop.accentColor.b, 0.8)
                        
                        
                        Behavior on height {
                            enabled: volDrop.isOpen && volDrop.mediaAvailable
                            NumberAnimation {
                                duration: 30
                                easing.type: Easing.Linear
                            }
                        }
                    }
                }
            }
        }
    }  // end CAVA visualizer
    }  // end unified container
}
