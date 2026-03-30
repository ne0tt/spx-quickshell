import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../base"
import "../.."
// ============================================================
// WALLPAPER DROPDOWN — scrollable thumbnail grid
// Finds all images under ~/wallpaper/ recursively.
// Click a thumbnail to apply it with awww and save to settings.
// ============================================================
DropdownBase {
    id: wpDrop
    reloadableId: "wallpaperDropdown"

    implicitHeight:  710  // +40 for matugen scheme row
    panelFullHeight: 476  // +40 for matugen scheme row
    panelWidth:      620
    panelTitle:      "Wallpaper"
    panelIcon:       "󰸉"
    headerHeight:    34
    panelZ:          1   // same z-order as app launcher dropdown

    keyboardFocusEnabled: true

    // --------------------------------------------------------
    // STATE  
    // --------------------------------------------------------
    property var    images:          []
    property string currentWallpaper: config.currentWallpaper || ""  // Initialize from settings
    property var    _findArr:         []   // array accumulator — avoids O(n²) string concat
    property bool   _applying:        false
    property int    focusedIndex:     -1   // keyboard-nav cursor
    
    // Wallpaper folder configuration
    readonly property string wallpaperPath: {
        var folder = config.wallpaperFolder
        if (folder.startsWith("/")) {
            return folder  // Absolute path
        } else {
            // Relative to home directory
            var homePath = Qt.resolvedUrl("~/" + folder).toString()
            return homePath.startsWith("file://") ? homePath.replace("file://", "") : homePath
        }
    }
    readonly property bool includeSubdirs: config.wallpaperSubdirs

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
        refreshImages()
    }
    
    function refreshImages() {
        _findArr = []
        findProc.running = true
        currentProc.running = true
    }
    
    // Process to open folder selection dialog
    Process {
        id: folderSelectProc
        running: false
        command: ["sh", "-c", "if command -v zenity >/dev/null 2>&1; then zenity --file-selection --directory --title='Select Wallpaper Folder' 2>/dev/null; elif command -v kdialog >/dev/null 2>&1; then kdialog --getexistingdirectory ~ 'Select Wallpaper Folder' 2>/dev/null; else echo 'NO_DIALOG'; fi"]
        stdout: SplitParser {
            onRead: data => {
                var path = data.trim()
                if (path && path !== '' && path !== 'NO_DIALOG') {
                    config.wallpaperFolder = path
                    refreshImages()
                } else if (path === 'NO_DIALOG') {
                    console.log("No dialog tool available. Install zenity or kdialog for folder selection.")
                }
            }
        }
    }
    
    function selectFolder() {
        folderSelectProc.running = true
    }

    // --------------------------------------------------------
    // FIND IMAGES — now uses configurable folder and subdirectory settings
    // --------------------------------------------------------
    Process {
        id: findProc
        running: false
        command: buildFindCommand()
        
        function buildFindCommand() {
            var cmd = "find \"" + wpDrop.wallpaperPath + "\""
            
            // Add depth limit if subdirectories are disabled
            if (!wpDrop.includeSubdirs) {
                cmd += " -maxdepth 1"
            }
            
            cmd += " -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"
            
            return ["sh", "-c", cmd]
        }
        
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
    // READ CURRENT WALLPAPER — ask awww what is actually displayed
    // --------------------------------------------------------
    Process {
        id: currentProc
        running: false
        command: ["sh", "-c", "awww query 2>/dev/null | awk -F'image: ' '{print $2}' | awk '{print $1}' | tr -d ',' | head -1"]
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
        id: awwwProc
        running: false
        onExited: (code, status) => {
            currentProc.running = true
        }
    }

    Process {
        id: matugenProc
        running: false
        onExited: (code, status) => {
            wpDrop._applying = false
        }
    }

    function applyWallpaper(path) {
        if (_applying) return
        _applying = true
        
        // Save to settings using existing config system with immediate save
        config.currentWallpaper = path
        // Force immediate save instead of waiting for debounce timer
        Qt.callLater(function() {
            config._saveImmediately()
        })
        
        // update immediately so the highlight moves right away
        wpDrop.currentWallpaper = path
        awwwProc.command    = ["awww", "img", path,
            "--transition-type", "fade",
            "--transition-angle", "0",
            "--transition-duration", "0.3"]
        matugenProc.command = ["matugen", "image", path,
            "--source-color-index", "0",
            "--type", config.matugenType]
        
        awwwProc.running    = true
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

    // ────────────────────────────────────────────────────────────────
    // FOLDER CONTROLS
    // ────────────────────────────────────────────────────────────────
    
    // Folder path display and selection
    Item {
        x: 16 + wpDrop._mx
        y: 16 + wpDrop.headerHeight + 8
        width: wpDrop.panelWidth - wpDrop._mx * 2
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: Qt.rgba(wpDrop.dimColor.r, wpDrop.dimColor.g, wpDrop.dimColor.b, 0.1)
            border.color: Qt.rgba(wpDrop.dimColor.r, wpDrop.dimColor.g, wpDrop.dimColor.b, 0.2)
            border.width: 1

            // Left side - folder icon and path
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.horizontalCenter
                anchors.rightMargin: 10
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    font.family: wpDrop.fontFamily
                    font.pixelSize: 14
                    color: Colors.col_source_color
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: wpDrop.wallpaperPath
                    elide: Text.ElideMiddle
                    width: Math.max(100, parent.width - 30)  // Ensure minimum visible width
                    font.pixelSize: 11
                    color: wpDrop.textColor
                    font.bold: true
                }
            }

            // Right side controls
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Subdirectory checkbox
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60  // Fixed width for "Subdirs" + checkbox
                    height: 18
                    radius: 9
                    color: config.wallpaperSubdirs ? Qt.rgba(wpDrop.accentColor.r, wpDrop.accentColor.g, wpDrop.accentColor.b, 0.2) : "transparent"
                    border.color: wpDrop.accentColor
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            width: 12
                            height: 12
                            radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: config.wallpaperSubdirs ? wpDrop.accentColor : "transparent"
                            border.color: wpDrop.accentColor
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                font.pixelSize: 8
                                color: "white"
                                visible: config.wallpaperSubdirs
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Subdirs"
                            font.pixelSize: 9
                            color: wpDrop.textColor
                            font.bold: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            config.wallpaperSubdirs = !config.wallpaperSubdirs
                            wpDrop.refreshImages()
                        }
                    }
                }

                // Refresh button  
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 20
                    radius: 10
                    color: refreshBtn.containsMouse ? wpDrop.accentColor : Qt.rgba(wpDrop.accentColor.r, wpDrop.accentColor.g, wpDrop.accentColor.b, 0.5)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "🔄"
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: refreshBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wpDrop.refreshImages()
                    }
                }

                // Browse button
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                    height: 20
                    radius: 10
                    color: folderBtn.containsMouse ? wpDrop.accentColor : Qt.rgba(wpDrop.accentColor.r, wpDrop.accentColor.g, wpDrop.accentColor.b, 0.7)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Browse"
                        font.pixelSize: 10
                        color: "white"
                        font.bold: true
                    }

                    MouseArea {
                        id: folderBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wpDrop.selectFolder()
                    }
                }
            }
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
                } else if (event.key === Qt.Key_Escape) {
                    wpDrop.closePanel()
                    event.accepted = true
                    return
                } else {
                    return
                }
                wpDrop.focusedIndex = idx
                wpDrop.ensureFocusedVisible()
            }
            x: 16 + wpDrop._mx
            y: 16 + wpDrop.headerHeight + 8 + 32 + 8  // folder controls + margin
            width:  wpDrop.panelWidth - wpDrop._mx * 2
            height: wpDrop.panelFullHeight - (8 + 32 + 8) - (32 + 8) - wpDrop._mx  // subtract folder row + matugen row + margins
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

    // ── Matugen colour scheme selector ───────────────────────────────
    Item {
        x: 16 + wpDrop._mx
        y: flickArea.y + flickArea.height + 8
        width: wpDrop.panelWidth - wpDrop._mx * 2
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: Qt.rgba(wpDrop.dimColor.r, wpDrop.dimColor.g, wpDrop.dimColor.b, 0.1)
            border.color: Qt.rgba(wpDrop.dimColor.r, wpDrop.dimColor.g, wpDrop.dimColor.b, 0.2)
            border.width: 1

            Text {
                id: schemeLabel
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "Matugen Scheme"
                font.pixelSize: 10
                font.bold: true
                color: wpDrop.textColor
            }

            // Horizontally scrollable pill row
            Flickable {
                anchors.left: schemeLabel.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                contentWidth: schemePills.implicitWidth
                contentHeight: height
                interactive: contentWidth > width

                Row {
                    id: schemePills
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: [
                            "scheme-tonal-spot",
                            "scheme-content",
                            "scheme-expressive",
                            "scheme-fidelity",
                            "scheme-fruit-salad",
                            "scheme-monochrome",
                            "scheme-neutral",
                            "scheme-rainbow"
                        ]

                        delegate: Rectangle {
                            property bool active: modelData === config.matugenType
                            anchors.verticalCenter: parent.verticalCenter
                            height: 20
                            radius: 10
                            width: pillText.implicitWidth + 14
                            color: active
                                ? wpDrop.accentColor
                                : Qt.rgba(wpDrop.accentColor.r, wpDrop.accentColor.g, wpDrop.accentColor.b, 0.1)
                            border.color: wpDrop.accentColor
                            border.width: active ? 0 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                id: pillText
                                anchors.centerIn: parent
                                text: modelData.replace("scheme-", "")
                                font.pixelSize: 9
                                font.bold: active
                                color: active ? "#1a1a1a" : wpDrop.textColor
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    config.matugenType = modelData
                                    Qt.callLater(function() { config._saveImmediately() })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
