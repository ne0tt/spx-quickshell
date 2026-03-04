// components/NetworkAdminDropdown.qml
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls

// ============================================================
// NETWORK ADMIN DROPDOWN
// Manages NetworkManager connections from within the shell:
//   • connections view  — list all connections, toggle active,
//                         delete, open edit
//   • edit view         — switch DHCP ↔ static, set IP/GW/DNS,
//                         save & re-apply
//   • wifi view         — scan networks, connect (open or WPA),
//                         disconnect
// ============================================================
DropdownBase {
    id: netAdmin
    reloadableId: "networkAdminDropdown"

    panelWidth:      320
    panelTitle:      "Network Manager"
    panelIcon:       "󰛳"
    headerHeight:    34
    footerHeight:    32

    // Dynamic height per view
    panelFullHeight: {
        if (currentView === "edit")
            return editIpMethod === "manual" ? 390 : 160
        if (currentView === "wifi")
            return Math.min(370, Math.max(88,
                        44 + (wifiConnectSsid !== "" ? 116 : 0)
                           + wifiNetworks.length * 46))
        // connections (default)
        return Math.min(350, Math.max(68, 52 + connectionList.length * 50))
    }
    implicitHeight: 500

    // ── View state ───────────────────────────────────────────
    property string currentView:       "connections"  // connections | edit | wifi
    property var    selectedConn:      null

    // ── Connection list data ─────────────────────────────────
    property var connectionList: []
    property var _connBuf:       []

    // ── WiFi scan data ───────────────────────────────────────
    property var    wifiNetworks:    []
    property var    _wifiBuf:        []
    property string wifiConnectSsid: ""   // non-empty → show password prompt
    property bool   wifiScanning:    false

    // ── Edit-view state (set by process, read on save) ───────
    property string editIpMethod:  "auto"
    property bool   editBusy:      false

    // ── Helpers ──────────────────────────────────────────────
    function typeIcon(t) {
        if (t.indexOf("wireless") >= 0) return "󰤨"
        if (t.indexOf("ethernet") >= 0) return "󰈀"
        if (t.indexOf("vlan")     >= 0) return "󰲝"
        if (t.indexOf("vpn")      >= 0) return "󰖂"
        if (t.indexOf("bridge")   >= 0) return "󰲡"
        if (t.indexOf("loopback") >= 0) return "󰓫"
        return "󰛳"
    }

    // Accent-tinted rect helper — expressed as an inline component below

    // ── Lifecycle ────────────────────────────────────────────
    Component.onCompleted: {
        _connBuf = []
        conListProc.running = true
    }

    onAboutToOpen: {
        currentView = "connections"
        _connBuf = []
        conListProc.running = true
    }

    // ── Public actions ───────────────────────────────────────
    function refresh() {
        _connBuf = []
        conListProc.running = true
    }

    function activateConn(uuid) {
        activateProc.command = ["nmcli", "con", "up", uuid]
        activateProc.running = true
    }

    function deactivateConn(uuid) {
        deactivateProc.command = ["nmcli", "con", "down", uuid]
        deactivateProc.running = true
    }

    function deleteConn(uuid) {
        deleteProc.command = ["nmcli", "con", "delete", uuid]
        deleteProc.running = true
    }

    function openEdit(conn) {
        selectedConn    = conn
        editIpMethod    = "auto"
        editBusy        = true
        ipAddrFld.text  = ""
        prefixFld.text  = "24"
        gatewayFld.text = ""
        dnsFld.text     = ""
        currentView     = "edit"
        editProc.command = [
            "nmcli", "-t", "-f",
            "ipv4.method,ipv4.addresses,IP4.ADDRESS[1],ipv4.gateway,ipv4.dns",
            "con", "show", conn.uuid
        ]
        editProc.running = true
    }

    function saveEdit() {
        editBusy = true
        var uuid = selectedConn.uuid
        var args
        if (editIpMethod === "auto") {
            args = ["nmcli", "con", "mod", uuid,
                    "ipv4.method",    "auto",
                    "ipv4.addresses", "",
                    "ipv4.gateway",   "",
                    "ipv4.dns",       ""]
        } else {
            var cidr = ipAddrFld.text + "/" + prefixFld.text
            args = ["nmcli", "con", "mod", uuid,
                    "ipv4.method",    "manual",
                    "ipv4.addresses", cidr,
                    "ipv4.gateway",   gatewayFld.text,
                    "ipv4.dns",       dnsFld.text]
        }
        saveProc.command = args
        saveProc.running = true
    }

    function openWifi() {
        wifiNetworks    = []
        _wifiBuf        = []
        wifiConnectSsid = ""
        wifiScanning    = true
        currentView     = "wifi"
        wifiScanProc.running = true
    }

    // ── Processes ────────────────────────────────────────────

    // List all connections
    Process {
        id: conListProc
        running: false
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE,ACTIVE", "con", "show"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (!line) return
                // Split from the end — NAME may contain ":"
                var p    = line.split(":")
                if (p.length < 5) return
                var active = p[p.length - 1]
                var device = p[p.length - 2]
                var type   = p[p.length - 3]
                var uuid   = p[p.length - 4]
                var name   = p.slice(0, p.length - 4).join(":")
                netAdmin._connBuf.push({ name, uuid, type, device, active: active === "yes" })
            }
        }
        onExited: netAdmin.connectionList = netAdmin._connBuf.slice()
    }

    // Activate a connection
    Process {
        id: activateProc
        running: false
        command: []
        onRunningChanged: if (!running) { command = []; Qt.callLater(netAdmin.refresh) }
    }

    // Deactivate a connection
    Process {
        id: deactivateProc
        running: false
        command: []
        onRunningChanged: if (!running) { command = []; Qt.callLater(netAdmin.refresh) }
    }

    // Delete a connection
    Process {
        id: deleteProc
        running: false
        command: []
        onRunningChanged: if (!running) { command = []; Qt.callLater(netAdmin.refresh) }
    }

    // Load connection details for editing
    Process {
        id: editProc
        running: false
        command: []
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                var col  = line.indexOf(":")
                if (col < 0) return
                var k = line.substring(0, col).trim()
                var v = line.substring(col + 1).trim()

                if (k === "ipv4.method") {
                    netAdmin.editIpMethod = (v === "manual") ? "manual" : "auto"
                } else if (k === "ipv4.addresses" && v) {
                    var sl = v.indexOf("/")
                    ipAddrFld.text  = sl >= 0 ? v.substring(0, sl) : v
                    prefixFld.text  = sl >= 0 ? v.substring(sl + 1) : "24"
                } else if (k === "IP4.ADDRESS[1]" && v && !ipAddrFld.text) {
                    var sl2 = v.indexOf("/")
                    ipAddrFld.text  = sl2 >= 0 ? v.substring(0, sl2) : v
                    prefixFld.text  = sl2 >= 0 ? v.substring(sl2 + 1) : "24"
                } else if (k === "ipv4.gateway") {
                    gatewayFld.text = v
                } else if (k === "ipv4.dns") {
                    dnsFld.text = v
                }
            }
        }
        onExited: netAdmin.editBusy = false
    }

    // Save edits
    Process {
        id: saveProc
        running: false
        command: []
        onRunningChanged: {
            if (!running) {
                command = []
                if (netAdmin.selectedConn && netAdmin.selectedConn.active) {
                    reUpProc.command = ["nmcli", "con", "up", netAdmin.selectedConn.uuid]
                    reUpProc.running = true
                } else {
                    netAdmin.editBusy    = false
                    netAdmin.currentView = "connections"
                    Qt.callLater(netAdmin.refresh)
                }
            }
        }
    }

    // Re-apply connection after save
    Process {
        id: reUpProc
        running: false
        command: []
        onRunningChanged: {
            if (!running) {
                command = []
                netAdmin.editBusy    = false
                netAdmin.currentView = "connections"
                Qt.callLater(netAdmin.refresh)
            }
        }
    }

    // WiFi scan
    Process {
        id: wifiScanProc
        running: false
        command: ["nmcli", "--rescan", "yes", "-t",
                  "-f", "SSID,SIGNAL,SECURITY,IN-USE", "dev", "wifi", "list"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (!line) return
                // IN-USE is "*" or " " — stored at end
                var p = line.split(":")
                if (p.length < 4) return
                var inUse    = p[p.length - 1].trim()
                var security = p[p.length - 2].trim()
                var signal   = parseInt(p[p.length - 3]) || 0
                var ssid     = p.slice(0, p.length - 3).join(":")
                if (!ssid) return
                // deduplicate SSIDs — keep strongest signal
                var existing = netAdmin._wifiBuf.findIndex(n => n.ssid === ssid)
                if (existing >= 0) {
                    if (signal > netAdmin._wifiBuf[existing].signal)
                        netAdmin._wifiBuf[existing] = { ssid, signal, security, connected: inUse === "*" }
                } else {
                    netAdmin._wifiBuf.push({ ssid, signal, security, connected: inUse === "*" })
                }
            }
        }
        onExited: {
            // Sort by signal descending
            netAdmin._wifiBuf.sort((a, b) => b.signal - a.signal)
            netAdmin.wifiNetworks = netAdmin._wifiBuf.slice()
            netAdmin.wifiScanning = false
        }
    }

    // WiFi connect / disconnect
    Process {
        id: wifiConnectProc
        running: false
        command: []
        onRunningChanged: {
            if (!running) {
                command = []
                netAdmin._wifiBuf    = []
                netAdmin.wifiScanning = true
                wifiScanProc.running  = true
                Qt.callLater(netAdmin.refresh)
            }
        }
    }

    // nmcli event monitor — debounced
    Process {
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: data => nmAdminDebounce.restart()
        }
    }

    Timer {
        id: nmAdminDebounce
        interval: 1500
        repeat:   false
        onTriggered: if (netAdmin.currentView === "connections") netAdmin.refresh()
    }

    // ================================================================
    // UI
    // ================================================================

    // ── Inline button component ──────────────────────────────
    component ActionBtn: Rectangle {
        property string icon:     ""
        property string label:    ""
        property bool   danger:   false
        property bool   selected: false
        width:  label ? Math.max(68, labelText.implicitWidth + 28) : 28
        height: 26
        radius: 6
        color: {
            if (danger && _ma.containsMouse) return Qt.rgba(1, 0.3, 0.3, 0.22)
            if (selected) return Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.22)
            if (_ma.containsMouse) return Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.18)
            return Qt.rgba(1, 1, 1, 0.07)
        }
        border.color: {
            if (selected || (!danger && _ma.containsMouse))
                return Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.40)
            if (danger && _ma.containsMouse) return "#aa3333"
            return Qt.rgba(1, 1, 1, 0.10)
        }
        border.width: 1
        Behavior on color        { ColorAnimation { duration: 110 } }
        Behavior on border.color { ColorAnimation { duration: 110 } }
        signal clicked
        Row {
            anchors.centerIn: parent
            spacing: 4
            Text {
                visible:        parent.parent.icon !== ""
                text:           parent.parent.icon
                font.family:    netAdmin.fontFamily
                font.pixelSize: 14
                color: parent.parent.danger && _ma.containsMouse ? "#ff6b6b"
                     : parent.parent.selected                    ? netAdmin.accentColor
                     :                                             netAdmin.textColor
                Behavior on color { ColorAnimation { duration: 110 } }
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: labelText
                visible:        parent.parent.label !== ""
                text:           parent.parent.label
                font.pixelSize: 10
                font.bold:      true
                color: parent.parent.danger && _ma.containsMouse ? "#ff6b6b"
                     : parent.parent.selected                    ? netAdmin.accentColor
                     :                                             netAdmin.textColor
                Behavior on color { ColorAnimation { duration: 110 } }
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: _ma
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            hoverEnabled: true
            onClicked:    parent.clicked()
        }
    }

    // ================================================================
    // VIEW — CONNECTIONS
    // ================================================================
    Item {
        id: viewConnections
        x:       16 + 14
        y:       16 + netAdmin.headerHeight + 8
        width:   netAdmin.panelWidth - 28
        height:  netAdmin.panelFullHeight - 8
        visible: netAdmin.currentView === "connections"
        clip:    true

        // ── Toolbar ──────────────────────────────────────────
        Row {
            id: connToolbar
            width:   parent.width
            height:  28
            spacing: 6
            layoutDirection: Qt.RightToLeft

            ActionBtn {
                id: refreshConnBtn
                icon: "󰑓"
                onClicked: netAdmin.refresh()
            }

            ActionBtn {
                icon:  "󰤨"
                label: "WiFi"
                visible: netAdmin.connectionList.some(c =>
                    c.type.indexOf("wireless") >= 0)
                onClicked: netAdmin.openWifi()
            }
        }

        Rectangle {
            y:     connToolbar.height + 4
            width: parent.width; height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }

        // ── Connection list ───────────────────────────────────
        Flickable {
            y:             connToolbar.height + 9
            width:         parent.width
            height:        parent.height - connToolbar.height - 9
            contentHeight: connCol.implicitHeight
            clip:          true

            Column {
                id:      connCol
                width:   parent.width
                spacing: 4

                Text {
                    width:               parent.width
                    visible:             netAdmin.connectionList.length === 0
                    text:                "No connections found"
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize:      12
                    topPadding:          12
                    color: Qt.rgba(netAdmin.textColor.r, netAdmin.textColor.g, netAdmin.textColor.b, 0.35)
                }

                Repeater {
                    model: netAdmin.connectionList

                    delegate: Rectangle {
                        width:  connCol.width
                        height: 46
                        radius: 8
                        color: modelData.active
                            ? Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.12)
                            : Qt.rgba(1, 1, 1, 0.04)
                        border.color: modelData.active
                            ? Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.32)
                            : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1

                        // Type icon
                        Text {
                            id: _cIcon
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            text:           netAdmin.typeIcon(modelData.type)
                            font.family:    netAdmin.fontFamily
                            font.pixelSize: 20
                            color: modelData.active
                                ? netAdmin.accentColor
                                : Qt.rgba(netAdmin.textColor.r, netAdmin.textColor.g, netAdmin.textColor.b, 0.45)
                        }

                        // Name + device/type label
                        Column {
                            anchors {
                                left:   _cIcon.right; leftMargin: 9
                                right:  _cBtnRow.left; rightMargin: 6
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 1
                            Text {
                                text:          modelData.name
                                font.pixelSize: 12
                                font.bold:      true
                                color:          netAdmin.textColor
                                elide:          Text.ElideRight
                                width:          parent.width
                            }
                            Text {
                                text: modelData.device
                                    ? modelData.device
                                    : modelData.type.split(".").pop()
                                font.pixelSize: 10
                                color: Qt.rgba(netAdmin.textColor.r, netAdmin.textColor.g, netAdmin.textColor.b, 0.48)
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        // Action buttons
                        Row {
                            id: _cBtnRow
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            spacing: 4

                            ActionBtn {
                                icon:     "󰏪"
                                onClicked: netAdmin.openEdit(modelData)
                            }
                            ActionBtn {
                                icon:     modelData.active ? "󰖩" : "󰸿"
                                selected: modelData.active
                                onClicked: {
                                    if (modelData.active) netAdmin.deactivateConn(modelData.uuid)
                                    else                  netAdmin.activateConn(modelData.uuid)
                                }
                            }
                            ActionBtn {
                                icon:     "󰩺"
                                danger:   true
                                onClicked: netAdmin.deleteConn(modelData.uuid)
                            }
                        }
                    }
                }
            }
        }
    }

    // ================================================================
    // VIEW — EDIT CONNECTION
    // ================================================================
    Item {
        id: viewEdit
        x:       16 + 14
        y:       16 + netAdmin.headerHeight + 8
        width:   netAdmin.panelWidth - 28
        visible: netAdmin.currentView === "edit"
        height:  netAdmin.panelFullHeight - 8

        // Back + connection name
        Row {
            id:      editHeader
            spacing: 8
            height:  28
            ActionBtn {
                icon:     "󰁍"
                onClicked: netAdmin.currentView = "connections"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:           netAdmin.selectedConn ? netAdmin.selectedConn.name : ""
                font.pixelSize: 13
                font.bold:      true
                color:          netAdmin.textColor
                elide:          Text.ElideRight
                width:          viewEdit.width - 36
            }
        }

        Rectangle {
            y: editHeader.height + 6; width: parent.width; height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }

        // Spinner while loading
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 60 }
            visible:        netAdmin.editBusy
            text:           "󰑓"
            font.family:    netAdmin.fontFamily
            font.pixelSize: 28
            color:          netAdmin.accentColor
            RotationAnimation on rotation {
                running: netAdmin.editBusy
                loops:   Animation.Infinite
                from: 0; to: 360; duration: 900
            }
        }

        // Edit form
        Column {
            y:       editHeader.height + 14
            width:   parent.width
            spacing: 12
            visible: !netAdmin.editBusy

            // IP method selector
            Column {
                width: parent.width; spacing: 6
                Text {
                    text:               "IPv4 METHOD"
                    font.pixelSize:     10
                    font.bold:          true
                    font.letterSpacing: 1
                    color: Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.70)
                }
                Row {
                    spacing: 6
                    Repeater {
                        model: [{ val: "auto", label: "DHCP" }, { val: "manual", label: "Static" }]
                        ActionBtn {
                            label:    modelData.label
                            selected: netAdmin.editIpMethod === modelData.val
                            width:    72
                            onClicked: netAdmin.editIpMethod = modelData.val
                        }
                    }
                }
            }

            // Static IP fields (hidden in DHCP mode)
            Column {
                width:   parent.width
                spacing: 10
                visible: netAdmin.editIpMethod === "manual"

                // ── IP Address ──
                Column { width: parent.width; spacing: 4
                    Text { text: "IP ADDRESS"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1
                           color: Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.70) }
                    TextField {
                        id: ipAddrFld
                        width: parent.width; height: 30
                        placeholderText: "e.g. 192.168.1.100"
                        color: netAdmin.textColor; font.pixelSize: 11; font.family: netAdmin.fontFamily
                        leftPadding: 9; rightPadding: 9; verticalAlignment: TextField.AlignVCenter
                        background: Rectangle {
                            radius: 6; color: Qt.rgba(1, 1, 1, 0.05)
                            border.color: ipAddrFld.activeFocus
                                ? Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.55)
                                : Qt.rgba(1, 1, 1, 0.13)
                            border.width: 1
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                        }
                    }
                }

                // ── Prefix ──
                Column { width: parent.width; spacing: 4
                    Text { text: "PREFIX LENGTH"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1
                           color: Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.70) }
                    TextField {
                        id: prefixFld
                        width: parent.width; height: 30; text: "24"
                        placeholderText: "24"
                        color: netAdmin.textColor; font.pixelSize: 11; font.family: netAdmin.fontFamily
                        leftPadding: 9; rightPadding: 9; verticalAlignment: TextField.AlignVCenter
                        background: Rectangle {
                            radius: 6; color: Qt.rgba(1, 1, 1, 0.05)
                            border.color: prefixFld.activeFocus
                                ? Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.55)
                                : Qt.rgba(1, 1, 1, 0.13)
                            border.width: 1
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                        }
                    }
                }

                // ── Gateway ──
                Column { width: parent.width; spacing: 4
                    Text { text: "GATEWAY"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1
                           color: Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.70) }
                    TextField {
                        id: gatewayFld
                        width: parent.width; height: 30
                        placeholderText: "e.g. 192.168.1.1"
                        color: netAdmin.textColor; font.pixelSize: 11; font.family: netAdmin.fontFamily
                        leftPadding: 9; rightPadding: 9; verticalAlignment: TextField.AlignVCenter
                        background: Rectangle {
                            radius: 6; color: Qt.rgba(1, 1, 1, 0.05)
                            border.color: gatewayFld.activeFocus
                                ? Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.55)
                                : Qt.rgba(1, 1, 1, 0.13)
                            border.width: 1
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                        }
                    }
                }

                // ── DNS ──
                Column { width: parent.width; spacing: 4
                    Text { text: "DNS SERVERS"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1
                           color: Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.70) }
                    TextField {
                        id: dnsFld
                        width: parent.width; height: 30
                        placeholderText: "e.g. 1.1.1.1 8.8.8.8"
                        color: netAdmin.textColor; font.pixelSize: 11; font.family: netAdmin.fontFamily
                        leftPadding: 9; rightPadding: 9; verticalAlignment: TextField.AlignVCenter
                        background: Rectangle {
                            radius: 6; color: Qt.rgba(1, 1, 1, 0.05)
                            border.color: dnsFld.activeFocus
                                ? Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.55)
                                : Qt.rgba(1, 1, 1, 0.13)
                            border.width: 1
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                        }
                    }
                }
            }

            // Save button
            ActionBtn {
                width:   parent.width
                height:  36
                icon:    "󰄬"
                label:   "Save & Apply"
                selected: true
                onClicked: netAdmin.saveEdit()
            }
        }
    }

    // ================================================================
    // VIEW — WIFI NETWORKS
    // ================================================================
    Item {
        id: viewWifi
        x:       16 + 14
        y:       16 + netAdmin.headerHeight + 8
        width:   netAdmin.panelWidth - 28
        height:  netAdmin.panelFullHeight - 8
        visible: netAdmin.currentView === "wifi"
        clip:    true

        // Header row: back + title + rescan
        Row {
            id:      wifiHeader
            height:  28
            spacing: 6
            width:   parent.width

            ActionBtn {
                icon:     "󰁍"
                onClicked: netAdmin.currentView = "connections"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:           "WiFi Networks"
                font.pixelSize: 13
                font.bold:      true
                color:          netAdmin.textColor
            }
            Item { width: viewWifi.width - 28 - 78 - 18; height: 1 }   // spacer
            ActionBtn {
                width:  72
                icon:   "󰑓"
                label:  netAdmin.wifiScanning ? "Scanning" : "Rescan"
                onClicked: {
                    if (!netAdmin.wifiScanning) {
                        netAdmin._wifiBuf     = []
                        netAdmin.wifiNetworks  = []
                        netAdmin.wifiScanning  = true
                        wifiScanProc.running   = true
                    }
                }
                // Spin the icon while scanning
                Text {
                    visible:        netAdmin.wifiScanning
                    anchors {       left: parent.left; leftMargin: 7; verticalCenter: parent.verticalCenter }
                    text:           "󰑓"
                    font.family:    netAdmin.fontFamily
                    font.pixelSize: 14
                    color:          netAdmin.accentColor
                    RotationAnimation on rotation {
                        running: netAdmin.wifiScanning
                        loops: Animation.Infinite; from: 0; to: 360; duration: 900
                    }
                }
            }
        }

        Rectangle {
            y: wifiHeader.height + 4; width: parent.width; height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }

        // Password prompt (slides in when wifiConnectSsid is set)
        Item {
            id: wifiPwOverlay
            y:       wifiHeader.height + 8
            width:   parent.width
            height:  wifiConnectSsid !== "" ? 112 : 0
            visible: wifiConnectSsid !== ""
            clip:    true
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Column {
                width:   parent.width
                spacing: 8
                padding: 0

                Text {
                    text:           "Connect to: " + netAdmin.wifiConnectSsid
                    font.pixelSize: 11
                    font.bold:      true
                    color:          netAdmin.accentColor
                    elide:          Text.ElideRight
                    width:          parent.width
                }

                TextField {
                    id: wifiPwInput
                    width: parent.width; height: 30
                    echoMode: TextField.Password
                    placeholderText: "Password (leave blank for open networks)"
                    color: netAdmin.textColor
                    font.pixelSize: 11; font.family: netAdmin.fontFamily
                    leftPadding: 9; rightPadding: 9; verticalAlignment: TextField.AlignVCenter
                    background: Rectangle {
                        radius: 6; color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: wifiPwInput.activeFocus
                            ? Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.55)
                            : Qt.rgba(1, 1, 1, 0.13)
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                    }
                }

                Row {
                    spacing: 6
                    ActionBtn {
                        label: "Cancel"
                        onClicked: { netAdmin.wifiConnectSsid = ""; wifiPwInput.text = "" }
                    }
                    ActionBtn {
                        label:    "Connect"
                        selected: true
                        onClicked: {
                            var ssid = netAdmin.wifiConnectSsid
                            var pass = wifiPwInput.text
                            netAdmin.wifiConnectSsid = ""
                            wifiPwInput.text = ""
                            if (pass) {
                                wifiConnectProc.command = ["nmcli", "dev", "wifi", "connect", ssid, "password", pass]
                            } else {
                                wifiConnectProc.command = ["nmcli", "dev", "wifi", "connect", ssid]
                            }
                            wifiConnectProc.running = true
                        }
                    }
                }
            }
        }

        // Network list
        Flickable {
            y:             wifiHeader.height + 8 + wifiPwOverlay.height
            width:         parent.width
            height:        parent.height - wifiHeader.height - 8 - wifiPwOverlay.height
            contentHeight: wifiCol.implicitHeight
            clip:          true
            Behavior on y      { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Column {
                id:      wifiCol
                width:   parent.width
                spacing: 4

                Text {
                    width:               parent.width
                    visible:             netAdmin.wifiScanning && netAdmin.wifiNetworks.length === 0
                    text:                "Scanning…"
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize:      12
                    topPadding:          12
                    color: Qt.rgba(netAdmin.textColor.r, netAdmin.textColor.g, netAdmin.textColor.b, 0.38)
                }

                Repeater {
                    model: netAdmin.wifiNetworks

                    delegate: Rectangle {
                        width:  wifiCol.width
                        height: 42
                        radius: 8
                        color: modelData.connected
                            ? Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.12)
                            : Qt.rgba(1, 1, 1, 0.04)
                        border.color: modelData.connected
                            ? Qt.rgba(netAdmin.accentColor.r, netAdmin.accentColor.g, netAdmin.accentColor.b, 0.32)
                            : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1

                        // Signal strength glyph
                        Text {
                            id: _sigIcon
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            text: {
                                var s = modelData.signal
                                if (s >= 80) return "󰤨"
                                if (s >= 60) return "󰤥"
                                if (s >= 40) return "󰤢"
                                if (s >= 20) return "󰤟"
                                return "󰤯"
                            }
                            font.family:    netAdmin.fontFamily
                            font.pixelSize: 18
                            color: modelData.connected
                                ? netAdmin.accentColor
                                : Qt.rgba(netAdmin.textColor.r, netAdmin.textColor.g, netAdmin.textColor.b, 0.50)
                        }

                        Column {
                            anchors {
                                left: _sigIcon.right; leftMargin: 8
                                right: _wifiActBtn.left; rightMargin: 6
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 1
                            Text {
                                text:           modelData.ssid
                                font.pixelSize: 12
                                font.bold:      true
                                color:          netAdmin.textColor
                                elide:          Text.ElideRight
                                width:          parent.width
                            }
                            Row {
                                spacing: 6
                                Text {
                                    text:           modelData.signal + "%"
                                    font.pixelSize: 10
                                    color: Qt.rgba(netAdmin.textColor.r, netAdmin.textColor.g, netAdmin.textColor.b, 0.48)
                                }
                                Text {
                                    visible:        modelData.security && modelData.security !== "--"
                                    text:           "󰌾 " + modelData.security
                                    font.pixelSize: 10
                                    color: Qt.rgba(netAdmin.textColor.r, netAdmin.textColor.g, netAdmin.textColor.b, 0.40)
                                }
                            }
                        }

                        ActionBtn {
                            id:    _wifiActBtn
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            icon:   modelData.connected ? "󰖪" : "󰤨"
                            label:  modelData.connected ? "" : "Connect"
                            danger: modelData.connected
                            onClicked: {
                                if (modelData.connected) {
                                    // Disconnect: find the active wifi device
                                    var wifiDev = netAdmin.connectionList
                                        .find(c => c.active && c.type.indexOf("wireless") >= 0)
                                    wifiConnectProc.command = [
                                        "nmcli", "dev", "disconnect",
                                        wifiDev ? wifiDev.device : "wlan0"
                                    ]
                                    wifiConnectProc.running = true
                                } else if (!modelData.security || modelData.security === "--") {
                                    wifiConnectProc.command = ["nmcli", "dev", "wifi", "connect", modelData.ssid]
                                    wifiConnectProc.running = true
                                } else {
                                    netAdmin.wifiConnectSsid = modelData.ssid
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
