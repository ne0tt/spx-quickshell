import Quickshell
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
    reloadableId: "appLauncher"
    anchors.top:   true
    anchors.left:  true
    anchors.right: true
    implicitHeight: screen ? screen.height : 1080
    exclusiveZone: 0
    color: "transparent"

    // Grab keyboard exclusively while open so typing works immediately.
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
    // ─── Open / close ────────────────────────────────────
    function openLauncher() {
        if (_panel.visible) return;
        _panel.opacity = 0;
        _panel.scale   = 0.97;
        _panel.visible = true;
        _openAnim.start();
        _filter(searchField.text);
        Qt.callLater(() => searchField.forceActiveFocus());
    }

    function closeLauncher() {
        if (!_panel.visible) return;
        _closeAnim.start();
        searchField.text = "";
    }

    // ─── Filtering ───────────────────────────────────────
    function _score(entry, q) {
        var n = entry.name.toLowerCase();
        if (n === q)               return 100;
        if (n.startsWith(q))       return 80;
        if (n.indexOf(q) !== -1)   return 60;
        if (String(entry.genericName).toLowerCase().indexOf(q) !== -1) return 40;
        if (String(entry.keywords).toLowerCase().indexOf(q)    !== -1) return 20;
        return 0;
    }

    function _filter(query) {
        filteredApps.clear();
        if (!query) {
            appList.currentIndex = -1;
            return;
        }
        var q = query.toLowerCase();
        var entries = DesktopEntries.applications.values;
        var scored = [];
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            if (entry.noDisplay) continue;
            var s = _score(entry, q);
            if (s > 0) scored.push({ name: entry.name, desktopId: entry.id, _s: s });
        }
        scored.sort(function(a, b) { return b._s - a._s });
        var limit = Math.min(scored.length, 100);
        for (var j = 0; j < limit; j++)
            filteredApps.append({ name: scored[j].name, desktopId: scored[j].desktopId });
        appList.currentIndex = filteredApps.count > 0 ? 0 : -1;
    }

    function _launch(id) {
        var entry = DesktopEntries.byId(id);
        if (entry) entry.execute();
        closeLauncher();
    }

    // ─── Models ──────────────────────────────────────────
    ListModel { id: filteredApps }

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
            property real _borderAngle: 0
            Timer {
                id: __borderAngleTimer
                running: searchField.activeFocus
                interval: 40    // ~20 fps — throttled to reduce CPU load
                repeat: true
                onTriggered: parent._borderAngle -= Math.PI * 2 / 48
            }

            // Solid background fill
            Rectangle {
                anchors.fill: parent
                radius: 8
                color: colors.col_background
            }

            // Dim static border shown when unfocused
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
                    var bw = 2; var r = 8
                    var x = bw/2; var y = bw/2
                    var w = width - bw; var h = height - bw
                    var cx = width/2; var cy = height/2
                    var grad = ctx.createConicalGradient(cx, cy, angle)
                    var sc = colors.col_source_color
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

            // Search icon
            Text {
                id: _searchIcon
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: ""
                font.family: launcher.fontFamily
                font.pixelSize: 16
                color: searchField.activeFocus
                       ? colors.col_source_color
                       : Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.8)
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            // Placeholder text
            Text {
                anchors { left: _searchIcon.right; leftMargin: 8; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                visible: searchField.text.length === 0
                text: "Search applications…"
                color: Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.2)
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
                text: "No apps matching \"" + searchField.text + "\""
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
