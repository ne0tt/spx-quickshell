import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../base"
// ============================================================
// WALLPAPER DROPDOWN — scrollable thumbnail grid
// Finds all images under ~/wallpaper/ recursively.
// Click a thumbnail to apply it via wallpaper.sh.
// ============================================================
DropdownBase {
    id: wpDrop
    reloadableId: "wallpaperDropdown"

    implicitHeight:  650
    panelFullHeight: 416
    panelWidth:      620
    panelTitle:      "Wallpaper"
    panelIcon:       "󰸉"
    headerHeight:    34

    // Exclusively grab keyboard input while the panel is open so arrow-key
    // navigation works without the user needing to mouse over the window first.
    WlrLayershell.keyboardFocus: panelVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // --------------------------------------------------------
    // STATE
    // --------------------------------------------------------
    property var    images:          []
    property string currentWallpaper: ""
    property var    _findArr:         []   // array accumulator — avoids O(n²) string concat
    property bool   _applying:        false
    property int    focusedIndex:     -1   // keyboard-nav cursor

    // inner content margin (matches other dropdowns)
    readonly property int _mx: 14   // horizontal margin inside panel shape
    readonly property int _cols: 4
    readonly property real _cellW: Math.floor((panelWidth - _mx * 2 - (_cols - 1) * 6) / _cols)
    readonly property real _cellH: Math.floor(_cellW * 0.6)

    // --------------------------------------------------------
    // OPEN / CLOSE API — async: animate only after image list loads
    // --------------------------------------------------------
    function openPanel() {
        panelVisible = true
        _findArr = []
        findProc.running = true
        currentProc.running = true
    }

    // --------------------------------------------------------
    // FIND IMAGES
    // --------------------------------------------------------
    Process {
        id: findProc
        running: false
        command: ["sh", "-c",
            "find \"$HOME/wallpaper\" -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"]
        stdout: SplitParser {
            onRead: data => {
                var s = data.trim()
                if (s) wpDrop._findArr.push(s)
            }
        }
        onExited: (code, status) => {
            wpDrop.images = wpDrop._findArr.slice()
            wpDrop._findArr = []
            var idx = wpDrop.images.indexOf(wpDrop.currentWallpaper)
            wpDrop.focusedIndex = idx >= 0 ? idx : 0
            startOpenAnim()
            _focusTimer.restart()
        }
    }

    // --------------------------------------------------------
    // READ CURRENT WALLPAPER — ask swww what is actually displayed
    // --------------------------------------------------------
    Process {
        id: currentProc
        running: false
        command: ["sh", "-c", "swww query 2>/dev/null | awk -F'image: ' '{print $2}' | awk '{print $1}' | tr -d ',' | head -1"]
        stdout: SplitParser {
            onRead: data => {
                var s = data.trim()
                if (s) {
                    wpDrop.currentWallpaper = s
                    // currentProc may finish after findProc — sync focusedIndex
                    if (wpDrop.images.length > 0) {
                        var idx = wpDrop.images.indexOf(s)
                        if (idx >= 0) {
                            wpDrop.focusedIndex = idx
                            Qt.callLater(function() { wpDrop.ensureFocusedVisible() })
                        }
                    }
                }
            }
        }
    }

    // --------------------------------------------------------
    // APPLY WALLPAPER
    // --------------------------------------------------------
    Process {
        id: swwwProc
        running: false
        command: ["swww", "img", ""]
        onExited: (code, status) => {
            // swww done — refresh current wallpaper indicator
            currentProc.running = true
        }
    }

    Process {
        id: matugenProc
        running: false
        command: ["matugen", "image", "", "--source-color-index", "0"]
        onExited: (code, status) => {
            wpDrop._applying = false
        }
    }

    function applyWallpaper(path) {
        if (_applying) return
        _applying = true
        // update immediately so the highlight moves right away
        wpDrop.currentWallpaper = path
        swwwProc.command    = ["swww", "img", path,
            "--transition-type", "wipe",
            "--transition-angle", "30",
            "--transition-duration", "0.5"]
        matugenProc.command = ["matugen", "image", path, "--source-color-index", "0"]
        swwwProc.running    = true
        matugenProc.running = true
    }

    function ensureFocusedVisible() {
        if (wpDrop.focusedIndex < 0) return
        var row       = Math.floor(wpDrop.focusedIndex / wpDrop._cols)
        var itemY     = row * (wpDrop._cellH + 6)   // 6 = rowSpacing
        var itemBot   = itemY + wpDrop._cellH
        if (itemY < flickArea.contentY)
            flickArea.contentY = itemY
        else if (itemBot > flickArea.contentY + flickArea.height)
            flickArea.contentY = itemBot - flickArea.height
    }

    // Wait for the Wayland compositor to grant keyboard focus to the surface
    // before asking Qt to focus the Flickable — Qt.callLater fires too early.
    Timer {
        id: _focusTimer
        interval: 80
        repeat: false
        onTriggered: {
            flickArea.forceActiveFocus()
            wpDrop.ensureFocusedVisible()
        }
    }

        // ── Scrollable thumbnail grid ─────────────────────
        Flickable {
            id: flickArea
            focus: true

            Keys.onPressed: event => {
                var n = wpDrop.images.length
                if (n === 0) return
                var idx = wpDrop.focusedIndex
                if (idx < 0) idx = 0
                if (event.key === Qt.Key_Left) {
                    idx = Math.max(0, idx - 1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Right) {
                    idx = Math.min(n - 1, idx + 1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Up) {
                    idx = Math.max(0, idx - wpDrop._cols)
                    event.accepted = true
                } else if (event.key === Qt.Key_Down) {
                    idx = Math.min(n - 1, idx + wpDrop._cols)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (idx >= 0 && idx < n)
                        wpDrop.applyWallpaper(wpDrop.images[idx])
                    event.accepted = true
                    return
                } else {
                    return
                }
                wpDrop.focusedIndex = idx
                wpDrop.ensureFocusedVisible()
            }
            x: 16 + wpDrop._mx
            y: 16 + wpDrop.headerHeight + 10
            width:  wpDrop.panelWidth - wpDrop._mx * 2
            height: wpDrop.panelFullHeight - 10 - wpDrop._mx
            clip: true
            flickableDirection: Flickable.VerticalFlick
            contentWidth: width
            contentHeight: thumbGrid.implicitHeight

            // subtle scroll indicator
            Rectangle {
                visible: flickArea.contentHeight > flickArea.height
                anchors.right: parent.right
                anchors.rightMargin: -2
                y: flickArea.visibleArea.yPosition * flickArea.height
                width: 3
                height: flickArea.visibleArea.heightRatio * flickArea.height
                radius: 2
                color: Qt.rgba(wpDrop.accentColor.r,
                               wpDrop.accentColor.g,
                               wpDrop.accentColor.b, 0.4)
            }

            Grid {
                id: thumbGrid
                width: flickArea.width
                columns: wpDrop._cols
                columnSpacing: 6
                rowSpacing: 6

                Repeater {
                    model: wpDrop.images

                    Item {
                        id: thumbItem
                        width:  wpDrop._cellW
                        height: wpDrop._cellH

                        property bool isCurrent: modelData === wpDrop.currentWallpaper
                        property bool isFocused: index === wpDrop.focusedIndex
                        property bool hovered:   false

                        // Highlight ring for current wallpaper
                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: "transparent"
                            border.color: thumbItem.isCurrent
                                ? wpDrop.accentColor
                                : (thumbItem.isFocused
                                    ? Qt.rgba(wpDrop.accentColor.r,
                                              wpDrop.accentColor.g,
                                              wpDrop.accentColor.b, 0.9)
                                    : (thumbItem.hovered
                                        ? Qt.rgba(wpDrop.accentColor.r,
                                                  wpDrop.accentColor.g,
                                                  wpDrop.accentColor.b, 0.5)
                                        : "transparent"))
                            border.width: (thumbItem.isCurrent || thumbItem.isFocused) ? 2 : 1
                            z: 1
                            Behavior on border.color { ColorAnimation { duration: 160 } }
                        }

                        // Thumbnail image — clipped to rounded rect by the
                        // wrapping Rectangle (no per-thumb GPU layer needed).
                        Rectangle {
                            id: thumbClip
                            anchors.fill: parent
                            anchors.margins: thumbItem.isCurrent ? 2 : 1
                            radius: 5
                            color: "transparent"
                            // layer.enabled clips children to the rounded shape
                            // without any shader, keeping textures thumbnail-sized.
                            layer.enabled: true

                            Image {
                                anchors.fill: parent
                                source: "file://" + modelData
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                // Decode at 2× thumbnail size — avoids loading
                                // full-resolution wallpapers (saves 100s of MB).
                                sourceSize: Qt.size(Math.round(wpDrop._cellW * 2),
                                                    Math.round(wpDrop._cellH * 2))

                                // loading placeholder
                                Rectangle {
                                    anchors.fill: parent
                                    color: Qt.rgba(1, 1, 1, 0.04)
                                    visible: parent.status !== Image.Ready
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰸉"
                                        font.family: fontFamily
                                        font.pixelSize: 16
                                        color: Qt.rgba(1, 1, 1, 0.15)
                                    }
                                }
                            }
                        }

                        // Current-wallpaper badge
                        Rectangle {
                            visible: thumbItem.isCurrent
                            anchors {
                                bottom: parent.bottom
                                right: parent.right
                                bottomMargin: 4
                                rightMargin: 4
                            }
                            width: 10; height: 10; radius: 5
                            color: wpDrop.accentColor
                            z: 2
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: {
                                thumbItem.hovered = true
                                wpDrop.focusedIndex = index
                            }
                            onExited:  thumbItem.hovered = false
                            onClicked: {
                                wpDrop.applyWallpaper(modelData)
                                flickArea.forceActiveFocus()
                            }
                        }
                    }
                }
            }
        }
}
