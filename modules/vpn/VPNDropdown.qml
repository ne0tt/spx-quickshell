import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "../../base"

// ============================================================
// VPN DROPDOWN — drops down from the VPN Module pill
// Lists all WireGuard connections; click to bring up or down.
// ============================================================
DropdownBase {
    id: vpnDrop
    reloadableId: "vpnDropdown"

    keyboardFocusEnabled: true

    Item { focus: true; Keys.onEscapePressed: vpnDrop.closePanel() }

    panelWidth:      270

    // --------------------------------------------------------
    // DYNAMIC CONNECTION LIST
    // --------------------------------------------------------
    readonly property int _cardH: 48
    readonly property int _gapH:  8
    readonly property int _padH:  20
    property var wgConnections: []
    property var activeSet:     ({})   // name -> true if active
    property var _buf:          []     // accumulates {name, active} during wgProc run

    panelTitle:      "WireGuard"
    panelIcon:       ""
    headerHeight:    34
    panelFullHeight: wgConnections.length > 0
        ? _padH + wgConnections.length * _cardH + (wgConnections.length - 1) * _gapH
        : 80
    implicitHeight:  panelFullHeight + headerHeight + 52

    // --------------------------------------------------------
    // SINGLE PROCESS — list WireGuard connections + active status
    // --------------------------------------------------------
    Process {
        id: wgProc
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
                vpnDrop._buf.push({
                    name:   line.substring(0, sep),
                    active: line.substring(sep + 1) === "active"
                })
            }
        }
        onExited: {
            var names  = vpnDrop._buf.map(x => x.name)
            var newSet = {}
            vpnDrop._buf.forEach(x => { if (x.active) newSet[x.name] = true })
            vpnDrop._buf          = []
            vpnDrop.wgConnections = names
            vpnDrop.activeSet     = newSet
        }
    }

    // ── nmcli monitor — debounced refresh ─────────────────────
    Process {
        running: vpnDrop.isOpen
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: data => nmVpnDebounce.restart()
        }
    }

    Timer {
        id: nmVpnDebounce
        interval: 800
        repeat: false
        onTriggered: { vpnDrop._buf = []; wgProc.running = true }
    }

    // Pre-load on startup so panel height is correct before first open
    Component.onCompleted: {
        vpnDrop._buf = []
        wgProc.running = true
    }

    Connections {
        target: vpnDrop
        function onIsOpenChanged() {
            if (vpnDrop.isOpen) {
                vpnDrop._buf = []
                wgProc.running = true
            }
        }
    }

        // ── Connection list ───────────────────────────────
        Column {
            x: 16 + 14
            y: 16 + vpnDrop.headerHeight + 8
            width: vpnDrop.panelWidth - 28
            spacing: 8

            Repeater {
                model: vpnDrop.wgConnections

                Item {
                    id: wgRow
                    width: parent.width
                    height: 48

                    property bool isActive:   vpnDrop.activeSet[modelData] === true
                    property bool isBusy:     false
                    property bool _wasActive: false

                    onIsActiveChanged: {
                        if (isActive && !_wasActive) card.flash()
                        _wasActive = isActive
                    }

                    // ── Toggle process ─────────────────────────────────────────
                    Process {
                        id: wgToggleProc
                        running: false
                        command: wgRow.isActive
                            ? ["nmcli", "connection", "down", modelData]
                            : ["nmcli", "connection", "up",   modelData]
                        onExited: (code, status) => {
                            wgRow.isBusy    = false
                            vpnDrop._buf    = []
                            wgProc.running  = true
                        }
                    }

                    SelectableCard {
                        id: card
                        width: parent.width
                        isActive:    wgRow.isActive
                        isBusy:      wgRow.isBusy
                        cardIcon:    "󰦝"
                        label:       modelData
                        subtitle:    wgRow.isBusy
                            ? (wgRow.isActive ? "Disconnecting…" : "Connecting…")
                            : (wgRow.isActive ? "Connected" : "Disconnected")
                        isPanelOpen: vpnDrop.isOpen
                        accentColor: vpnDrop.accentColor
                        textColor:   vpnDrop.textColor
                        dimColor:    vpnDrop.dimColor
                        onClicked: {
                            wgRow.isBusy         = true
                            wgToggleProc.running = true
                        }
                    }
                }
            }

            // ── Empty state ───────────────────────────────
            Item {
                visible: vpnDrop.wgConnections.length === 0
                width: parent.width
                height: 48

                Text {
                    anchors.centerIn: parent
                    text: "No WireGuard connections found"
                    font.pixelSize: 11
                    color: Qt.rgba(vpnDrop.dimColor.r,
                                   vpnDrop.dimColor.g,
                                   vpnDrop.dimColor.b, 0.40)
                }
            }
        }
}
