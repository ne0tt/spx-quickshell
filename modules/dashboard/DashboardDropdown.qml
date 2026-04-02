pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../.."
import "../../base"
import "../../state"

// ============================================================
// DASHBOARD DROPDOWN — tabbed info panel with:
//   Tab 0 — Dashboard : weather card + system info + mini media + calendar
//   Tab 1 — Media     : full-size media player
//   Tab 2 — Performance: CPU + RAM usage bars
//   Tab 3 — Weather   : current conditions + 3-day forecast
//   Tab 4 — Network   : active interface, IP, gateway, DNS
// ============================================================
DropdownBase {
    id: dash
    reloadableId: "dashboardDropdown"

    keyboardFocusEnabled: true

    panelWidth: 640

    // Content y-offsets (ears 16 + top-pad 10 + tab-bar 36 + gap 8 = 70)
    readonly property int _tabBarY: 16 + 10          // tab bar top inside _contentArea
    readonly property int _contentY: 16 + 10 + 36 + 8 // tab content top

    // Per-tab panelFullHeight: must accommodate _contentY + content + bottom-pad
    readonly property int _dashH:    _contentY + 155 + 10 + 200 + 4  // info row + cal
    readonly property int _mediaH:   _contentY + 287 + 12  // increased for volume slider at top
    readonly property int _perfH:    _contentY + 194 + 12
    readonly property int _weatherH: _contentY + 455 + 12  // current + hourly + weekly + sunrise
    readonly property int _networkH: _contentY + 280 + 12   // vpn list + map + nm button

    panelFullHeight: {
        switch (dash._tab) {
            case 0: return dash._dashH
            case 1: return dash._mediaH
            case 2: return dash._perfH
            case 3: return dash._weatherH
            case 4: return dash._networkH
            default: return dash._mediaH
        }
    }

    implicitHeight: panelFullHeight + 52

    // ── Hourly: next 12 entries from current hour ──────────────
    readonly property var _hourlyNext12: {
        var now = new Date()
        var nowStr = now.getFullYear() + "-" +
                     String(now.getMonth() + 1).padStart(2, "0") + "-" +
                     String(now.getDate()).padStart(2, "0") + "T" +
                     String(now.getHours()).padStart(2, "0") + ":00"
        var idx = 0
        for (var i = 0; i < WeatherState.wHourly.length; i++) {
            if (WeatherState.wHourly[i].time >= nowStr) { idx = i; break }
        }
        return WeatherState.wHourly.slice(idx, idx + 12)
    }

    // ── State ─────────────────────────────────────────────────
    property int    _tab:         0

    property string _uptime:         "…"
    property string _kernelVersion:  "…"
    property string _hyprlandVersion: "…"
    property int    _updates:     -1  // -1 = loading, 0 = up to date, >0 = count
    property string _mediaTitle:  "No media playing"
    property string _mediaArtist: ""
    property string _mediaArtUrl: ""
    property string _mediaStatus: "Stopped"
    property bool   _mediaAvail:  false
    property real   _mediaPosition: 0     // in seconds
    property real   _mediaDuration: 0     // in seconds

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

    // Network tab state
    property string _netIface:    ""
    property string _netIp:       "—"
    property string _netGateway:  "—"
    property string _netDns:      "—"
    readonly property string _netVlanId: {
        var parts = _netIp.split(".")
        if (parts.length >= 3) {
            var octet = parseInt(parts[2])
            return isNaN(octet) ? "—" : "VLAN" + octet
        }
        return "—"
    }

    // VPN connections (WireGuard)
    property var    _vpnConnections: []
    property var    _vpnActiveSet:   ({})
    property var    _vpnBuf:         []

    // VPN server geo-location (for map pulsing dot)
    property real   _vpnGeoLat:   0.0
    property real   _vpnGeoLon:   0.0
    property bool   _vpnGeoValid: false

    // Network tab keyboard focus (-1 = none, 0..N-1 = VPN cards, N = editor button)
    property int    _netFocusIdx:   -1
    property int    _netKbdFireIdx: -1   // pulses to trigger per-card toggle by index

    // Map colorization is handled by matugen before quickshell reloads
    property int     _mapRefreshCounter: 0  // incremented to force map reload
    readonly property string _mapPath: "file://" + Quickshell.env("HOME") + "/.config/quickshell/assets/map_colorized_latest.png?v=" + _mapRefreshCounter

    // Tab bar width helpers (content width - 4 gaps of 6px)
    readonly property int _cw: panelWidth - 28
    readonly property real _tabW: (_cw - 24) / 5

    // ── Lifecycle ─────────────────────────────────────────────
    onAboutToOpen: {
        _tab      = 0
        _updates  = -1
        _mediaStatus = "Stopped"
        _mediaAvail = false
        _mediaTitle = "No media playing"
        _mediaArtist = ""
        _mediaArtUrl = ""
        _mediaPosition = 0
        _mediaDuration = 0
        var now = new Date()
        inlineCal.displayYear  = now.getFullYear()
        inlineCal.displayMonth = now.getMonth()
        WeatherState.refresh()
        uptimeProc.running       = true
        perfProc.running         = true
        updatesOpenDelay.restart()
        kernelProc.running       = true
        hyprlandVerProc.running  = true
        // Prime the VPN state so tab 4 has data without waiting for the timer
        _vpnBuf = []
        _mapRefreshCounter++  // Force map image reload
        _vpnProc.running = true
        // Control CAVA based on initial state
        Audio.cava.visualizationVisible = false
    }

    onIsOpenChanged: {
        if (!isOpen) Audio.cava.visualizationVisible = false
        else if (_tab === 1 && _mediaAvail) Audio.cava.visualizationVisible = true
    }

    on_TabChanged: {
        if (_tab === 4) {
            _netIfaceProc.running = true
            _vpnBuf = []
            _mapRefreshCounter++  // Force map image reload
            _vpnProc.running = true
        } else if (_tab === 1) {
            mediaProc.running = true
        } else {
            _netFocusIdx = -1
        }
        // Control CAVA visualization
        Audio.cava.visualizationVisible = dash.isOpen && _tab === 1 && _mediaAvail
    }

    // Start update check only after dropdown finishes opening.
    Timer {
        id: updatesOpenDelay
        interval: dash.openDuration + 250
        repeat: false
        onTriggered: {
            if (dash.isOpen) {
                updatesProc.running = true
            }
        }
    }

    Timer {
        interval: 3000
        running:  dash.isOpen
        repeat:   true
        onTriggered: {
            if (dash._tab === 0) uptimeProc.running = true
            if (dash._tab === 1) mediaProc.running  = true
            if (dash._tab === 0 || dash._tab === 2) perfProc.running = true
            if (dash._tab === 4) _netIfaceProc.running = true
            if (dash._tab === 4) { dash._vpnBuf = []; dash._mapRefreshCounter++; _vpnProc.running = true }
        }
    }

    // Progress bar update timer - runs every second for smooth seekbar updates
    Timer {
        interval: 1000
        running:  dash.isOpen && dash._tab === 1 && dash._mediaAvail
        repeat:   true
        onTriggered: {
            mediaProc.running = true
        }
    }

    signal upgradeCompleted()

    // ── Run upgrade in kitty ──────────────────────────────────
    Process {
        id: dashUpgradeProc
        running: false
        command: ["kitty", "--config", Quickshell.env("HOME") + "/dotfiles/.config/kitty/kitty-qs-yay.conf",
                  "--title", "qs-kitty-yay", "sh", "-c",
                  "yay -Syu; echo ''; echo 'Press Enter to close...'; read"]
        onRunningChanged: {
            if (!running) {
                updatesProc.running = true
                dash.upgradeCompleted()
            }
        }
    }

    // ── Kernel version ────────────────────────────────────────
    Process {
        id: kernelProc
        running: false
        command: ["uname", "-r"]
        stdout: SplitParser {
            onRead: data => dash._kernelVersion = data.trim()
        }
    }

    // ── Hyprland version ──────────────────────────────────────
    Process {
        id: hyprlandVerProc
        running: false
        command: ["bash", "-c", "yay -Q hyprland 2>/dev/null | awk '{gsub(/-[0-9]+$/,\"\",$2); print $2}'"]
        stdout: SplitParser {
            onRead: data => {
                var v = data.trim()
                dash._hyprlandVersion = v !== "" ? v : "?"
            }
        }
    }

    // ── Available updates ─────────────────────────────────────
    Process {
        id: updatesProc
        running: false
        command: ["bash", "-c", "repo=$(checkupdates 2>/dev/null | wc -l); aur=0; if command -v yay >/dev/null 2>&1; then aur=$(timeout 15 yay -Qua 2>/dev/null | wc -l); fi; echo $((repo + aur))"]
        stdout: SplitParser {
            onRead: data => {
                var n = parseInt(data.trim())
                dash._updates = isNaN(n) ? 0 : n
            }
        }
    }

    // ── Network info ──────────────────────────────────────────
    Process {
        id: _netIfaceProc
        running: false
        command: ["sh", "-c",
            "nmcli -t -f DEVICE,TYPE,STATE dev | awk -F: '$2==\"vlan\" && $3==\"connected\"{print $1; exit}'"]
        stdout: SplitParser {
            onRead: data => {
                var s = data.trim()
                if (s) dash._netIface = s
            }
        }
        onExited: (code, status) => {
            if (dash._netIface !== "") {
                _netDetailsProc.running = true
            } else {
                dash._netIp      = "\u2014"
                dash._netGateway = "\u2014"
                dash._netDns     = "\u2014"
            }
        }
    }

    Process {
        id: _netDetailsProc
        running: false
        command: ["sh", "-c",
            "nmcli dev show \"" + dash._netIface + "\" | " +
            "awk '/^IP4\\.ADDRESS\\[1\\]/{split($0,a,\": *\"); split(a[2],b,\"/\"); printf \"ip=%s\\n\",b[1]} " +
                  "/^IP4\\.GATEWAY:/{split($0,a,\": *\"); printf \"gw=%s\\n\",a[2]} " +
                  "/^IP4\\.DNS/{split($0,a,\": *\"); dns=(dns?dns\" \":\"\")a[2]} " +
                  "END{printf \"dns=%s\\n\",dns}'"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                var eq = line.indexOf("=")
                if (eq < 0) return
                var key = line.substring(0, eq)
                var val = line.substring(eq + 1).trim()
                if      (key === "ip")  dash._netIp      = val || "\u2014"
                else if (key === "gw")  dash._netGateway = val || "\u2014"
                else if (key === "dns") dash._netDns     = val || "\u2014"
            }
        }
    }

    // ── VPN (WireGuard) connections ───────────────────────────
    Process {
        id: _vpnProc
        running: false
        command: ["sh", "-c",
            "nmcli -t -f NAME,TYPE,ACTIVE con show | " +
            "awk -F: '$2==\"wireguard\"{print $1 \"|\" ($3==\"yes\"?\"active\":\"inactive\")}'"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (!line) return
                var sep = line.lastIndexOf("|")
                if (sep < 0) return
                dash._vpnBuf.push({ name: line.substring(0, sep), active: line.substring(sep + 1) === "active" })
            }
        }
        onExited: {
            var newSet = {}
            dash._vpnBuf.forEach(x => { if (x.active) newSet[x.name] = true })
            var prevKeys = Object.keys(dash._vpnActiveSet).sort().join(",")
            var newKeys  = Object.keys(newSet).sort().join(",")
            dash._vpnConnections = dash._vpnBuf.map(x => x.name).sort((a, b) => a.localeCompare(b))
            dash._vpnActiveSet   = newSet
            dash._vpnBuf         = []
            if (Object.keys(newSet).length > 0) {
                if (!dash._vpnGeoValid || prevKeys !== newKeys)
                    _vpnGeoProc.running = true
            } else {
                dash._vpnGeoValid = false
            }
        }
    }

    // ── VPN server geo-location lookup ────────────────────────
    // When a full-tunnel VPN is active our external IP is the VPN server IP,
    // so ip-api auto-detects it correctly without needing root to read endpoints.
    Process {
        id: _vpnGeoProc
        running: false
        command: ["curl", "-sf", "--max-time", "8",
                  "http://ip-api.com/json?fields=lat,lon,status"]
        stdout: SplitParser {
            onRead: data => {
                var s = data.trim()
                if (!s) return
                try {
                    var obj = JSON.parse(s)
                    if (obj && obj.status === "success") {
                        dash._vpnGeoLat   = parseFloat(obj.lat) || 0.0
                        dash._vpnGeoLon   = parseFloat(obj.lon) || 0.0
                        dash._vpnGeoValid = true
                    }
                } catch (e) {}
            }
        }
        onExited: (code, status) => {
            if (code !== 0) dash._vpnGeoValid = false
        }
    }

    // ── Uptime ────────────────────────────────────────────────
    Process {
        id: uptimeProc
        running: false
        command: ["sh", "-c",
            "awk '{s=int($1);h=int(s/3600);m=int((s%3600)/60);" +
            "if(h>0)printf \"Uptime %dh %dm\",h,m;else printf \"Uptime %dm\",m}'" +
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
            "playerctl -a metadata --format '{{status}}|{{title}}|{{artist}}|{{mpris:artUrl}}|{{position}}|{{mpris:length}}'" +
            " 2>/dev/null | awk -F'|' '$1==\"Playing\"{print;found=1;exit}" +
            " {last=$0} END{if(!found&&NR>0)print last}' || echo 'Stopped|||||'"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split("|")
                if (p.length >= 3) {
                    var status = (p[0] || "Stopped").trim()
                    var title = (p[1] || "").trim()
                    var artist = (p[2] || "").trim()
                    var artUrl = (p.length > 3 ? (p[3] || "") : "").trim()

                    dash._mediaStatus = status
                    dash._mediaAvail = (status === "Playing" || status === "Paused")
                                      && title !== ""
                                      && title !== "No media playing"

                    if (dash._mediaAvail) {
                        dash._mediaTitle = title
                        dash._mediaArtist = artist
                        dash._mediaArtUrl = artUrl

                        // Position and duration are in microseconds, convert to seconds
                        // Validate they're reasonable (max 24 hours = 86400 seconds)
                        var pos = p.length > 4 && p[4] && p[4].trim() !== "" ? parseInt(p[4]) : 0
                        var posSeconds = (!isNaN(pos) && pos >= 0) ? pos / 1000000 : 0
                        dash._mediaPosition = (posSeconds >= 0 && posSeconds < 86400) ? posSeconds : 0

                        var dur = p.length > 5 && p[5] && p[5].trim() !== "" ? parseInt(p[5]) : 0
                        var durSeconds = (!isNaN(dur) && dur >= 0) ? dur / 1000000 : 0
                        dash._mediaDuration = (durSeconds >= 0 && durSeconds < 86400) ? durSeconds : 0
                    } else {
                        dash._mediaTitle = "No media playing"
                        dash._mediaArtist = ""
                        dash._mediaArtUrl = ""
                        dash._mediaPosition = 0
                        dash._mediaDuration = 0
                    }
                    // Control CAVA visualization
                    Audio.cava.visualizationVisible = dash.isOpen && dash._tab === 1 && dash._mediaAvail
                } else {
                    dash._mediaStatus = "Stopped"
                    dash._mediaAvail = false
                    dash._mediaTitle = "No media playing"
                    dash._mediaArtist = ""
                    dash._mediaArtUrl = ""
                    dash._mediaPosition = 0
                    dash._mediaDuration = 0
                    Audio.cava.visualizationVisible = false
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
        Keys.onTabPressed:    { dash._tab = (dash._tab + 1) % 5; dash.triggerHex() }
        Keys.onBacktabPressed: { dash._tab = (dash._tab + 4) % 5; dash.triggerHex() }
        Keys.onEscapePressed: dash.closePanel()

        // ── Network tab (Tab 4) up/down/enter navigation ─────
        Keys.onDownPressed: {
            if (dash._tab !== 4) return
            var total = dash._vpnConnections.length + 1  // cards + editor button
            dash._netFocusIdx = (dash._netFocusIdx + 1 + total) % total
        }
        Keys.onUpPressed: {
            if (dash._tab !== 4) return
            var total = dash._vpnConnections.length + 1
            dash._netFocusIdx = (dash._netFocusIdx - 1 + total) % total
        }
        Keys.onReturnPressed: {
            if (dash._tab !== 4 || dash._netFocusIdx < 0) return
            if (dash._netFocusIdx < dash._vpnConnections.length) {
                dash._netKbdFireIdx = dash._netFocusIdx
            } else {
                _nmConnEditor.running = true
                dash.closePanel()
            }
        }
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
                { icon: "󰖕", label: "Weather"      },
                { icon: "󰈀", label: "Network"      }
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
                    text: WeatherState.wIcon
                    font.family: config.fontFamily
                    font.styleName: "Solid"
                    font.pixelSize: 64
                    color: dash.accentColor
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: WeatherState.wTemp
                    color: dash.textColor
                    font.pixelSize: 22
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: WeatherState.wDesc
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
                width: parent.width * 0.42
                spacing: 7
                Row { spacing: 8
                    Text { text: "󰣇"; font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 14; color: dash.accentColor; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Linux " + dash._kernelVersion; color: dash.textColor; font.pixelSize: 13; font.family: config.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                }
                Row { spacing: 8
                    Text { text: "󱗃"; font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 14; color: dash.accentColor; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Hyprland " + dash._hyprlandVersion; color: dash.textColor; font.pixelSize: 13; font.family: config.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                }
                Row { spacing: 8
                    Text { text: "󰔛"; font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 14; color: dash.accentColor; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: dash._uptime; color: dash.textColor; font.pixelSize: 13; font.family: config.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                }
                Item {
                    width: updatesRow.implicitWidth
                    height: updatesRow.implicitHeight

                    Row {
                        id: updatesRow
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
                            text: dash._updates < 0 ? "Checking for updates…"
                                : dash._updates === 0 ? "System is up to date"
                                : numbersToText.convert(dash._updates) + (dash._updates === 1 ? " update available" : " updates available")
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

                    MouseArea {
                        anchors.fill: parent
                        enabled: dash._updates > 0
                        cursorShape: dash._updates > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            dash.closePanel()
                            dashUpgradeProc.running = true
                        }
                    }
                }
            }

            // Right: CPU / RAM / Disk bars
            Column {
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: 14; topMargin: 14; bottomMargin: 14 }
                width: parent.width * 0.48 - 20
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
                            color: Colors.col_background
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

                SystemClock {
                    id: dashClock
                    precision: SystemClock.Minutes
                }

                // Time display
                Row {
                    id: clockRow
                    anchors { top: parent.top; topMargin: 20; horizontalCenter: parent.horizontalCenter }
                    spacing: 4

                    Text {
                        id: clockTime
                        text: Qt.formatDateTime(dashClock.date, "hh:mm")
                        color: dash.textColor; font.pixelSize: 60; font.bold: true; font.family: config.fontFamily
                    }
                }

                // Long date
                Column {
                    anchors { top: clockRow.bottom; topMargin: 8; horizontalCenter: parent.horizontalCenter }
                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(dashClock.date, "dddd")
                        color: dash.accentColor; font.pixelSize: 22; font.bold: true; font.family: config.fontFamily
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(dashClock.date, "d MMMM yyyy")
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
                                id: todayCircle
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -1
                                width: 20; height: 20; radius: 10
                                color: modelData.isToday ? dash.accentColor : "transparent"
                                visible: !modelData.overflow && modelData.isToday

                                SequentialAnimation {
                                    running: modelData.isToday && dash.isOpen
                                    loops: Animation.Infinite
                                    NumberAnimation { target: todayCircle; property: "opacity"; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                                    NumberAnimation { target: todayCircle; property: "opacity"; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                                }
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
        height:  287
        visible: dash._tab === 1

        property int _mediaDragVol: -1
        readonly property int _mediaDisplayVol: _mediaDragVol >= 0 ? _mediaDragVol : VolumeState.volume

        Rectangle {
            anchors.fill: parent; radius: 10
            color:        Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.06)
            border.color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.15)
            border.width: 1
        }

        // ── Volume slider at top ──────────────────────────────────────
        Item {
            id: mediaVolContainer
            x: 20; y: 15
            width: parent.width - 40; height: 44

            Text {
                id: mediaVolPct
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: (VolumeState.muted ? 0 : mediaVolContainer.parent._mediaDisplayVol) + "%"
                color: dash.accentColor; font.pixelSize: 14; font.family: config.fontFamily
                width: 38; horizontalAlignment: Text.AlignRight
            }

            Item {
                anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: mediaVolPct.left; rightMargin: 8 }
                height: 40

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 6; radius: 3
                    color: Colors.col_background

                    Rectangle {
                        width: parent.width * (VolumeState.muted ? 0 : mediaVolContainer.parent._mediaDisplayVol / 100)
                        height: parent.height; radius: 3
                        color: VolumeState.muted ? dash.dimColor : dash.accentColor
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
                        (VolumeState.muted ? 0 : mediaVolContainer.parent._mediaDisplayVol / 100) * (parent.width - width)
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
                        VolumeState.setVolume(newVol)
                    }

                    onPressed:         mouse => setFromX(mouse.x)
                    onPositionChanged: mouse => { if (pressed) setFromX(mouse.x) }
                    onReleased: mediaVolContainer.parent._mediaDragVol = -1
                }
            }
        }

        // Divider between volume and media
        Rectangle {
            x: 0; y: 67
            width: parent.width
            height: 1
            color: Qt.rgba(dash.dimColor.r, dash.dimColor.g, dash.dimColor.b, 0.2)
        }

        Rectangle {
            id: bigArt
            width: 95; height: 95; radius: 10
            x: 15; y: 76
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
                running: dash._mediaStatus === "Playing" && dash.isOpen && dash._tab === 1
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
                source: dash._mediaAvail ? dash._mediaArtUrl : ""
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
                visible: dash._mediaAvail && (bigArtImage.status !== Image.Ready || dash._mediaArtUrl === "")
                text: "󰎆"; font.family: config.fontFamily; font.styleName: "Solid"
                font.pixelSize: 36; color: dash.accentColor
            }
        }

        Column {
            x: bigArt.x + bigArt.width + 24
            y: 76
            width: parent.width - bigArt.x - bigArt.width - 24 - 28
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
                        running: mediaTitleText.needsScroll && dash.isOpen && dash._tab === 1
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

            // ── Playback controls + Progress bar ──────────────────────
            Row {
                width: parent.width
                height: 40
                topPadding: 4
                spacing: 20

                // Playback controls
                Row {
                    spacing: 16
                    anchors.verticalCenter: parent.verticalCenter
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

                // Progress bar
                Item {
                    width: parent.width - 168  // Parent width minus controls (136) and spacing
                    height: parent.height
                    anchors.verticalCenter: parent.verticalCenter
                    visible: dash._mediaAvail

                    Row {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        spacing: 3

                        Text {
                            id: currentTime
                            width: 56
                            text: {
                                var pos = dash._mediaPosition || 0
                                var sec = Math.floor(pos)
                                var h = Math.floor(sec / 3600)
                                var min = Math.floor((sec % 3600) / 60)
                                var s = sec % 60
                                return String(h).padStart(2, "0") + ":" + String(min).padStart(2, "0") + ":" + String(s).padStart(2, "0")
                            }
                            color: dash.accentColor
                            font.pixelSize: 11
                            font.family: config.fontFamily
                            horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            width: parent.width - 118
                            height: parent.height
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                id: progressBg
                                anchors.centerIn: parent
                                width: parent.width
                                height: 6
                                radius: 3
                                color: Colors.col_background

                                Rectangle {
                                    id: progressFill
                                    height: parent.height
                                    width: dash._mediaDuration > 0 ? (dash._mediaPosition / dash._mediaDuration) * parent.width : 0
                                    radius: parent.radius
                                    color: dash.accentColor

                                    Behavior on width {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                    }
                                }

                                Rectangle {
                                    visible: progressHover.containsMouse
                                    x: progressFill.width - width / 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: dash.accentColor
                                    border.color: Qt.lighter(dash.accentColor, 1.3)
                                    border.width: 2

                                    Behavior on width { NumberAnimation { duration: 100 } }
                                    Behavior on height { NumberAnimation { duration: 100 } }
                                }

                                MouseArea {
                                    id: progressHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (dash._mediaDuration > 0) {
                                            var fraction = mouse.x / width
                                            var seekPos = Math.max(0, Math.min(dash._mediaDuration, fraction * dash._mediaDuration))
                                            ctrlProc.command = ["playerctl", "position", String(seekPos)]
                                            ctrlProc.running = true
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            id: totalTime
                            width: 56
                            text: {
                                var dur = dash._mediaDuration || 0
                                var sec = Math.floor(dur)
                                var h = Math.floor(sec / 3600)
                                var min = Math.floor((sec % 3600) / 60)
                                var s = sec % 60
                                return String(h).padStart(2, "0") + ":" + String(min).padStart(2, "0") + ":" + String(s).padStart(2, "0")
                            }
                            color: dash.dimColor
                            font.pixelSize: 11
                            font.family: config.fontFamily
                            horizontalAlignment: Text.AlignLeft
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        // ── CAVA Visualization ──────────────────────────────────────────
        Item {
            x: 20
            y: 223
            width: parent.width - 40
            height: 54
            visible: dash._mediaAvail

            Row {
                id: cavaBarsRow
                anchors.centerIn: parent
                height: parent.height - 14
                spacing: 3

                property int barCount: 20

                Repeater {
                    model: cavaBarsRow.barCount

                    Rectangle {
                        id: cavaBar
                        required property int index

                        property real value: (dash.isOpen && dash._tab === 1 && dash._mediaAvail) ?
                            Math.max(0, Math.min(1,
                                Audio.cava.values?.[Math.floor((index / (cavaBarsRow.barCount - 1)) * (Audio.cava.values?.length - 1 || 0))] || 0
                            )) : 0

                        width: (parent.parent.width - (cavaBarsRow.spacing * (cavaBarsRow.barCount - 1))) / cavaBarsRow.barCount
                        height: Math.max(2, cavaBar.value * cavaBarsRow.height * 1.8)

                        anchors.bottom: parent.bottom
                        color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.8)

                        Behavior on height {
                            enabled: dash.isOpen && dash._tab === 1 && dash._mediaAvail
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

        Rectangle {
            anchors.fill: parent
            radius: 10
            color:        Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.08)
            border.color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.20)
            border.width: 1
        }

        Column {
            anchors.fill: parent
            anchors.margins: 10
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
                        width: 120; height: 120
                        anchors { top: parent.top; topMargin: 10; horizontalCenter: parent.horizontalCenter }
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = 60, cy = 60, r = 46, lw = 9
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, Math.PI * 2)
                            ctx.strokeStyle = Colors.col_background.toString()
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
                        width: 120; height: 120
                        anchors { top: parent.top; topMargin: 10; horizontalCenter: parent.horizontalCenter }
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = 60, cy = 60, r = 46, lw = 9
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, Math.PI * 2)
                            ctx.strokeStyle = Colors.col_background.toString()
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
                        width: 120; height: 120
                        anchors { top: parent.top; topMargin: 10; horizontalCenter: parent.horizontalCenter }
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = 60, cy = 60, r = 46, lw = 9
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, Math.PI * 2)
                            ctx.strokeStyle = Colors.col_background.toString()
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
            visible: WeatherState.wLoading
            anchors.centerIn: parent
            text: "Fetching weather…"; color: dash.dimColor; font.pixelSize: 13; font.family: config.fontFamily
        }

        Column {
            visible: !WeatherState.wLoading
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
                    anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                    text: WeatherState.wIcon
                    font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 94
                    color: dash.accentColor
                }
                Column {
                    anchors { left: bigWIcon.right; leftMargin: 28; verticalCenter: parent.verticalCenter }
                    spacing: 1
                    Text { text: WeatherState.wTemp;  color: dash.textColor; font.pixelSize: 32; font.bold: true }
                    Text { text: WeatherState.wDesc;  color: dash.dimColor;  font.pixelSize: 22 }
                    Text { text: "Feels like " + WeatherState.wFeels; color: dash.dimColor; font.pixelSize: 18 }
                }
                Column {
                    anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Row { spacing: 6
                        Text { text: "󰖝"; font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 13; color: dash.accentColor }
                        Text { text: WeatherState.wWind; color: dash.dimColor; font.pixelSize: 13 }
                    }
                    Row { spacing: 6
                        Text { text: ""; font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 13; color: dash.accentColor }
                        Text { text: WeatherState.wHumidity; color: dash.dimColor; font.pixelSize: 13 }
                    }
                    Row { spacing: 6
                        Text { text: "󰖛"; font.family: config.fontFamily; font.styleName: "Solid"; font.pixelSize: 13; color: dash.accentColor }
                        Text { text: WeatherState.wSunrise; color: dash.dimColor; font.pixelSize: 13 }
                    }
                }
            }

            // ── Hourly strip (next 24 h) ─────────────────────────────
            Item {
                width: parent.width; height: 106

                Text {
                    id: hourlyLabel
                    text: "Next 12 hours"
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
                            model: ScriptModel { values: dash._hourlyNext12 }
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
                        model: ScriptModel { values: WeatherState.wForecast.slice(0, 7) }
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
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰖛  " + WeatherState.wSunrise; color: dash.textColor; font.pixelSize: 12; font.family: config.fontFamily }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Sunrise"; color: dash.dimColor; font.pixelSize: 10; font.family: config.fontFamily }
                    }
                    Column { spacing: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰖜  " + WeatherState.wSunset; color: dash.textColor; font.pixelSize: 12; font.family: config.fontFamily }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Sunset"; color: dash.dimColor; font.pixelSize: 10; font.family: config.fontFamily }
                    }
                    Column { spacing: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰖝  " + WeatherState.wWind; color: dash.textColor; font.pixelSize: 12; font.family: config.fontFamily }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Wind"; color: dash.dimColor; font.pixelSize: 10; font.family: config.fontFamily }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    // TAB 4: NETWORK
    // ══════════════════════════════════════════════════════════
    Item {
        x:       16 + 14
        y:       dash._contentY
        width:   dash._cw
        height:  280
        visible: dash._tab === 4

        Rectangle {
            id: _netCard
            anchors.fill: parent
            anchors.bottomMargin: _nmEditorBtn.height + 8
            radius: 10
            color:        Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.08)
            border.color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.20)
            border.width: 1
        }

        readonly property real _colGap:  10
        readonly property real _leftW:   Math.round((_netCard.width - _colGap) * 0.45) - 100
        readonly property real _rightW:  _netCard.width - _leftW - _colGap

        // ── Left: VPN connections ─────────────────────────────
        Column {
            id: _vpnCol
            anchors {
                left: _netCard.left
                top: _netCard.top
                bottom: _netCard.bottom
                leftMargin: 12
                topMargin: 12
                bottomMargin: 12
            }
            width: parent._leftW
            spacing: 8

            // Header label
            Text {
                text: "WireGuard"
                font.pixelSize: 10; font.bold: true; font.letterSpacing: 1
                color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.7)
                font.family: config.fontFamily
                leftPadding: 4
            }

            // Connection cards
            Repeater {
                model: dash._vpnConnections

                Item {
                    id: _vpnRow
                    required property string modelData
                    required property int    index

                    width:  _vpnCol.width
                    height: 48

                    property bool _isActive:  dash._vpnActiveSet[modelData] === true
                    property bool _isBusy:    false
                    property bool _wasActive: false
                    readonly property bool _kbdFocused: dash._netFocusIdx === index

                    on_IsActiveChanged: {
                        if (_isActive && !_wasActive) _vpnSelCard.flash()
                        _wasActive = _isActive
                    }

                    // Keyboard-enter trigger: fires toggle when _netKbdFireIdx matches our index
                    Connections {
                        target: dash
                        function on_NetKbdFireIdxChanged() {
                            if (dash._netKbdFireIdx === _vpnRow.index && !_vpnRow._isBusy) {
                                _vpnRow._isBusy = true
                                _cardToggleProc.running = true
                                dash._netKbdFireIdx = -1
                            }
                        }
                    }

                    Process {
                        id: _cardToggleProc
                        running: false
                        command: _vpnRow._isActive
                            ? ["nmcli", "connection", "down", _vpnRow.modelData]
                            : ["nmcli", "connection", "up",   _vpnRow.modelData]
                        onExited: (code, status) => {
                            _vpnRow._isBusy = false
                            dash._vpnBuf    = []
                            _vpnProc.running = true
                        }
                    }

                    SelectableCard {
                        id: _vpnSelCard
                        width:       parent.width
                        isActive:    _vpnRow._isActive
                        isBusy:      _vpnRow._isBusy
                        cardIcon:    "󰦝"
                        label:       _vpnRow.modelData
                        subtitle:    _vpnRow._isBusy
                            ? (_vpnRow._isActive ? "Disconnecting…" : "Connecting…")
                            : (_vpnRow._isActive ? "Connected" : "Disconnected")
                        isPanelOpen: dash.isOpen
                        accentColor: dash.accentColor
                        textColor:   dash.textColor
                        dimColor:    dash.dimColor
                        onClicked: {
                            _vpnRow._isBusy         = true
                            _cardToggleProc.running = true
                        }
                    }

                    // Keyboard focus ring
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: "transparent"
                        border.color: Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, _vpnRow._kbdFocused ? 0.8 : 0)
                        border.width: 2
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                    }
                }
            }

            // Empty state
            Text {
                visible: dash._vpnConnections.length === 0
                text: "No WireGuard\nconnections found"
                color: dash.dimColor; font.pixelSize: 12
                font.family: config.fontFamily
                lineHeight: 1.4
                leftPadding: 4
            }
        }

        // ── Right: map image + VPN server dot ────────────────────
        Item {
            id: _mapContainer
            anchors {
                right: _netCard.right; rightMargin: 12
                top: _netCard.top; topMargin: 12
                bottom: _netCard.bottom; bottomMargin: 12
            }
            width: parent._rightW - 24

            Image {
                id: _mapImage
                anchors.fill: parent
                source: Object.keys(dash._vpnActiveSet).length > 0 ? dash._mapPath : "../../assets/map_colorized_latest_dark.png"
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                opacity: 0.55
            }

            // VPN server location overlay — only visible when geo data is available
            Item {
                id: _vpnOverlay
                anchors.fill: parent
                visible: dash._vpnGeoValid && Object.keys(dash._vpnActiveSet).length > 0

                // Equirectangular projection offsets (image is letterboxed / centered by PreserveAspectFit)
                readonly property real _offX:    (_mapContainer.width  - _mapImage.paintedWidth)  / 2
                readonly property real _offY:    (_mapContainer.height - _mapImage.paintedHeight) / 2
                readonly property real _centerX: _offX + (dash._vpnGeoLon + 180) / 360 * _mapImage.paintedWidth  - 10
                readonly property real _centerY: _offY + (90 - dash._vpnGeoLat) / 180 * _mapImage.paintedHeight + 17

                // Ring 1 — first ripple
                Rectangle {
                    id: _ring1
                    x: _vpnOverlay._centerX - 16; y: _vpnOverlay._centerY - 16
                    width: 28; height: 28; radius: 14
                    transformOrigin: Item.Center
                    color: "transparent"
                    border.color: dash.accentColor
                    border.width: 1.5
                    opacity: 0; scale: 0.4
                    SequentialAnimation {
                        running: _vpnOverlay.visible && dash.isOpen
                        loops: Animation.Infinite
                        ParallelAnimation {
                            NumberAnimation { target: _ring1; property: "opacity"; from: 0.9; to: 0.0; duration: 1400; easing.type: Easing.OutCubic }
                            NumberAnimation { target: _ring1; property: "scale";   from: 0.4; to: 2.8; duration: 1400; easing.type: Easing.OutCubic }
                        }
                        PauseAnimation { duration: 400 }
                    }
                }

                // Ring 2 — second ripple (staggered)
                Rectangle {
                    id: _ring2
                    x: _vpnOverlay._centerX - 16; y: _vpnOverlay._centerY - 16
                    width: 28; height: 28; radius: 14
                    transformOrigin: Item.Center
                    color: "transparent"
                    border.color: dash.accentColor
                    border.width: 1.5
                    opacity: 0; scale: 0.4
                    SequentialAnimation {
                        running: _vpnOverlay.visible && dash.isOpen
                        loops: Animation.Infinite
                        PauseAnimation { duration: 600 }
                        ParallelAnimation {
                            NumberAnimation { target: _ring2; property: "opacity"; from: 0.9; to: 0.0; duration: 1400; easing.type: Easing.OutCubic }
                            NumberAnimation { target: _ring2; property: "scale";   from: 0.4; to: 2.8; duration: 1400; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // Ring 3 — third ripple (most staggered)
                Rectangle {
                    id: _ring3
                    x: _vpnOverlay._centerX - 16; y: _vpnOverlay._centerY - 16
                    width: 28; height: 28; radius: 14
                    transformOrigin: Item.Center
                    color: "transparent"
                    border.color: dash.accentColor
                    border.width: 1.5
                    opacity: 0; scale: 0.4
                    SequentialAnimation {
                        running: _vpnOverlay.visible && dash.isOpen
                        loops: Animation.Infinite
                        PauseAnimation { duration: 1200 }
                        ParallelAnimation {
                            NumberAnimation { target: _ring3; property: "opacity"; from: 0.9; to: 0.0; duration: 1400; easing.type: Easing.OutCubic }
                            NumberAnimation { target: _ring3; property: "scale";   from: 0.4; to: 2.8; duration: 1400; easing.type: Easing.OutCubic }
                        }
                        PauseAnimation { duration: 200 }
                    }
                }

                // Inner dot — scales small→big and fades in/out
                Rectangle {
                    id: _vpnMapDot
                    x: _vpnOverlay._centerX - 6; y: _vpnOverlay._centerY - 6
                    width: 8; height: 8; radius: 6
                    transformOrigin: Item.Center
                    color: "#ffffff"
                    opacity: 0; scale: 0.3
                    SequentialAnimation {
                        running: _vpnOverlay.visible && dash.isOpen
                        loops: Animation.Infinite
                        ParallelAnimation {
                            NumberAnimation { target: _vpnMapDot; property: "opacity"; from: 0.0; to: 1.0; duration: 500; easing.type: Easing.OutCubic }
                            NumberAnimation { target: _vpnMapDot; property: "scale";   from: 0.3; to: 1.0; duration: 500; easing.type: Easing.OutBack }
                        }
                        PauseAnimation { duration: 800 }
                        ParallelAnimation {
                            NumberAnimation { target: _vpnMapDot; property: "opacity"; from: 1.0; to: 0.0; duration: 500; easing.type: Easing.InCubic }
                            NumberAnimation { target: _vpnMapDot; property: "scale";   from: 1.0; to: 0.3; duration: 500; easing.type: Easing.InBack }
                        }
                        PauseAnimation { duration: 100 }
                    }
                }
            }
        }

        // ── nm-connection-editor button (full width, bottom) ───
        Rectangle {
            id: _nmEditorBtn
            anchors {
                left: parent.left
                right: parent.right
                top: _netCard.bottom
                topMargin: 8
            }
            height: 38
            radius: 10
            readonly property bool _kbdFocused: dash._netFocusIdx === dash._vpnConnections.length
            color: _nmBtnArea.containsMouse || _kbdFocused
                ? Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.22)
                : Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.10)
            border.color: _kbdFocused
                ? Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.8)
                : Qt.rgba(dash.accentColor.r, dash.accentColor.g, dash.accentColor.b, 0.35)
            border.width: _kbdFocused ? 2 : 1
            Behavior on color        { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Row {
                anchors.centerIn: parent
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󱘖"; font.family: config.fontFamily; font.pixelSize: 16
                    color: dash.accentColor
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Connection Editor"
                    font.pixelSize: 12; font.bold: true
                    color: dash.textColor; font.family: config.fontFamily
                }
            }

            MouseArea {
                id: _nmBtnArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    _nmConnEditor.running = true
                    dash.closePanel()
                }
            }
        }
    }

    Process {
        id: _nmConnEditor
        running: false
        command: ["nm-connection-editor"]
    }
}
