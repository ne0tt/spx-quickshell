pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../../base"
import "../../state"

// ============================================================
// DASHBOARD DROPDOWN — tabbed info panel with:
//   Tab 0 — Dashboard : weather card + system info + mini media + calendar
//   Tab 1 — Media     : full-size media player
//   Tab 2 — Performance: CPU + RAM usage bars
//   Tab 3 — Weather   : current conditions + 3-day forecast
// ============================================================
DropdownBase {
    id: dash
    reloadableId: "dashboardDropdown"

    // Receive keyboard events while open so Tab can cycle tabs
    WlrLayershell.keyboardFocus: dash.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    panelWidth: 560

    // Content y-offsets (ears 16 + top-pad 10 + tab-bar 36 + gap 8 = 70)
    readonly property int _tabBarY: 16 + 10          // tab bar top inside _contentArea
    readonly property int _contentY: 16 + 10 + 36 + 8 // tab content top

    // Per-tab panelFullHeight: must accommodate _contentY + content + bottom-pad
    readonly property int _dashH:    _contentY + 155 + 10 + 200 + 4  // info row + cal
    readonly property int _mediaH:   _contentY + 179 + 12
    readonly property int _perfH:    _contentY + 194 + 12
    readonly property int _weatherH: _contentY + 455 + 12  // current + hourly + weekly + sunrise

    panelFullHeight: {
        switch (dash._tab) {
            case 0: return dash._dashH
            case 1: return dash._mediaH
            case 2: return dash._perfH
            case 3: return dash._weatherH
            default: return dash._mediaH
        }
    }

    implicitHeight: panelFullHeight + 52

    // ── Hourly: next 24 entries from current hour ──────────────
    readonly property var _hourlyNext24: {
        var now = new Date()
        var nowStr = now.getFullYear() + "-" +
                     String(now.getMonth() + 1).padStart(2, "0") + "-" +
                     String(now.getDate()).padStart(2, "0") + "T" +
                     String(now.getHours()).padStart(2, "0") + ":00"
        var idx = 0
        for (var i = 0; i < AppState.wHourly.length; i++) {
            if (AppState.wHourly[i].time >= nowStr) { idx = i; break }
        }
        return AppState.wHourly.slice(idx, idx + 24)
    }

    // ── State ─────────────────────────────────────────────────
    property int    _tab:         0

    property string _uptime:      "…"
    property int    _updates:     -1  // -1 = loading, 0 = up to date, >0 = count
    property string _mediaTitle:  "No media playing"
    property string _mediaArtist: ""
    property string _mediaArtUrl: ""
    property string _mediaStatus: "Stopped"
    property bool   _mediaAvail:  false

    property int    _cpuPercent:  0
    property int    _ramUsed:     0
    property int    _ramTotal:    0
    property int    _ramPercent:  0
    property int    _diskPercent: 0
    property int    _diskUsedGB:  0
    property int    _diskTotalGB: 0
    property int    _swapUsed:    0
    property int    _swapTotal:   0
    property int    _swapPercent: 0
    property string _load1:       "0.00"
    property string _load5:       "0.00"
    property string _load15:      "0.00"

    // Tab bar width helpers (content width - 3 gaps of 6px)
    readonly property int _cw: panelWidth - 28
    readonly property real _tabW: (_cw - 18) / 4

    // ── Lifecycle ─────────────────────────────────────────────
    onAboutToOpen: {
        _tab      = 0
        _updates  = -1
        AppState.refresh()
        uptimeProc.running  = true
        mediaProc.running   = true
        perfProc.running    = true
        updatesProc.running = true
    }

    Timer {
        interval: 3000
        running:  dash.isOpen
        repeat:   true
        onTriggered: {
            if (dash._tab === 0) uptimeProc.running = true
            if (dash._tab === 1) mediaProc.running  = true
            if (dash._tab === 0 || dash._tab === 2) perfProc.running = true
        }
    }

    // ── Available updates ─────────────────────────────────────
    Process {
        id: updatesProc
        running: false
        command: ["bash", "-c", "checkupdates 2>/dev/null | wc -l || echo 0"]
        stdout: SplitParser {
            onRead: data => {
                var n = parseInt(data.trim())
                dash._updates = isNaN(n) ? 0 : n
            }
        }
    }

    // ── Uptime ────────────────────────────────────────────────
    Process {
        id: uptimeProc
        running: false
        command: ["sh", "-c",
            "awk '{s=int($1);h=int(s/3600);m=int((s%3600)/60);" +
            "if(h>0)printf \"up %dh %dm\",h,m;else printf \"up %dm\",m}'" +
            " /proc/uptime"]
        stdout: SplitParser {
            onRead: data => dash._uptime = data.trim()
        }
    }

    // ── Media info ────────────────────────────────────────────
    Process {
        id: mediaProc
        running: false
        command: ["bash", "-c",
            "playerctl -a metadata --format '{{status}}|{{title}}|{{artist}}|{{mpris:artUrl}}'" +
            " 2>/dev/null | awk -F'|' '$1==\"Playing\"{print;found=1;exit}" +
            " {last=$0} END{if(!found&&NR>0)print last}' || echo 'Stopped|||'"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split("|")
                if (p.length >= 3) {
                    dash._mediaStatus = p[0] || "Stopped"
                    dash._mediaTitle  = p[1] || "No media playing"
                    dash._mediaArtist = p[2] || ""
                    dash._mediaArtUrl = p.length > 3 ? p[3] : ""
                    dash._mediaAvail  = (dash._mediaStatus === "Playing" || dash._mediaStatus === "Paused")
                                        && dash._mediaTitle !== "" && dash._mediaTitle !== "No media playing"
                }
            }
        }
    }

    // Media playback control (command set dynamically on click)
    Process {
        id: ctrlProc
        running: false
        command: []
        onRunningChanged: if (!running) { command = []; mediaProc.running = true }
    }

    // ── Performance ───────────────────────────────────────────
    Process {
        id: perfProc
        running: false
        command: ["bash", "-c",
            "CPU=$(vmstat 1 2 2>/dev/null | tail -1 | awk '{printf \"%.0f\",100-$15}' 2>/dev/null || echo 0);" +
            " MEM=$(free -m 2>/dev/null | awk '/^Mem:/{print $3\"|\"$2}');" +
            " DISK=$(df / 2>/dev/null | awk 'NR==2{gsub(/%/,\"\",$5); printf \"%s|%d|%d\",$5,int($3/1024),int($2/1024)}' || echo '0|0|0');" +
            " SWAP=$(free -m 2>/dev/null | awk '/^Swap:/{if($2>0) printf \"%d|%d|%.0f\",$3,$2,$3*100/$2; else print \"0|0|0\"}' || echo '0|0|0');" +
            " LOAD=$(cat /proc/loadavg 2>/dev/null | awk '{print $1\"|\"$2\"|\"$3}' || echo '0.00|0.00|0.00');" +
            " echo \"cpu=$CPU\"; echo \"mem=$MEM\"; echo \"disk=$DISK\"; echo \"swap=$SWAP\"; echo \"load=$LOAD\""]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.startsWith("cpu=")) {
                    dash._cpuPercent = parseInt(line.substring(4)) || 0
                } else if (line.startsWith("mem=")) {
                    var p = line.substring(4).split("|")
                    if (p.length === 2) {
                        dash._ramUsed    = parseInt(p[0]) || 0
                        dash._ramTotal   = parseInt(p[1]) || 0
                        dash._ramPercent = dash._ramTotal > 0
                            ? Math.round(dash._ramUsed * 100 / dash._ramTotal) : 0
                    }
                } else if (line.startsWith("disk=")) {
                    var dp = line.substring(5).split("|")
                    dash._diskPercent = parseInt(dp[0]) || 0
                    dash._diskUsedGB  = dp.length > 1 ? parseInt(dp[1]) || 0 : 0
                    dash._diskTotalGB = dp.length > 2 ? parseInt(dp[2]) || 0 : 0
                } else if (line.startsWith("swap=")) {
                    var sp = line.substring(5).split("|")
                    if (sp.length >= 3) {
                        dash._swapUsed    = parseInt(sp[0]) || 0
                        dash._swapTotal   = parseInt(sp[1]) || 0
                        dash._swapPercent = parseInt(sp[2]) || 0
                    }
                } else if (line.startsWith("load=")) {
                    var lp = line.substring(5).split("|")
                    dash._load1  = lp.length > 0 ? lp[0] : "0.00"
                    dash._load5  = lp.length > 1 ? lp[1] : "0.00"
                    dash._load15 = lp.length > 2 ? lp[2] : "0.00"
                }
            }
        }
    }

    // ── Tab key navigation ──────────────────────────────────
    Item {
        focus: true
        Keys.onTabPressed:    { dash._tab = (dash._tab + 1) % 4; dash.triggerHex() }
        Keys.onBacktabPressed: { dash._tab = (dash._tab + 3) % 4; dash.triggerHex() }
        Keys.onEscapePressed: dash.closePanel()
    }

    // ══════════════════════════════════════════════════════════
    // TAB BAR
    // ══════════════════════════════════════════════════════════
    Row {
        x:       16 + 14
        y:       dash._tabBarY
        width:   dash._cw
        height:  36
        spacing: 6

        Repeater {
            model: [
                { icon: "󰕮", label: "Dashboard"   },
                { icon: "󰝚", label: "Media"        },
                { icon: "󰻠", label: "Performance"  },
                { icon: "󰖕", label: "Weather"      }
            ]
            delegate: Rectangle {
                id: tabItem

                required property var modelData
                required property int index

                width:  dash._tabW
                height: 36
                radius: 7

                color: dash._tab === tabItem.index
                    ? Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.15)
                    : tabMA.containsMouse
                        ? Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.07)
                        : "transparent"
                border.color: dash._tab === tabItem.index
                    ? Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.35)
                    : "transparent"
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: tabItem.modelData.icon
                        font.family: config.fontFamily
                        font.styleName: "Solid"
                        font.pixelSize: 13
                        color: dash._tab === tabItem.index ? dash.accentColor : dash.dimColor
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        text: tabItem.modelData.label
                        font.family: config.fontFamily
                        font.pixelSize: 13
                        font.weight: dash._tab === tabItem.index ? Font.Medium : Font.Normal
                        color: dash._tab === tabItem.index ? dash.accentColor : dash.dimColor
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                MouseArea {
                    id: tabMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    { dash._tab = tabItem.index; dash.triggerHex() }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    // TAB 0: DASHBOARD
    // ══════════════════════════════════════════════════════════
    Item {
        x:       16 + 14
        y:       dash._contentY
        width:   dash._cw
        visible: dash._tab === 0
        height:  155 + 10 + 200

        readonly property real colW:      (width - 10) / 2
        readonly property real weatherW:  colW / 2
        readonly property real sysinfoW:  width - weatherW - 10

        // ── Weather card ──────────────────────────────────────
        Rectangle {
            x: 0; y: 0
            width: parent.weatherW; height: 155
            radius: 10
            color:        Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.08)
            border.color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.20)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 5

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: AppState.wIcon
                    font.family: config.fontFamily
                    font.styleName: "Solid"
                    font.pixelSize: 44
                    color: dash.accentColor
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: AppState.wTemp
                    color: dash.textColor
                    font.pixelSize: 22
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: AppState.wDesc
                    color: dash.dimColor
                    font.pixelSize: 11
                }
            }
        }

        // ── System info card ──────────────────────────────────
        Rectangle {
            x: parent.weatherW + 10; y: 0
            width: parent.sysinfoW; height: 155
            radius: 10
            color:        Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.08)
            border.color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.20)
            border.width: 1

            // Left: system info text
            Column {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 14; topMargin: 14; bottomMargin: 14 }
                width: parent.width * 0.45
                spacing: 7
                Row { spacing: 8
                    Text { text: "󰣇"; font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 14; color: dash.accentColor; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Arch Linux"; color: dash.textColor; font.pixelSize: 13; font.family: config.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                }
                Row { spacing: 8
                    Text { text: "󱗃"; font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 14; color: dash.accentColor; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Hyprland"; color: dash.textColor; font.pixelSize: 13; font.family: config.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                }
                Row { spacing: 8
                    Text { text: "󰔛"; font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 14; color: dash.accentColor; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: dash._uptime; color: dash.textColor; font.pixelSize: 13; font.family: config.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    spacing: 8

                    Text {
                        id: updatesIcon
                        text: "󰏖"; font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 14
                        color: dash._updates > 0 ? dash.accentColor : dash.dimColor
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                    Text {
                        id: updatesLabel
                        color: dash._updates > 0 ? dash.accentColor : dash.textColor
                        font.pixelSize: 13; font.family: config.fontFamily; anchors.verticalCenter: parent.verticalCenter
                        text: dash._updates < 0 ? "checking…"
                            : dash._updates === 0 ? "system up to date"
                            : dash._updates === 1 ? "1 update available"
                            : dash._updates + " updates available"
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }

                    // Flash white when updates first appear
                    SequentialAnimation {
                        id: updateFlashAnim
                        running: false
                        loops: 6
                        ParallelAnimation {
                            ColorAnimation { target: updatesIcon;  property: "color"; to: "white";           duration: 300 }
                            ColorAnimation { target: updatesLabel; property: "color"; to: "white";           duration: 300 }
                        }
                        ParallelAnimation {
                            ColorAnimation { target: updatesIcon;  property: "color"; to: dash.accentColor; duration: 300 }
                            ColorAnimation { target: updatesLabel; property: "color"; to: dash.accentColor; duration: 300 }
                        }
                        onStopped: {
                            updatesIcon.color  = Qt.binding(() => dash._updates > 0 ? dash.accentColor : dash.dimColor)
                            updatesLabel.color = Qt.binding(() => dash._updates > 0 ? dash.accentColor : dash.textColor)
                        }
                    }

                    Connections {
                        target: dash
                        function on_UpdatesChanged() {
                            if (dash._updates > 0) updateFlashAnim.restart()
                        }
                    }
                }
            }

            // Right: CPU / RAM / Disk bars
            Column {
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: 14; topMargin: 14; bottomMargin: 14 }
                width: parent.width * 0.50
                spacing: 10
                Repeater {
                    model: [
                        { label: "CPU",  pct: dash._cpuPercent  },
                        { label: "RAM",  pct: dash._ramPercent  },
                        { label: "Disk", pct: dash._diskPercent }
                    ]
                    delegate: Row {
                        required property var modelData
                        width: parent.width; spacing: 6
                        Text {
                            text: modelData.label
                            color: dash.dimColor; font.pixelSize: 11; font.family: config.fontFamily
                            width: 29; anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            width: parent.width - 29 - 31 - 12; height: 6; radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.15)
                            Rectangle {
                                width: parent.width * (modelData.pct / 100); height: parent.height; radius: 3
                                color: modelData.pct > 85 ? "#ff6b6b" : dash.accentColor
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                        }
                        Text {
                            text: modelData.pct + "%"
                            color: dash.accentColor; font.pixelSize: 11; font.family: config.fontFamily
                            width: 31; horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        // ── Clock + calendar row ──────────────────────────────
        Item {
            x: 0; y: 155 + 10
            width: parent.width; height: 200

            readonly property real calW:   (parent.width - 10) * (1.25 / 2.25)
            readonly property real clockW: (parent.width - 10) - calW
            readonly property real halfW:  clockW   // alias used by children

            // Left: clock + date
            Item {
                x: 0; y: 0
                width: parent.halfW; height: parent.height

                readonly property var _longMonthNames: [
                    "January","February","March","April","May","June",
                    "July","August","September","October","November","December"
                ]
                readonly property var _dayNames: [
                    "Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"
                ]

                Timer {
                    interval: 1000; running: dash.isOpen && dash._tab === 0; repeat: true
                    onTriggered: { clockTime.text = Qt.formatTime(new Date(), "hh:mm") }
                }

                // Time display
                Row {
                    id: clockRow
                    anchors { top: parent.top; topMargin: 20; horizontalCenter: parent.horizontalCenter }
                    spacing: 2

                    Text {
                        id: clockTime
                        text: Qt.formatTime(new Date(), "hh:mm")
                        color: dash.textColor; font.pixelSize: 58; font.bold: true; font.family: config.fontFamily
                    }
                }

                // Long date
                Column {
                    anchors { top: clockRow.bottom; topMargin: 8; horizontalCenter: parent.horizontalCenter }
                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.parent._dayNames[new Date().getDay()]
                        color: dash.accentColor; font.pixelSize: 22; font.bold: true; font.family: config.fontFamily
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: new Date().getDate() + " " + parent.parent._longMonthNames[new Date().getMonth()] + " " + new Date().getFullYear()
                        color: dash.dimColor; font.pixelSize: 19; font.family: config.fontFamily
                    }
                }
            }

            // Right: inline calendar
            Item {
                id: inlineCal
                x: parent.clockW + 10; y: 0
                width: parent.calW; height: parent.height

                property int displayYear:   new Date().getFullYear()
                property int displayMonth:  new Date().getMonth()

                readonly property var _monthNames: [
                    "January","February","March","April","May","June",
                    "July","August","September","October","November","December"
                ]

                property var calDays: {
                    var yr = displayYear, mo = displayMonth
                    var firstDay   = new Date(yr, mo, 1).getDay()
                    var total      = new Date(yr, mo+1, 0).getDate()
                    var prevTotal  = new Date(yr, mo, 0).getDate()
                    var tod        = new Date()
                    var todayD     = (tod.getFullYear() === yr && tod.getMonth() === mo) ? tod.getDate() : -1
                    var days       = []
                    // Leading days from previous month
                    for (var i = firstDay - 1; i >= 0; i--)
                        days.push({ day: prevTotal - i, isToday: false, overflow: true })
                    // Current month
                    for (var d = 1; d <= total; d++)
                        days.push({ day: d, isToday: d === todayD, overflow: false })
                    // Trailing days from next month
                    var next = 1
                    while (days.length % 7 !== 0)
                        days.push({ day: next++, isToday: false, overflow: true })
                    return days
                }

                // Month nav header
                Item {
                    id: calHdr
                    y: 0; width: parent.width; height: 24

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: "‹"; color: dash.accentColor; font.pixelSize: 18; font.bold: true
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (inlineCal.displayMonth === 0) { inlineCal.displayMonth = 11; inlineCal.displayYear-- }
                                else inlineCal.displayMonth--
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: inlineCal._monthNames[inlineCal.displayMonth] + "  " + inlineCal.displayYear
                        color: dash.accentColor; font.pixelSize: 13; font.bold: true; font.family: config.fontFamily
                    }
                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: "›"; color: dash.accentColor; font.pixelSize: 18; font.bold: true
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (inlineCal.displayMonth === 11) { inlineCal.displayMonth = 0; inlineCal.displayYear++ }
                                else inlineCal.displayMonth++
                            }
                        }
                    }
                }

                // Day-of-week labels
                Row {
                    id: dowRow
                    y: 28; width: parent.width; height: 14
                    readonly property real cellW: inlineCal.width / 7

                    Repeater {
                        model: ["Su","Mo","Tu","We","Th","Fr","Sa"]
                        delegate: Text {
                            required property string modelData
                            width: dowRow.cellW
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.55)
                            font.pixelSize: 13; font.bold: true; font.family: config.fontFamily
                        }
                    }
                }

                // Date grid
                Grid {
                    id: dayGrid
                    y: 46; width: parent.width; columns: 7
                    readonly property real cellW: inlineCal.width / 7
                    readonly property int  cellH: 24

                    Repeater {
                        model: ScriptModel { values: inlineCal.calDays }
                        delegate: Item {
                            required property var modelData
                            width:  dayGrid.cellW
                            height: dayGrid.cellH

                            Rectangle {
                                anchors.centerIn: parent
                                width: 20; height: 20; radius: 10
                                color: modelData.isToday ? dash.accentColor : "transparent"
                                visible: !modelData.overflow && modelData.isToday
                            }
                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                color: modelData.overflow
                                    ? Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.25)
                                    : modelData.isToday ? dash.panelColor : dash.accentColor
                                font.pixelSize: 13; font.bold: modelData.isToday
                                font.family: config.fontFamily
                            }
                        }
                    }
                }
            }
        }

        // (slider moved to Media tab)
    }

    // ══════════════════════════════════════════════════════════
    // TAB 1: MEDIA
    // ══════════════════════════════════════════════════════════
    Item {
        x:       16 + 14
        y:       dash._contentY
        width:   dash._cw
        height:  179
        visible: dash._tab === 1

        property int _mediaDragVol: -1
        readonly property int _mediaDisplayVol: _mediaDragVol >= 0 ? _mediaDragVol : AppState.volume

        Rectangle {
            anchors.fill: parent; radius: 10
            color:        Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.06)
            border.color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.15)
            border.width: 1
        }

        Rectangle {
            id: bigArt
            width: 95; height: 95; radius: 10
            anchors { left: parent.left; leftMargin: 15; top: parent.top; topMargin: 15 }
            color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.15)

            // Animated border — pulses between accent and a complementary hue while playing
            border.width: dash._mediaStatus === "Playing" ? 2 : 0
            border.color: {
                if (dash._mediaStatus !== "Playing") return "transparent"
                var t = (Math.sin((_artAngle % 360) / 360 * Math.PI * 4) + 1) / 2
                var r = dash.accentColor.r * (1 - t) + 0.769 * t
                var g = dash.accentColor.g * (1 - t) + 0.498 * t
                var b = dash.accentColor.b * (1 - t) + 0.835 * t
                return Qt.rgba(r, g, b, 1.0)
            }
            Behavior on border.width { NumberAnimation { duration: 200 } }

            property real _artAngle: 0
            Timer {
                interval: 50
                running: dash._mediaStatus === "Playing" && dash.isOpen
                repeat: true
                onTriggered: bigArt._artAngle = (bigArt._artAngle + 3) % 360
            }

            Rectangle {
                id: bigArtMask
                anchors { fill: parent; margins: bigArt.border.width }
                radius: bigArt.radius - 1
                color: "white"
                layer.enabled: true
                visible: false
            }
            Image {
                id: bigArtImage
                anchors { fill: parent; margins: bigArt.border.width }
                source: dash._mediaArtUrl
                fillMode: Image.PreserveAspectCrop
                smooth: true; asynchronous: true
                visible: dash._mediaArtUrl !== "" && status === Image.Ready
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: bigArtMask
                }
            }
            Text {
                anchors.centerIn: parent
                visible: bigArtImage.status !== Image.Ready || dash._mediaArtUrl === ""
                text: "󰎆"; font.family: config.fontFamily; font.styleName: "Solid"
                font.pixelSize: 36; color: dash.accentColor
            }
        }

        Column {
            anchors {
                left: bigArt.right; leftMargin: 24
                right: parent.right; rightMargin: 28
                top: parent.top; topMargin: 15
            }
            spacing: 10

            Item {
                id: mediaTitleClip
                width: parent.width; height: 20
                clip: true

                Text {
                    id: mediaTitleText
                    text: dash._mediaAvail ? dash._mediaTitle : "No media playing"
                    color: dash.textColor; font.pixelSize: 15; font.bold: true
                    font.family: config.fontFamily

                    property bool needsScroll: paintedWidth > mediaTitleClip.width
                    SequentialAnimation {
                        running: mediaTitleText.needsScroll && dash.isOpen
                        loops: Animation.Infinite
                        PauseAnimation { duration: 2000 }
                        NumberAnimation {
                            target: mediaTitleText; property: "x"
                            from: 0; to: mediaTitleClip.width - mediaTitleText.paintedWidth - 4
                            duration: Math.max(3000, mediaTitleText.paintedWidth * 20)
                            easing.type: Easing.InOutQuad
                        }
                        PauseAnimation { duration: 1500 }
                        NumberAnimation {
                            target: mediaTitleText; property: "x"
                            from: mediaTitleClip.width - mediaTitleText.paintedWidth - 4; to: 0
                            duration: Math.max(3000, mediaTitleText.paintedWidth * 20)
                            easing.type: Easing.InOutQuad
                        }
                    }
                    onNeedsScrollChanged: if (!needsScroll) x = 0
                    onTextChanged: { x = 0 }
                }
            }
            Text {
                width: parent.width
                text:    dash._mediaArtist
                visible: dash._mediaArtist !== ""
                color: dash.dimColor; font.pixelSize: 13
                elide: Text.ElideRight; font.family: config.fontFamily
            }

            Row {
                spacing: 16
                topPadding: 4
                opacity: dash._mediaAvail ? 1.0 : 0.35

                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: prevHov.containsMouse
                        ? Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.15)
                        : Qt.rgba(dash.dimColor.r, dash.dimColor.g, dash.dimColor.b, 0.1)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text { anchors.centerIn: parent; text: "󰒮"; font.family: config.fontFamily; font.pixelSize: 16; color: dash.accentColor }
                    MouseArea {
                        id: prevHov; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true; enabled: dash._mediaAvail
                        onClicked: { ctrlProc.command = ["playerctl","previous"]; ctrlProc.running = true }
                    }
                }
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: playHov.containsMouse
                        ? Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.25)
                        : Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.15)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text { anchors.centerIn: parent; text: dash._mediaStatus === "Playing" ? "󰏤" : "󰐊"; font.family: config.fontFamily; font.pixelSize: 18; color: dash.accentColor }
                    MouseArea {
                        id: playHov; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true; enabled: dash._mediaAvail
                        onClicked: { ctrlProc.command = ["playerctl","play-pause"]; ctrlProc.running = true }
                    }
                }
                Rectangle {
                    width: 40; height: 40; radius: 20
                    color: nextHov.containsMouse
                        ? Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.15)
                        : Qt.rgba(dash.dimColor.r, dash.dimColor.g, dash.dimColor.b, 0.1)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text { anchors.centerIn: parent; text: "󰒭"; font.family: config.fontFamily; font.pixelSize: 16; color: dash.accentColor }
                    MouseArea {
                        id: nextHov; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true; enabled: dash._mediaAvail
                        onClicked: { ctrlProc.command = ["playerctl","next"]; ctrlProc.running = true }
                    }
                }
            }
        }

        // ── Volume slider ──────────────────────────────────────────
        Item {
            id: mediaVolContainer
            x: 20; y: 125
            width: parent.width - 40; height: 44

            Text {
                id: mediaVolPct
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: (AppState.muted ? 0 : mediaVolContainer.parent._mediaDisplayVol) + "%"
                color: dash.accentColor; font.pixelSize: 14; font.family: config.fontFamily
                width: 38; horizontalAlignment: Text.AlignRight
            }

            Item {
                anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: mediaVolPct.left; rightMargin: 8 }
                height: 40

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 6; radius: 3
                    color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.15)

                    Rectangle {
                        width: parent.width * (AppState.muted ? 0 : mediaVolContainer.parent._mediaDisplayVol / 100)
                        height: parent.height; radius: 3
                        color: AppState.muted ? dash.dimColor : dash.accentColor
                    }
                }

                Rectangle {
                    id: mediaVolHandle
                    width: 18; height: 18; radius: 9
                    color: dash.accentColor
                    border.width: 1
                    border.color: dash.panelColor
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(
                        parent.width - width,
                        (AppState.muted ? 0 : mediaVolContainer.parent._mediaDisplayVol / 100) * (parent.width - width)
                    ))
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true

                    function setFromX(mx) {
                        var newVol = Math.round(Math.max(0, Math.min(100,
                            mx / (parent.width - mediaVolHandle.width) * 100
                        )))
                        mediaVolContainer.parent._mediaDragVol = newVol
                        AppState.setVolume(newVol)
                    }

                    onPressed:         mouse => setFromX(mouse.x)
                    onPositionChanged: mouse => { if (pressed) setFromX(mouse.x) }
                    onReleased: mediaVolContainer.parent._mediaDragVol = -1
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    // TAB 2: PERFORMANCE
    // ══════════════════════════════════════════════════════════
    Item {
        id: perfTab
        x:       16 + 14
        y:       dash._contentY
        width:   dash._cw
        height:  194
        visible: dash._tab === 2
        onVisibleChanged: if (visible) perfProc.running = true

        function fmtMiB(mib) {
            if (mib >= 1024 * 1024) return (mib / (1024 * 1024)).toFixed(1) + " TiB"
            if (mib >= 1024)        return (mib / 1024).toFixed(1) + " GiB"
            return mib + " MiB"
        }
        function fmtGB(gb) {
            if (gb >= 1024) return (gb / 1024).toFixed(1) + " TB"
            return gb + " GB"
        }

        Column {
            anchors.fill: parent
            spacing: 16

            // Circular gauges row
            Row {
                width: parent.width; height: 150

                // ── CPU gauge ──────────────────────────────────
                Item {
                    width: parent.width / 3; height: 150
                    property real _anim: dash._cpuPercent
                    Behavior on _anim { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                    on_AnimChanged: cpuCanvas.requestPaint()

                    Canvas {
                        id: cpuCanvas
                        width: 100; height: 100
                        anchors { top: parent.top; topMargin: 10; horizontalCenter: parent.horizontalCenter }
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = 50, cy = 50, r = 38, lw = 9
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, Math.PI * 2)
                            ctx.strokeStyle = Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.15).toString()
                            ctx.lineWidth = lw; ctx.stroke()
                            var p = parent._anim / 100
                            if (p > 0) {
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * p)
                                ctx.strokeStyle = (dash._cpuPercent > 85 ? "#ff6b6b" : Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 1.0)).toString()
                                ctx.lineWidth = lw; ctx.lineCap = "round"; ctx.stroke()
                            }
                        }
                        Connections { target: dash; function onAccentColorChanged() { cpuCanvas.requestPaint() } }
                    }
                    Text {
                        anchors.centerIn: cpuCanvas
                        text: dash._cpuPercent + "%"
                        color: dash.textColor; font.pixelSize: 15; font.bold: true; font.family: config.fontFamily
                    }
                    Column {
                        anchors { top: cpuCanvas.bottom; topMargin: 6; horizontalCenter: parent.horizontalCenter }
                        spacing: 2
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "CPU"; color: dash.textColor; font.pixelSize: 13; font.weight: Font.Medium; font.family: config.fontFamily }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "All cores avg"; color: dash.dimColor; font.pixelSize: 10; font.family: config.fontFamily }
                    }
                }

                // ── RAM gauge ──────────────────────────────────
                Item {
                    width: parent.width / 3; height: 150
                    property real _anim: dash._ramPercent
                    Behavior on _anim { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                    on_AnimChanged: ramCanvas.requestPaint()

                    Canvas {
                        id: ramCanvas
                        width: 100; height: 100
                        anchors { top: parent.top; topMargin: 10; horizontalCenter: parent.horizontalCenter }
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = 50, cy = 50, r = 38, lw = 9
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, Math.PI * 2)
                            ctx.strokeStyle = Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.15).toString()
                            ctx.lineWidth = lw; ctx.stroke()
                            var p = parent._anim / 100
                            if (p > 0) {
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * p)
                                ctx.strokeStyle = (dash._ramPercent > 85 ? "#ff6b6b" : Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 1.0)).toString()
                                ctx.lineWidth = lw; ctx.lineCap = "round"; ctx.stroke()
                            }
                        }
                        Connections { target: dash; function onAccentColorChanged() { ramCanvas.requestPaint() } }
                    }
                    Text {
                        anchors.centerIn: ramCanvas
                        text: dash._ramPercent + "%"
                        color: dash.textColor; font.pixelSize: 15; font.bold: true; font.family: config.fontFamily
                    }
                    Column {
                        anchors { top: ramCanvas.bottom; topMargin: 6; horizontalCenter: parent.horizontalCenter }
                        spacing: 2
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "RAM"; color: dash.textColor; font.pixelSize: 13; font.weight: Font.Medium; font.family: config.fontFamily }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: perfTab.fmtMiB(dash._ramUsed) + " / " + perfTab.fmtMiB(dash._ramTotal); color: dash.dimColor; font.pixelSize: 10; font.family: config.fontFamily }
                    }
                }

                // ── Disk gauge ─────────────────────────────────
                Item {
                    width: parent.width / 3; height: 150
                    property real _anim: dash._diskPercent
                    Behavior on _anim { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                    on_AnimChanged: diskCanvas.requestPaint()

                    Canvas {
                        id: diskCanvas
                        width: 100; height: 100
                        anchors { top: parent.top; topMargin: 10; horizontalCenter: parent.horizontalCenter }
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = 50, cy = 50, r = 38, lw = 9
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, Math.PI * 2)
                            ctx.strokeStyle = Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.15).toString()
                            ctx.lineWidth = lw; ctx.stroke()
                            var p = parent._anim / 100
                            if (p > 0) {
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * p)
                                ctx.strokeStyle = (dash._diskPercent > 85 ? "#ff6b6b" : Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 1.0)).toString()
                                ctx.lineWidth = lw; ctx.lineCap = "round"; ctx.stroke()
                            }
                        }
                        Connections { target: dash; function onAccentColorChanged() { diskCanvas.requestPaint() } }
                    }
                    Text {
                        anchors.centerIn: diskCanvas
                        text: dash._diskPercent + "%"
                        color: dash.textColor; font.pixelSize: 15; font.bold: true; font.family: config.fontFamily
                    }
                    Column {
                        anchors { top: diskCanvas.bottom; topMargin: 6; horizontalCenter: parent.horizontalCenter }
                        spacing: 2
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Disk"; color: dash.textColor; font.pixelSize: 13; font.weight: Font.Medium; font.family: config.fontFamily }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: perfTab.fmtGB(dash._diskUsedGB) + " / " + perfTab.fmtGB(dash._diskTotalGB); color: dash.dimColor; font.pixelSize: 10; font.family: config.fontFamily }
                    }
                }
            }

            // Refresh link
            Item {
                width: parent.width; height: 28

                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: "↻  Refresh"
                    color: rfHov.containsMouse ? dash.accentColor : dash.dimColor
                    font.pixelSize: 12; font.family: config.fontFamily
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: rfHov
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: perfProc.running = true
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    // TAB 3: WEATHER
    // ══════════════════════════════════════════════════════════
    Item {
        x:       16 + 14
        y:       dash._contentY
        width:   dash._cw
        height:  431
        visible: dash._tab === 3

        Text {
            visible: AppState.wLoading
            anchors.centerIn: parent
            text: "Fetching weather…"; color: dash.dimColor; font.pixelSize: 13; font.family: config.fontFamily
        }

        Column {
            visible: !AppState.wLoading
            anchors.fill: parent
            spacing: 10

            // ── Current conditions card ──────────────────────────────
            Rectangle {
                width: parent.width; height: 125; radius: 10
                color:        Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.08)
                border.color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.18)
                border.width: 1

                Text {
                    id: bigWIcon
                    anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                    text: AppState.wIcon
                    font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 64
                    color: dash.accentColor
                }
                Column {
                    anchors { left: bigWIcon.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    Text { text: AppState.wTemp;  color: dash.textColor; font.pixelSize: 24; font.bold: true }
                    Text { text: AppState.wDesc;  color: dash.dimColor;  font.pixelSize: 13 }
                    Text { text: "Feels like " + AppState.wFeels; color: dash.dimColor; font.pixelSize: 12 }
                }
                Column {
                    anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Row { spacing: 6
                        Text { text: "󰖝"; font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 12; color: dash.accentColor }
                        Text { text: AppState.wWind; color: dash.dimColor; font.pixelSize: 12 }
                    }
                    Row { spacing: 6
                        Text { text: ""; font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 12; color: dash.accentColor }
                        Text { text: AppState.wHumidity; color: dash.dimColor; font.pixelSize: 12 }
                    }
                    Row { spacing: 6
                        Text { text: "󰖛"; font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 12; color: dash.accentColor }
                        Text { text: AppState.wSunrise; color: dash.dimColor; font.pixelSize: 12 }
                    }
                }
            }

            // ── Hourly strip (next 24 h) ─────────────────────────────
            Item {
                width: parent.width; height: 106

                Text {
                    id: hourlyLabel
                    text: "Next 24 hours"
                    color: dash.dimColor; font.pixelSize: 10; font.family: config.fontFamily
                    anchors { top: parent.top; left: parent.left }
                }

                Flickable {
                    anchors { top: hourlyLabel.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom }
                    flickableDirection: Flickable.HorizontalFlick
                    contentWidth: hourlyRepeater.count * 60 - 4
                    clip: true

                    Row {
                        height: parent.height
                        spacing: 4
                        Repeater {
                            id: hourlyRepeater
                            model: ScriptModel { values: dash._hourlyNext24 }
                            delegate: Rectangle {
                                required property var modelData
                                width: 56; height: 80; radius: 8
                                color:        Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.06)
                                border.color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.14)
                                border.width: 1

                                Text {
                                    anchors { top: parent.top; topMargin: 7; horizontalCenter: parent.horizontalCenter }
                                    text: (modelData.time || "").substring(11, 16)
                                    color: dash.dimColor; font.pixelSize: 9; font.family: config.fontFamily
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon || ""
                                    font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 20
                                    color: dash.accentColor
                                }
                                Text {
                                    anchors { bottom: parent.bottom; bottomMargin: 7; horizontalCenter: parent.horizontalCenter }
                                    text: modelData.temp || ""
                                    color: dash.textColor; font.pixelSize: 10; font.family: config.fontFamily
                                }
                            }
                        }
                    }
                }
            }

            // ── 7-day weekly forecast ────────────────────────────────
            Item {
                width: parent.width; height: 130

                Text {
                    id: weeklyLabel
                    text: "This week"
                    color: dash.dimColor; font.pixelSize: 10; font.family: config.fontFamily
                    anchors { top: parent.top; left: parent.left }
                }

                Row {
                    id: weeklyRow
                    anchors { top: weeklyLabel.bottom; topMargin: 4; left: parent.left; right: parent.right }
                    height: 112
                    spacing: 4

                    Repeater {
                        model: ScriptModel { values: AppState.wForecast.slice(0, 7) }
                        delegate: Rectangle {
                            id: dayCard
                            required property var modelData
                            readonly property string _dayName: {
                                var parts = (modelData.date || "").split("-")
                                if (parts.length < 3) return ""
                                var today = new Date()
                                var todayStr = today.getFullYear() + "-" +
                                    String(today.getMonth() + 1).padStart(2, "0") + "-" +
                                    String(today.getDate()).padStart(2, "0")
                                var tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1)
                                var tomorrowStr = tomorrow.getFullYear() + "-" +
                                    String(tomorrow.getMonth() + 1).padStart(2, "0") + "-" +
                                    String(tomorrow.getDate()).padStart(2, "0")
                                if (modelData.date === todayStr) return "Today"
                                if (modelData.date === tomorrowStr) return "Tmrw"
                                var d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]))
                                return ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][d.getDay()] || ""
                            }
                            readonly property string _dayDate: {
                                var parts = (modelData.date || "").split("-")
                                if (parts.length < 3) return ""
                                return parts[2] + "/" + parts[1]
                            }
                            width:  (weeklyRow.width - 6 * weeklyRow.spacing) / 7
                            height: 112; radius: 8
                            color:        Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.06)
                            border.color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.14)
                            border.width: 1

                            // Day name pinned to top
                            Text {
                                id: cardDayName
                                anchors { top: parent.top; topMargin: 7; horizontalCenter: parent.horizontalCenter }
                                text: dayCard._dayName; color: dash.textColor; font.pixelSize: 9; font.bold: true; font.family: config.fontFamily
                            }
                            // Icon + temps centred in card
                            Column {
                                anchors.centerIn: parent; spacing: 2
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon || ""; font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 20; color: dash.accentColor }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.max || ""; color: dash.textColor; font.pixelSize: 10; font.family: config.fontFamily }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.min || ""; color: dash.dimColor; font.pixelSize: 10; font.family: config.fontFamily }
                            }
                            // Date pinned to bottom
                            Text {
                                anchors { bottom: parent.bottom; bottomMargin: 7; horizontalCenter: parent.horizontalCenter }
                                text: dayCard._dayDate; color: dash.dimColor; font.pixelSize: 9; font.family: config.fontFamily
                            }
                        }
                    }
                }
            }

            // ── Sunrise / Sunset / Wind summary ─────────────────────
            Rectangle {
                width: parent.width; height: 62; radius: 10
                color:        Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.06)
                border.color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.12)
                border.width: 1

                Row {
                    anchors.centerIn: parent; spacing: 40

                    Column { spacing: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰖛  " + AppState.wSunrise; color: dash.textColor; font.pixelSize: 12; font.family: config.fontFamily }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Sunrise"; color: dash.dimColor; font.pixelSize: 10; font.family: config.fontFamily }
                    }
                    Column { spacing: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰖜  " + AppState.wSunset; color: dash.textColor; font.pixelSize: 12; font.family: config.fontFamily }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Sunset"; color: dash.dimColor; font.pixelSize: 10; font.family: config.fontFamily }
                    }
                    Column { spacing: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰖝  " + AppState.wWind; color: dash.textColor; font.pixelSize: 12; font.family: config.fontFamily }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Wind"; color: dash.dimColor; font.pixelSize: 10; font.family: config.fontFamily }
                    }
                }
            }
        }
    }
}
