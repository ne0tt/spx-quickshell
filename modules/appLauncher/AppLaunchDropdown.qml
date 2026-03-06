import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import "../../base"

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
    panelZ:       1   // above all other dropdowns and the main bar
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
    // Fixed maximum so the Wayland window never resizes when results appear —
    // the panel expands downward purely via the inner _wrapper animation while
    // the search box stays perfectly still.
    // max panelFullHeight = padTop(8) + searchBox(44) + padBot(8) + divider(8) + maxList(190) + padBot(8) = 266
    // max total           = 266 + ears(16) + footerHeight(28) + pad(8) = 318
    implicitHeight: 320

    // ── App state ────────────────────────────────────────────
    property bool _hasQuery: false   // true when searchField has text

    // Clear search and refocus on every open ─────────────────
    onAboutToOpen: {
        filteredApps.clear()
        _drop._hasQuery = false
        Qt.callLater(() => { searchField.text = ""; searchField.forceActiveFocus() })
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
    function _score(entry, q) {
        var n = entry.name.toLowerCase()
        if (n === q)               return 100
        if (n.startsWith(q))       return 80
        if (n.indexOf(q) !== -1)   return 60
        if (String(entry.genericName).toLowerCase().indexOf(q) !== -1) return 40
        if (String(entry.keywords).toLowerCase().indexOf(q)    !== -1) return 20
        return 0
    }

    function _filter(query) {
        filteredApps.clear()
        _drop._hasQuery = query.length > 0
        if (!query) { appList.currentIndex = -1; return }
        var q = query.toLowerCase()
        var entries = DesktopEntries.applications.values
        var scored = []
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i]
            if (entry.noDisplay) continue
            var s = _drop._score(entry, q)
            if (s > 0) scored.push({ name: entry.name, desktopId: entry.id, _s: s })
        }
        scored.sort(function(a, b) { return b._s - a._s })
        var limit = Math.min(scored.length, 25)
        for (var j = 0; j < limit; j++)
            filteredApps.append({ name: scored[j].name, desktopId: scored[j].desktopId })
        appList.currentIndex = filteredApps.count > 0 ? 0 : -1
    }

    // ── Launching ────────────────────────────────────────────
    function _launch(id) {
        var entry = DesktopEntries.byId(id)
        if (entry) entry.execute()
        _drop.closePanel()
    }

    // ── Models ──────────────────────────────────────────────
    ListModel { id: filteredApps }

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
        text: "No apps matching \"" + searchField.text + "\""
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
