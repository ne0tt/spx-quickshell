import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls

// ============================================================
// BLUETOOTH DROPDOWN — power toggle + paired device list
// ============================================================
DropdownBase {
    id: btDrop
    reloadableId: "bluetoothDropdown"

    panelWidth:      260
    panelTitle:      "Bluetooth"
    panelIcon:       "󰂯"
    headerHeight:    34
    // Off: nothing in content area (toggle lives in header)
    // On:  fit device list; 8 px top pad + 9 px flicker offset + N×52 cards, capped at 268
    panelFullHeight: {
        if (!btDrop.btPowered) return 0
        if (btDrop.pairedDevices.length === 0) return 60
        return Math.min(268, 17 + btDrop.pairedDevices.length * 52)
    }
    implicitHeight:  400

    // ── State ────────────────────────────────────────────────
    // Injected from shell.qml — BluetoothState is the single source of truth
    property QtObject btData: null

    readonly property bool btPowered: btData ? btData.btPowered : false
    property var  pairedDevices: []
    property var  _devBuf:       []

    // Resize panel and refresh device list whenever power state changes
    onBtPoweredChanged: {
        if (btDrop.isOpen) btDrop.resizePanel()
        if (btDrop.btPowered) { btDrop._devBuf = []; statusProc.running = true }
    }

    // Pre-load on startup so state is ready before first open
    Component.onCompleted: { btDrop._devBuf = []; statusProc.running = true }

    // Refresh on open so it's always current
    Connections {
        target: btDrop
        function onIsOpenChanged() {
            if (btDrop.isOpen) { btDrop._devBuf = []; statusProc.running = true }
        }
    }

    // ── Functions ────────────────────────────────────────────
    function _refresh() {
        btDrop._devBuf = []
        statusProc.running = true
    }

    function togglePower() {
        if (btData) btData.togglePower()
    }

    function connectDevice(addr) {
        deviceProc.command = ["bluetoothctl", "connect", addr]
        deviceProc.running = true
    }

    function disconnectDevice(addr) {
        deviceProc.command = ["bluetoothctl", "disconnect", addr]
        deviceProc.running = true
    }

    // ── Processes ────────────────────────────────────────────
    // Enumerate paired devices only — power state comes from btData
    Process {
        id: statusProc
        running: false
        command: ["bash", "-c",
            "bluetoothctl devices Paired | while read _ addr rest; do " +
            "  info=$(bluetoothctl info \"$addr\"); " +
            "  name=$(echo \"$info\" | awk -F': ' '/^\\tName:/{print $2; exit}'); " +
            "  conn=$(echo \"$info\" | grep -c 'Connected: yes'); " +
            "  echo \"DEVICE:$addr|${name:-$addr}|$conn\"; " +
            "done"]

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.startsWith("DEVICE:")) {
                    var parts = line.substring(7).split("|")
                    if (parts.length >= 3) {
                        btDrop._devBuf.push({
                            address:   parts[0],
                            name:      parts[1] || parts[0],
                            connected: parts[2] === "1"
                        })
                    }
                }
            }
        }

        onExited: btDrop.pairedDevices = btDrop._devBuf.slice()
    }

    // Connect / disconnect a device
    Process {
        id: deviceProc
        running: false
        command: []
        onRunningChanged: if (!running) { command = []; Qt.callLater(btDrop._refresh) }
    }

    // ── UI ───────────────────────────────────────────────────

    // Mini power toggle pill — sits in the header row, right-aligned
    Rectangle {
        x: 16 + btDrop.panelWidth - 14 - 34
        y: 16 + Math.floor((btDrop.headerHeight - 18) / 2)
        z: 10
        width: 34; height: 18; radius: 9
        color: btDrop.btPowered
               ? btDrop.accentColor
               : Qt.rgba(btDrop.dimColor.r, btDrop.dimColor.g, btDrop.dimColor.b, 0.3)
        Behavior on color { ColorAnimation { duration: 160 } }

        Rectangle {
            width: 12; height: 12; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            x: btDrop.btPowered ? parent.width - width - 3 : 3
            color: "white"
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: btDrop.togglePower()
        }
    }

    // Paired device list (shown only when powered and devices exist)
    Item {
        x: 30; y: 16 + btDrop.headerHeight + 8
        width: btDrop.panelWidth - 28
        height: Math.max(0, btDrop.panelFullHeight - 8)
        visible: btDrop.btPowered
        clip: true

        // Divider
        Rectangle {
            width: parent.width; height: 1
            color: Qt.rgba(btDrop.dimColor.r, btDrop.dimColor.g, btDrop.dimColor.b, 0.2)
            visible: btDrop.pairedDevices.length > 0
        }

        // No devices label
        Text {
            y: 12; width: parent.width
            visible: btDrop.pairedDevices.length === 0
            text: "No paired devices"
            horizontalAlignment: Text.AlignHCenter
            color: Qt.rgba(btDrop.dimColor.r, btDrop.dimColor.g, btDrop.dimColor.b, 0.4)
            font.pixelSize: 12
        }

        Flickable {
            y: 9
            width: parent.width
            height: parent.height - 9
            contentHeight: deviceCol.implicitHeight
            clip: true
            visible: btDrop.pairedDevices.length > 0
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: deviceCol
                width: parent.width
                spacing: 0

                Repeater {
                    model: btDrop.pairedDevices

                    Item {
                        width: deviceCol.width; height: 52

                        Row {
                            anchors {
                                left: parent.left
                                right: actionBtn.left; rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 10

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰂱"
                                font.family: fontFamily
                                font.pixelSize: 20
                                color: modelData.connected ? btDrop.accentColor
                                                           : Qt.rgba(btDrop.dimColor.r, btDrop.dimColor.g, btDrop.dimColor.b, 0.5)
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    text: modelData.name
                                    color: btDrop.textColor
                                    font.pixelSize: 13
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: 148
                                }
                                Text {
                                    text: modelData.connected ? "Connected" : "Paired"
                                    color: modelData.connected
                                           ? btDrop.accentColor
                                           : Qt.rgba(btDrop.dimColor.r, btDrop.dimColor.g, btDrop.dimColor.b, 0.5)
                                    font.pixelSize: 10
                                }
                            }
                        }

                        // Connect / disconnect button
                        Rectangle {
                            id: actionBtn
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 32; height: 32; radius: 16
                            color: actionHover.containsMouse
                                   ? Qt.rgba(btDrop.accentColor.r, btDrop.accentColor.g, btDrop.accentColor.b, 0.18)
                                   : Qt.rgba(btDrop.dimColor.r, btDrop.dimColor.g, btDrop.dimColor.b, 0.1)

                            Text {
                                anchors.centerIn: parent
                                text: modelData.connected ? "󰂲" : "󰂱"
                                font.family: fontFamily
                                font.pixelSize: 14
                                color: modelData.connected ? btDrop.accentColor : btDrop.dimColor
                            }

                            MouseArea {
                                id: actionHover
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: modelData.connected
                                           ? btDrop.disconnectDevice(modelData.address)
                                           : btDrop.connectDevice(modelData.address)
                            }
                        }
                    }
                }
            }
        }
    }
}
