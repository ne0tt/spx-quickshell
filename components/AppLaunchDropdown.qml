import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls

// ============================================================
// APP LAUNCH DROPDOWN — inline app search panel that drops down
// from the bar like other dropdowns. Designed to sit centred
// under the workspace switcher.
//
// API in shell.qml:
//   AppLaunchDropdown { id: appLaunchDropdown; screen: root.screen }
//
//   // Open (position is set before calling openPanel):
//   appLaunchDropdown.panelX = root.screen.width / 2 - appLaunchDropdown.panelWidth / 2 - 16;
//   appLaunchDropdown.openPanel();
//
//   // Close:
//   appLaunchDropdown.closePanel();
// ============================================================
DropdownBase {
    id: _drop
    reloadableId: "appLaunchDropdown"

    // Keyboard focus while open ─────────────────────────────
    // Exclusive so typing works immediately without clicking the search field first.
    WlrLayershell.keyboardFocus: _drop.isOpen
                                 ? WlrKeyboardFocus.Exclusive
                                 : WlrKeyboardFocus.None

    // ── Geometry ────────────────────────────────────────────
    panelZ:       99999   // above all other dropdowns and the main bar
    panelWidth:   400
    headerHeight: 0    // no shared title row; search box is the top element

    // Dynamic height:
    //   base  = padTop(8) + searchBox(44) + padBot(8) = 60
    //   query + results  → add divider gap(8) + rows(≤190) + bot(8)
    //   query + no match → add divider gap(8) + empty label(36) + bot(8)
    readonly property int _padTop:  8
    readonly property int _padBot:  8
    readonly property int _rowH:    38
    readonly property int _maxList: 190   // px cap on the result list

    panelFullHeight: {
        var base = _drop._padTop + 44 + _drop._padBot
        if (_drop._hasQuery) {
            if (filteredApps.count > 0)
                return base + 8 + Math.min(filteredApps.count * _drop._rowH, _drop._maxList) + _drop._padBot
            else
                return base + 8 + 36 + _drop._padBot
        }
        return base
    }
    implicitHeight: panelFullHeight + 16 + footerHeight + 8

    // ── App state ────────────────────────────────────────────
    property var  _appData:  []
    property bool _hasQuery: false   // true when searchField has text

    // Clear search and refocus on every open ─────────────────
    onAboutToOpen: {
        filteredApps.clear()
        _drop._hasQuery = false
        Qt.callLater(() => { searchField.text = ""; searchField.forceActiveFocus() })
        if (_drop._appData.length === 0 && !appListProc.running)
            appListProc.running = true
    }

    // Clear on close ─────────────────────────────────────────
    Connections {
        target: _drop
        function onIsOpenChanged() {
            if (!_drop.isOpen) {
                searchField.text = ""
                filteredApps.clear()
                _drop._hasQuery = false
            }
        }
    }

    // ── Filtering ────────────────────────────────────────────
    function _filter(query) {
        filteredApps.clear()
        _drop._hasQuery = query.length > 0
        if (!query) { appList.currentIndex = -1; return }
        var q = query.toLowerCase()
        for (var i = 0; i < _drop._appData.length; i++) {
            var app = _drop._appData[i]
            if (app.name.toLowerCase().indexOf(q) !== -1)
                filteredApps.append(app)
            if (filteredApps.count >= 25) break
        }
        appList.currentIndex = filteredApps.count > 0 ? 0 : -1
    }

    // ── Launching ────────────────────────────────────────────
    function _launch(execStr) {
        var pyScript =
            "import subprocess,re,shlex,sys\n" +
            "e=sys.argv[1]\n" +
            "e=re.sub(r'%[fFuUdDnNickvmpe]','',e).strip()\n" +
            "subprocess.Popen(shlex.split(e),\n" +
            "    start_new_session=True,\n" +
            "    close_fds=True,\n" +
            "    stdin=subprocess.DEVNULL,\n" +
            "    stdout=subprocess.DEVNULL,\n" +
            "    stderr=subprocess.DEVNULL)\n"
        launchProc.command = ["python3", "-c", pyScript, execStr]
        launchProc.running = true
        _drop.closePanel()
    }

    // ── Models ──────────────────────────────────────────────
    ListModel { id: filteredApps }

    // ── Process: enumerate .desktop files ────────────────────
    // Identical parser to AppLauncher — user entries shadow system ones.
    Process {
        id: appListProc
        running: false
        command: [
            "python3", "-c",
            "import os,glob\n" +
            "p2=glob.glob(os.path.expanduser('~/.local/share/applications/*.desktop'))\n" +
            "p1=glob.glob('/usr/share/applications/*.desktop')\n" +
            "out=[]\n" +
            "seen=set()\n" +
            "for f in p2+p1:\n" +
            "    n=nd=t=e=''\n" +
            "    s=False\n" +
            "    base=os.path.basename(f)\n" +
            "    try:\n" +
            "        for l in open(f,errors='ignore'):\n" +
            "            l=l.rstrip()\n" +
            "            if l=='[Desktop Entry]':s=True;continue\n" +
            "            if l.startswith('[') and s:break\n" +
            "            if not s:continue\n" +
            "            k,_,v=l.partition('=')\n" +
            "            if k=='Name' and not n:n=v\n" +
            "            if k=='Exec' and not e:e=v\n" +
            "            if k=='NoDisplay':nd=v.lower()\n" +
            "            if k=='Hidden':nd=v.lower()\n" +
            "            if k=='Type':t=v\n" +
            "        if n and e and nd!='true' and t=='Application' and base not in seen:\n" +
            "            seen.add(base)\n" +
            "            out.append(n+'\\t'+f+'\\t'+e)\n" +
            "    except:pass\n" +
            "out.sort(key=lambda x:x.lower())\n" +
            "print('\\n'.join(out))\n"
        ]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.split("\t")
                if (parts.length < 3) return
                _drop._appData.push({ name: parts[0], path: parts[1], desktopId: parts[2] })
            }
        }
        onRunningChanged: {
            if (!running && _drop._appData.length > 0)
                _drop._filter(searchField.text)
        }
    }

    // ── Process: launch ──────────────────────────────────────
    Process {
        id: launchProc
        command: []
        onRunningChanged: if (!running) command = []
    }

    // ═══════════════════════════════════════════════════════
    // CONTENT — search box + result list
    // y origin inside _contentArea = 16 (ears) + headerHeight(0) + _padTop
    // ═══════════════════════════════════════════════════════

    // ── Search box ───────────────────────────────────────────
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16 + _drop._padTop
        width:  370
        height: 40

        // ── Rotating gradient border (Hyprland-style) ──────────────
        // A conical gradient sweeps clockwise using col_source_color
        // and #C47FD5, drawn onto a Canvas each animation tick.
        property real _borderAngle: 0
        Timer {
            id: __borderAngleTimer
            running: searchField.activeFocus
            interval: 40    // ~20 fps — throttled to reduce CPU load
            repeat: true
            onTriggered: parent._borderAngle -= Math.PI * 2 / 48
        }

        // Dim static border shown when unfocused
        Rectangle {
            anchors.fill: parent
            radius: 8
            color: colors.col_background
        }

        // Unfocused border overlay
        Rectangle {
            anchors.fill: parent
            radius: 8
            color: "transparent"
            border.color: Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.25)
            border.width: 1
            visible: !searchField.activeFocus
        }

        // Rotating gradient border overlay — fades in on focus
        Canvas {
            id: _searchBorderCanvas
            anchors.fill: parent
            opacity: searchField.activeFocus ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            property real angle: parent._borderAngle
            onAngleChanged: { if (opacity > 0) requestPaint() }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var bw = 2
                var r  = 8
                var x  = bw / 2; var y = bw / 2
                var w  = width - bw; var h = height - bw
                var cx = width / 2;  var cy = height / 2

                // Conical gradient sweeping clockwise from current angle
                var grad = ctx.createConicalGradient(cx, cy, angle)
                var sc = colors.col_source_color
                var c1 = Qt.rgba(sc.r, sc.g, sc.b, 1.0).toString()
                grad.addColorStop(0,    c1)        // source_color half
                grad.addColorStop(0.5,  "#C47FD5") // purple half — chasing
                grad.addColorStop(1.0,  c1)        // wraps back seamlessly

                ctx.strokeStyle = grad
                ctx.lineWidth   = bw

                // Rounded-rect path (manual arcTo for compatibility)
                ctx.beginPath()
                ctx.moveTo(x + r, y)
                ctx.lineTo(x + w - r, y)
                ctx.arcTo(x + w, y,     x + w, y + r,     r)
                ctx.lineTo(x + w, y + h - r)
                ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
                ctx.lineTo(x + r, y + h)
                ctx.arcTo(x, y + h,     x, y + h - r,     r)
                ctx.lineTo(x, y + r)
                ctx.arcTo(x, y,         x + r, y,         r)
                ctx.closePath()
                ctx.stroke()
            }
        }

        // Search icon — tracks gradient lead color via angle
        Text {
            id: _searchIcon
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: ""
            font.family: _drop.fontFamily
            font.pixelSize: 16
            color: searchField.activeFocus
                   ? colors.col_source_color
                   : Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.8)
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // Placeholder
        Text {
            anchors { left: _searchIcon.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            visible: searchField.text.length === 0
            text: "Search applications…"
            color: Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.25)
            font.pixelSize: 14
            font.family: _drop.fontFamily
        }

        // Text input
        TextInput {
            id: searchField
            anchors { left: _searchIcon.right; leftMargin: 8; right: _countPill.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            color: colors.col_source_color
            font.pixelSize: 14
            font.family: _drop.fontFamily
            selectionColor: Qt.rgba(colors.col_source_color.r, colors.col_source_color.g, colors.col_source_color.b, 0.3)
            clip: true

            onTextChanged: _drop._filter(text)

            Keys.onEscapePressed: _drop.closePanel()
            Keys.onReturnPressed: {
                if (appList.currentIndex >= 0 && filteredApps.count > 0)
                    _drop._launch(filteredApps.get(appList.currentIndex).desktopId)
            }
            Keys.onUpPressed: {
                if (appList.currentIndex > 0) appList.currentIndex--
            }
            Keys.onDownPressed: {
                if (appList.currentIndex < filteredApps.count - 1) appList.currentIndex++
            }
            Keys.onTabPressed: {
                if (appList.currentIndex < filteredApps.count - 1) appList.currentIndex++
            }
        }

        // Result count pill
        Rectangle {
            id: _countPill
            visible: filteredApps.count > 0
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            width:  _countText.implicitWidth + 14
            height: 20; radius: 10
            color: Qt.rgba(colors.col_source_color.r, colors.col_source_color.g, colors.col_source_color.b, 0.12)

            Text {
                id: _countText
                anchors.centerIn: parent
                text: filteredApps.count
                color: Qt.rgba(colors.col_source_color.r, colors.col_source_color.g, colors.col_source_color.b, 0.7)
                font.pixelSize: 11
                font.family: _drop.fontFamily
                font.weight: Font.Bold
            }
        }
    }

    // ── Divider ──────────────────────────────────────────────
    Rectangle {
        x: 16 + 10
        y: 16 + _drop._padTop + 44 + 8
        width:   _drop.panelWidth - 20
        height:  1
        visible: _drop._hasQuery
        color:   Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.12)
    }

    // ── Empty state label ────────────────────────────────────
    Text {
        x: 16
        y: 16 + _drop._padTop + 44 + 8 + 8
        width:   _drop.panelWidth
        visible: _drop._hasQuery && filteredApps.count === 0
        text: appListProc.running ? "Loading…" : "No apps matching \"" + searchField.text + "\""
        horizontalAlignment: Text.AlignHCenter
        color: Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.35)
        font.pixelSize: 13
        font.family: _drop.fontFamily
    }

    // ── Result list ──────────────────────────────────────────
    ListView {
        id: appList
        x: 16 + 10
        y: 16 + _drop._padTop + 44 + 8 + 1 + 8   // below divider
        width:  _drop.panelWidth - 20
        height: Math.min(filteredApps.count * _drop._rowH, _drop._maxList)
        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        visible: filteredApps.count > 0
        clip:    true
        model:   filteredApps
        currentIndex: 0
        keyNavigationEnabled: false

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 4; radius: 2
                color: Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.35)
            }
            background: Rectangle { color: "transparent" }
        }

        delegate: Rectangle {
            id: _row
            required property string name
            required property string desktopId
            required property int    index

            width:  appList.width - 4
            height: _drop._rowH
            radius: 6
            color: appList.currentIndex === index
                   ? Qt.rgba(colors.col_source_color.r, colors.col_source_color.g, colors.col_source_color.b, 0.13)
                   : (rHover.containsMouse
                      ? Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.07)
                      : "transparent")
            Behavior on color { ColorAnimation { duration: 80 } }

            // Active left-edge accent bar
            Rectangle {
                visible: appList.currentIndex === _row.index
                anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                width: 3; height: 18; radius: 2
                color: colors.col_source_color
            }

            Text {
                anchors { left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text:  _row.name
                elide: Text.ElideRight
                color: appList.currentIndex === _row.index ? colors.col_source_color : colors.col_primary
                font.pixelSize: 14
                font.family:    _drop.fontFamily
                Behavior on color { ColorAnimation { duration: 80 } }
            }

            MouseArea {
                id: rHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onEntered:    appList.currentIndex = _row.index
                onClicked:    _drop._launch(_row.desktopId)
            }
        }
    }
}
