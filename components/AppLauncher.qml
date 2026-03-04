import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Controls

// ============================================================
// APP LAUNCHER — rofi-style centred launcher panel.
//
// Usage in shell.qml:
//   AppLauncher { id: appLauncher; screen: root.screen }
//
// API:
//   appLauncher.openLauncher()
//   appLauncher.closeLauncher()
//   appLauncher.isOpen  (read-only bool)
// ============================================================
PanelWindow {
    id: launcher

    // ─── Screen / window geometry ────────────────────────
    anchors.top:   true
    anchors.left:  true
    anchors.right: true
    implicitHeight: screen ? screen.height : 1080
    exclusiveZone: 0
    color: "transparent"

    // Grab keyboard exclusively while open, release when closed.
    // WlrLayershell.keyboardFocus is set via the attached object for Exclusive mode.
    WlrLayershell.keyboardFocus: _panel.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // When open: mask fills the whole window so click-outside is catchable.
    // When closed: 0×0 so the window eats no input at all.
    mask: Region { item: _maskProxy }

    Item {
        id: _maskProxy
        x: 0; y: 0
        width:  _panel.visible ? launcher.width  : 0
        height: _panel.visible ? launcher.height : 0
    }

    // ─── Public API ──────────────────────────────────────
    property bool isOpen: _panel.visible

    // Bar font used elsewhere in the shell
    property string fontFamily: config.fontFamily

    // ─── Internal state ───────────────────────────────────
    property var _appData: []   // backing array [{name, path, exec}]

    // ─── Open / close ────────────────────────────────────
    function openLauncher() {
        if (_panel.visible) return;
        _panel.opacity = 0;
        _panel.scale   = 0.97;
        _panel.visible = true;
        _openAnim.start();
        _maybeRefreshApps();
        Qt.callLater(() => searchField.forceActiveFocus());
    }

    function closeLauncher() {
        if (!_panel.visible) return;
        _closeAnim.start();
        searchField.text = "";
    }

    // ─── App fetching & filtering ────────────────────────
    function _maybeRefreshApps() {
        if (launcher._appData.length === 0 && !appListProc.running)
            appListProc.running = true;
        else
            _filter(searchField.text);
    }

    function _filter(query) {
        filteredApps.clear();
        if (!query) {
            appList.currentIndex = -1;
            return;
        }
        var q = query.toLowerCase();
        for (var i = 0; i < launcher._appData.length; i++) {
            var app = launcher._appData[i];
            if (app.name.toLowerCase().indexOf(q) !== -1)
                filteredApps.append(app);
            if (filteredApps.count >= 100) break;
        }
        appList.currentIndex = filteredApps.count > 0 ? 0 : -1;
    }

    function _launch(execStr) {
        // Use Python Popen with start_new_session=True: the app gets its own
        // process session, fully detached from quickshell, exactly how rofi
        // and other launchers hand off apps to the OS.
        var pyScript =
            "import subprocess,re,shlex,sys\n" +
            "e=sys.argv[1]\n" +
            "# Strip desktop field codes (%f %F %u %U etc.)\n" +
            "e=re.sub(r'%[fFuUdDnNickvmpe]','',e).strip()\n" +
            "subprocess.Popen(shlex.split(e),\n" +
            "    start_new_session=True,\n" +
            "    close_fds=True,\n" +
            "    stdin=subprocess.DEVNULL,\n" +
            "    stdout=subprocess.DEVNULL,\n" +
            "    stderr=subprocess.DEVNULL)\n";
        launchProc.command = ["python3", "-c", pyScript, execStr];
        launchProc.running = true;
        closeLauncher();
    }

    // ─── Models ──────────────────────────────────────────
    ListModel { id: filteredApps }

    // ─── Process: enumerate .desktop files ───────────────
    Process {
        id: appListProc
        running: false
        command: [
            "python3", "-c",
            "import os,glob\n" +
            "# User entries first so they shadow system ones\n" +
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
                var parts = data.split("\t");
                if (parts.length < 3) return;
                launcher._appData.push({
                    name:      parts[0],
                    path:      parts[1],
                    desktopId: parts[2]   // Exec= value
                });
            }
        }

        onRunningChanged: {
            if (!running && launcher._appData.length > 0)
                launcher._filter(searchField.text);
        }
    }

    // ─── Process: launch the selected app ────────────────
    Process {
        id: launchProc
        command: []
        // Re-arm after each run so subsequent launches work
        onRunningChanged: if (!running) command = []
    }

    // ─── Animations ──────────────────────────────────────
    ParallelAnimation {
        id: _openAnim
        NumberAnimation { target: _panel; property: "opacity"; from: 0;    to: 1;    duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: _panel; property: "scale";   from: 0.97; to: 1.0;  duration: 200; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: _closeAnim
        NumberAnimation { target: _panel; property: "opacity"; from: 1;   to: 0;    duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: _panel; property: "scale";   from: 1.0; to: 0.97; duration: 140; easing.type: Easing.InCubic }
        onFinished: _panel.visible = false
    }

    // ─── Click-outside to close ──────────────────────────
    MouseArea {
        anchors.fill: parent
        z: 99996
        visible: _panel.visible
        propagateComposedEvents: true
        onClicked: mouse => {
            mouse.accepted = false;   // always pass through to apps below
            var local = mapToItem(_panel, mouse.x, mouse.y);
            if (local.x < 0 || local.y < 0 ||
                local.x > _panel.width || local.y > _panel.height)
                launcher.closeLauncher();
        }
    }

    // ─── Main panel rect ─────────────────────────────────
    Rectangle {
        id: _panel
        visible: false
        z: 99997
        transformOrigin: Item.Center

        width:  400
        // 76px = search box only; expands as results arrive
        height: searchField.text.length === 0
                ? 76
                : (filteredApps.count > 0
                   ? (105 + Math.min(filteredApps.count * 38, 200))
                   : 120)   // room for "no results" message
        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        x: Math.round((parent.width  - width)  / 2)
        y: Math.round((parent.height - height) / 2)

        radius: 14
        color:  colors.col_main
        border.color: Qt.rgba(0, 0, 0, 0.7)
        border.width: 1

        // Drop shadow
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled:          true
            shadowColor:            "#CC000000"
            shadowBlur:             1.0
            shadowHorizontalOffset: 0
            shadowVerticalOffset:   6
        }

        // ── Header row ──────────────────────────────────────
        Item {
            id: _header
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
            height: 44

            // Search input background (declared first → drawn beneath text)
            Rectangle {
                anchors.fill: parent
                radius: 8
                color: Qt.rgba(colors.col_background.r, colors.col_background.g, colors.col_background.b, 1.0)
                border.color: searchField.activeFocus
                              ? colors.col_source_color
                              : Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.25)
                border.width: 1.5
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }

            // Search icon
            Text {
                id: _searchIcon
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: "\uf002"
                font.family: launcher.fontFamily
                font.pixelSize: 16
                color: searchField.activeFocus
                       ? colors.col_source_color
                       : Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.5)
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // Placeholder text
            Text {
                anchors { left: _searchIcon.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                visible: searchField.text.length === 0
                text: "Search applications…"
                color: Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.3)
                font.pixelSize: 15
                font.family: launcher.fontFamily
            }

            // Actual text input
            TextInput {
                id: searchField
                anchors {
                    left: _searchIcon.right; leftMargin: 8
                    right: parent.right;     rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                color: colors.col_source_color
                font.pixelSize: 15
                font.family: launcher.fontFamily
                selectionColor: Qt.rgba(colors.col_source_color.r, colors.col_source_color.g, colors.col_source_color.b, 0.3)
                clip: true

                onTextChanged: launcher._filter(text)

                Keys.onEscapePressed: launcher.closeLauncher()

                Keys.onReturnPressed: {
                    if (appList.currentIndex >= 0 && filteredApps.count > 0)
                        launcher._launch(filteredApps.get(appList.currentIndex).desktopId);
                }

                Keys.onUpPressed: {
                    if (appList.currentIndex > 0)
                        appList.currentIndex--;
                }

                Keys.onDownPressed: {
                    if (appList.currentIndex < filteredApps.count - 1)
                        appList.currentIndex++;
                }

                Keys.onTabPressed: {
                    if (appList.currentIndex < filteredApps.count - 1)
                        appList.currentIndex++;
                }
            }

            // Result count pill (top-right of header)
            Rectangle {
                visible: filteredApps.count > 0
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: _countText.implicitWidth + 14
                height: 20
                radius: 10
                color: Qt.rgba(colors.col_source_color.r, colors.col_source_color.g, colors.col_source_color.b, 0.12)

                Text {
                    id: _countText
                    anchors.centerIn: parent
                    text: filteredApps.count
                    color: Qt.rgba(colors.col_source_color.r, colors.col_source_color.g, colors.col_source_color.b, 0.7)
                    font.pixelSize: 11
                    font.family: launcher.fontFamily
                    font.weight: Font.Bold
                }
            }
        }

        // Divider
        Rectangle {
            id: _divider
            visible: filteredApps.count > 0
            anchors { top: _header.bottom; topMargin: 8; left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16 }
            height: 1
            color: Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.12)
        }

        // ── Empty state ──────────────────────────────────────
        Item {
            anchors { top: _divider.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }
            visible: searchField.text.length > 0 && filteredApps.count === 0

            Text {
                anchors.centerIn: parent
                text: searchField.text.length > 0
                      ? "No apps matching  \"" + searchField.text + "\""
                      : (appListProc.running ? "Loading…" : "No apps found")
                color: Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.35)
                font.pixelSize: 14
                font.family: launcher.fontFamily
            }
        }

        // ── App list ─────────────────────────────────────────
        ListView {
            id: appList
            anchors {
                top:    _divider.bottom;  topMargin:    8
                left:   parent.left;      leftMargin:   12
                right:  parent.right;     rightMargin:  12
                bottom: parent.bottom;    bottomMargin: 12
            }
            clip: true
            model: filteredApps
            currentIndex: 0
            keyNavigationEnabled: false   // handled by TextInput Keys above

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
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
                height: 38
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
                    width:  3
                    height: 18
                    radius: 2
                    color:  colors.col_source_color

                    Behavior on opacity { NumberAnimation { duration: 80 } }
                }

                // App name
                Text {
                    anchors {
                        left:           parent.left; leftMargin: 16
                        right:          parent.right; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text:  _row.name
                    elide: Text.ElideRight
                    color: appList.currentIndex === _row.index
                           ? colors.col_source_color
                           : colors.col_primary
                    font.pixelSize: 14
                    font.family:    launcher.fontFamily

                    Behavior on color { ColorAnimation { duration: 80 } }
                }

                MouseArea {
                    id: rHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onEntered:    appList.currentIndex = _row.index
                    onClicked:    launcher._launch(_row.desktopId)
                }
            }
        }
    }
}
