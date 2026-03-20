import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../base"
import "../../state"

// ============================================================
// VOLUME DROPDOWN — extends DropdownBase (no boilerplate duplication)
// ============================================================
DropdownBase {
    id: volDrop
    reloadableId: "volumeDropdown"

    implicitHeight:  volDrop.mediaAvailable ? 410 : 200  // increased to accommodate visualizer
    panelFullHeight: volDrop.mediaAvailable ? 296 : 140  // increased for visualizer space  
    panelWidth:      460
    panelTitle:      "Master volume"
    panelTitleRight: volDrop.muted ? "󰖁  Muted" : volDrop.volume + "%"
    panelIcon:       "󰕾"
    headerHeight:    34

    // ── Shared state (AppState singleton) ──────────────────────
    // _dragVolume overrides volume display while the slider is being dragged
    property int _dragVolume: -1
    readonly property int  volume: _dragVolume >= 0 ? _dragVolume : AppState.volume
    readonly property bool muted:  AppState.muted

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
        // Ensure clean state on open
        volDrop.mediaAvailable = false
        refreshMedia()
        refreshMediaVol()
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
                        volDrop.mediaAvailable = false  // explicitly set to false when no media
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


    // --------------------------------------------------------
    // VOLUME UI
    // Children land in DropdownBase's _wrapper via default alias.
    // --------------------------------------------------------
    Item {
        x: 16 + 20    // increased from 16+14 for better centering
        y: 16 + volDrop.headerHeight + 6
        width:  volDrop.panelWidth - 40    // adjusted for new margins
        height: volDrop.mediaAvailable ? 48 : 60    // when no media, make it fill more space to match media panel gap


        // Volume slider
        Item {
            anchors.verticalCenter: parent.verticalCenter    // center in container instead of fixed y
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
                    AppState.setVolume(newVol)
                }

                onPressed:         mouse => setFromX(mouse.x)
                onPositionChanged: mouse => { if (pressed) setFromX(mouse.x) }
                onReleased: volDrop._dragVolume = -1
            }
        }
    }

    // ────────────────────────────────────────────────────────
    // MEDIA CONTROLS
    // ────────────────────────────────────────────────────────
    Rectangle {
        x: 40    // adjusted for new margins
        y: 124   // moved up from 194 (visualizer was at 124)
        width:  volDrop.panelWidth - 40    // adjusted for new margins
        height: 1
        color: Qt.rgba(volDrop.dimColor.r, volDrop.dimColor.g, volDrop.dimColor.b, 0.2)
        visible: volDrop.mediaAvailable    // hide divider when no media
    }

    Item {
        x: 16 + 20    // increased margins for better centering
        y: 138   // moved up from 208 (was 194 + 14 offset)
        width:  volDrop.panelWidth - 40    // adjusted for new margins
        height: 148    // precise height: 100px art + 32px media slider + 16px spacing
        visible: volDrop.mediaAvailable    // hide entire media section when no media

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
                border.width: volDrop.mediaStatus === "Playing" ? 3 : 0
                border.color: {
                    if (volDrop.mediaStatus !== "Playing") return "transparent"
                    
                    // Create chase effect by interpolating between colors based on angle
                    var normalizedAngle = (_artAngle % 360) / 360
                    var t = (Math.sin(normalizedAngle * Math.PI * 4) + 1) / 2 // 0-1 oscillation, faster cycle
                    
                    // Interpolate between source_color and C47FD5
                    var r = volDrop.accentColor.r * (1 - t) + parseInt("C4", 16) / 255 * t
                    var g = volDrop.accentColor.g * (1 - t) + parseInt("7F", 16) / 255 * t  
                    var b = volDrop.accentColor.b * (1 - t) + parseInt("D5", 16) / 255 * t
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
                    height: 17  // font.pixelSize(14) + some padding
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

        // Playback controls
        Row {
            x: artBox.width + artRow.spacing + (parent.width - artBox.width - artRow.spacing - width) / 2    // center within title/artist text area
            y: artRow.y + 50    // align button bottoms with thumbnail bottom (100px thumbnail height - 50px button height)
            spacing: 16

            Rectangle {
                width: 50    // increased from 40 to match play button
                height: 50   // increased from 40 to match play button
                radius: 25   // increased from 20 to match play button
                color: prevHover.containsMouse 
                       ? Qt.rgba(volDrop.accentColor.r, volDrop.accentColor.g, volDrop.accentColor.b, 0.15)
                       : Qt.rgba(volDrop.dimColor.r, volDrop.dimColor.g, volDrop.dimColor.b, 0.1)
                opacity: volDrop.mediaAvailable ? 1.0 : 0.3

                Text {
                    anchors.centerIn: parent
                    text: "󰒮"
                    font.family: fontFamily
                    font.pixelSize: 20    // increased from 18 to match proportion
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
                width: 50    // increased from 40 to match play button
                height: 50   // increased from 40 to match play button
                radius: 25   // increased from 20 to match play button
                color: nextHover.containsMouse
                       ? Qt.rgba(volDrop.accentColor.r, volDrop.accentColor.g, volDrop.accentColor.b, 0.15)
                       : Qt.rgba(volDrop.dimColor.r, volDrop.dimColor.g, volDrop.dimColor.b, 0.1)
                opacity: volDrop.mediaAvailable ? 1.0 : 0.3

                Text {
                    anchors.centerIn: parent
                    text: "󰒭"
                    font.family: fontFamily
                    font.pixelSize: 20    // increased from 18 to match proportion
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
    }

    // ────────────────────────────────────────────────────────
    // AUDIO VISUALIZER (CAVA) - Now positioned below media controls
    // ────────────────────────────────────────────────────────
    Item {
        x: 16 + 20
        y: 296  // positioned below media controls (138 + 148 + 10 spacing)
        width: volDrop.panelWidth - 40
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
                property int barCount: 26
                
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
                            NumberAnimation {
                                duration: 30
                                easing.type: Easing.Linear
                            }
                        }
                    }
                }
            }
        }
    }
}
