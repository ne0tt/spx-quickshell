import Quickshell
import Quickshell.Io
import QtQuick
import "../../base"

// ============================================================
// VLAN DROPDOWN — drops down like VolumeDropdown / CalendarPanel
// Shows each monitored VLAN as a rounded card with a circle
// icon on the left; active VLANs are highlighted.
// ============================================================
DropdownBase {
    id: vlanDrop
    reloadableId: "vlanDropdown"

    // Card = 48 px tall + 8 px gap; padding top = 20 (footer handles bottom)
    readonly property int _cardH:  48
    readonly property int _gapH:   8
    readonly property int _padH:   20
    property var vlans:     []
    property var activeSet:  ({})   // name -> true if currently active
    property var _buf:        []     // accumulates {name, active} during vlanProc run

    panelTitle:      "VLANs"
    panelIcon:       "󰌘"
    headerHeight:    34
    panelFullHeight: vlans.length > 0
        ? _padH + vlans.length * _cardH + (vlans.length - 1) * _gapH
        : 80
    implicitHeight:  panelFullHeight + headerHeight + 52
    panelWidth:      270

    // --------------------------------------------------------
    // SINGLE PROCESS — list all VLAN connections + active status
    // One nmcli fork instead of two; same pattern as VPNDropdown.
    // --------------------------------------------------------
    Process {
        id: vlanProc
        running: false
        command: ["sh", "-c",
            "nmcli -t -f NAME,TYPE,ACTIVE con show | "
            + "awk -F: '$2==\"vlan\"{print $1 \"|\" ($3==\"yes\"?\"active\":\"inactive\")}'"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (!line) return
                var sep = line.lastIndexOf("|")
                if (sep < 0) return
                vlanDrop._buf.push({
                    name:   line.substring(0, sep),
                    active: line.substring(sep + 1) === "active"
                })
            }
        }
        onExited: {
            var names  = vlanDrop._buf.map(x => x.name).sort((a, b) => a.localeCompare(b))
            var newSet = {}
            vlanDrop._buf.forEach(x => { if (x.active) newSet[x.name] = true })
            vlanDrop._buf      = []
            vlanDrop.vlans     = names
            vlanDrop.activeSet = newSet
        }
    }

    // ── Single nmcli monitor — debounced activeProc refresh ───────
    Process {
        running: vlanDrop.isOpen
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: data => nmVlanDebounce.restart()
        }
    }

    Timer {
        id: nmVlanDebounce
        interval: 800
        repeat: false
        onTriggered: { vlanDrop._buf = []; vlanProc.running = true }
    }

    // Fetch at startup so panel height is correct before first open.
    Component.onCompleted: {
        vlanDrop._buf = []
        vlanProc.running = true
    }

    Connections {
        target: vlanDrop
        function onIsOpenChanged() {
            if (vlanDrop.isOpen) {
                vlanDrop._buf = []
                vlanProc.running = true
            }
        }
    }

    // ── VLAN list ─────────────────────────────────────
        Column {
            x: 16 + 14
            y: 16 + vlanDrop.headerHeight + 10
            width: vlanDrop.panelWidth - 28
            spacing: 8

            Repeater {
                model: vlanDrop.vlans

                Item {
                    id: vlanRow
                    width: parent.width
                    height: 48

                    property bool isActive:   vlanDrop.activeSet[modelData] === true
                    property bool isBusy:     false
                    property bool _wasActive: false

                    onIsActiveChanged: {
                        if (isActive && !_wasActive) card.flash()
                        _wasActive = isActive
                    }

                    // ── Toggle VLAN up / down on click ────────────────────
                    Process {
                        id: toggleProc
                        running: false
                        command: vlanRow.isActive
                            ? ["nmcli", "connection", "down", modelData]
                            : ["nmcli", "connection", "up",   modelData]
                        onExited: (exitCode, exitStatus) => {
                            vlanRow.isBusy   = false
                            vlanDrop._buf    = []
                            vlanProc.running = true
                        }
                    }

                    SelectableCard {
                        id: card
                        width: parent.width
                        isActive:       vlanRow.isActive
                        isBusy:         vlanRow.isBusy
                        cardIcon:       "󰌘"
                        label:          modelData.toUpperCase()
                        subtitle:       vlanRow.isActive ? "Active" : "Inactive"
                        isPanelOpen:    vlanDrop.isOpen
                        accentColor:    vlanDrop.accentColor
                        textColor:      vlanDrop.textColor
                        dimColor:       vlanDrop.dimColor
                        dotActiveColor: vlanDrop.textColor   // VLAN uses textColor, not accentColor
                        onClicked: {
                            vlanRow.isBusy     = true
                            toggleProc.running = true
                        }
                    }
                }
            }
        }
}
