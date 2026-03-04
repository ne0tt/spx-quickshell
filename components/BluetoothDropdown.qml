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
    // Off: just header + toggle, footer handles bottom
    // On:  size to fit devices (divider 1 + flickable offset 9 + N*52), capped at 330
    panelFullHeight: {
        if (!btDrop.btPowered) return 74
        if (btDrop.pairedDevices.length === 0) return 116
        return Math.min(296, 90 + btDrop.pairedDevices.length * 52)
    }
    implicitHeight:  400

    // ── State ────────────────────────────────────────────────
    property bool btPowered:    false
    property var  pairedDevices: []
    property var  _devBuf:       []

    // Force panel to resize whenever BT power state changes
    onBtPoweredChanged: { if (btDrop.isOpen) btDrop.resizePanel() }

    // Pre-load on startup so state is ready before first open
    Component.onCompleted: { btDrop._devBuf = []; statusProc.running = true }

    // Refresh on open so it's always current
    Connections {
        target: btDrop
        function onIsOpenChanged() {
            if (btDrop.isOpen) { btDrop._devBuf = []; statusProc.running = true }
        }
    }

    // ── bluetoothctl monitor — debounced refresh ──────────────
    Process {
        running: true
        command: ["bluetoothctl", "monitor"]
        stdout: SplitParser {
            onRead: data => btDebounce.restart()
        }
    }

    Timer {
        id: btDebounce
        interval: 800
        repeat: false
        onTriggered: { btDrop._devBuf = []; statusProc.running = true }
    }

    // ── Functions ────────────────────────────────────────────
    function _refresh() {
        btDrop._devBuf = []
        statusProc.running = true
    }

    function togglePower() {
        powerProc.command = ["bluetoothctl", "power", btDrop.btPowered ? "off" : "on"]
        powerProc.running = true
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
    // Poll power state and all paired devices in one script
    Process {
        id: statusProc
        running: false
        command: ["bash", "-c",
            "echo STATUS:$(bluetoothctl show | awk '/Powered:/{print $2; exit}'); " +
            "bluetoothctl devices Paired | while read _ addr rest; do " +
            "  info=$(bluetoothctl info \"$addr\"); " +
            "  name=$(echo \"$info\" | awk -F': ' '/^\\tName:/{print $2; exit}'); " +
            "  conn=$(echo \"$info\" | grep -c 'Connected: yes'); " +
            "  echo \"DEVICE:$addr|${name:-$addr}|$conn\"; " +
            "done"]

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.startsWith("STATUS:")) {
                    btDrop.btPowered = line.substring(7).trim() === "yes"
                } else if (line.startsWith("DEVICE:")) {
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

    // Toggle power
    Process {
        id: powerProc
        running: false
        command: []
        onRunningChanged: if (!running) { command = []; Qt.callLater(btDrop._refresh) }
    }

    // Connect / disconnect a device
    Process {
        id: deviceProc
        running: false
        command: []
        onRunningChanged: if (!running) { command = []; Qt.callLater(btDrop._refresh) }
    }

    // ── UI ───────────────────────────────────────────────────

    // Power toggle row
    Item {
        x: 30; y: 62
        width: btDrop.panelWidth - 28
        height: 44

        Rectangle {
            id: toggleTrack
            width: 48; height: 26; radius: 13
            anchors.verticalCenter: parent.verticalCenter
            color: btDrop.btPowered
                   ? btDrop.accentColor
                   : Qt.rgba(btDrop.dimColor.r, btDrop.dimColor.g, btDrop.dimColor.b, 0.3)
            Behavior on color { ColorAnimation { duration: 160 } }

            Rectangle {
                width: 20; height: 20; radius: 10
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

        Text {
            anchors { left: toggleTrack.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: btDrop.btPowered ? "On" : "Off"
            color: btDrop.btPowered ? btDrop.textColor : btDrop.dimColor
            font.pixelSize: 14
            font.bold: true
            Behavior on color { ColorAnimation { duration: 160 } }
        }
    }

    // Paired device list (shown only when powered and devices exist)
    Item {
        x: 30; y: 114
        width: btDrop.panelWidth - 28
        // Available height = panelFullHeight - y position (clamped so never negative)
        height: Math.max(0, btDrop.panelFullHeight - 80)
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

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 1
                            color: Qt.rgba(btDrop.dimColor.r, btDrop.dimColor.g, btDrop.dimColor.b, 0.08)
                        }
                    }
                }
            }
        }
    }
}
