import Quickshell
import Quickshell.Io
import QtQuick

// ============================================================
// NETWORK DROPDOWN — drops down from the EthernetPanel IP pill
// Shows connection name, IP, gateway and DNS for the active
// interface, plus a button to launch nm-connection-editor.
// ============================================================
DropdownBase {
    id: netDrop
    reloadableId: "networkDropdown"

    implicitHeight:  380
    panelFullHeight: 274
    panelWidth:      270
    panelTitle:      "Network"
    panelIcon:       "󰈀"
    headerHeight:    34

    // Refresh all info whenever the panel opens
    onAboutToOpen: ifaceProc.running = true

    // --------------------------------------------------------
    // GATHERED INFO
    // --------------------------------------------------------
    property string iface:          ""   // discovered dynamically
    property string infoConnection: iface !== "" ? iface : "—"
    property string infoIp:         "—"
    property string infoGateway:    "—"
    property string infoDns:        "—"

    property string infoVlanId: "—"

    // Derive VLAN ID from the 3rd octet: 192.168.10.x → VLAN10
    onInfoIpChanged: {
        var parts = infoIp.split(".")
        if (parts.length >= 3) {
            var octet = parseInt(parts[2])
            infoVlanId = isNaN(octet) ? "—" : "VLAN" + octet
        } else {
            infoVlanId = "—"
        }
    }

    // --------------------------------------------------------
    // STEP 1 — discover which VLAN interface is currently connected
    // --------------------------------------------------------
    Process {
        id: ifaceProc
        running: false
        command: ["sh", "-c",
            "nmcli -t -f DEVICE,TYPE,STATE dev | awk -F: '$2==\"vlan\" && $3==\"connected\"{print $1; exit}'"]
        stdout: SplitParser {
            onRead: data => {
                var s = data.trim()
                if (s) netDrop.iface = s
            }
        }
        onExited: (code, status) => {
            if (netDrop.iface !== "") {
                detailsProc.running = true
            } else {
                netDrop.iface       = ""
                netDrop.infoIp      = "—"
                netDrop.infoGateway = "—"
                netDrop.infoDns     = "—"
            }
        }
    }

    // --------------------------------------------------------
    // STEP 2 — fetch IP, gateway and DNS in one nmcli call
    // --------------------------------------------------------
    Process {
        id: detailsProc
        running: false
        command: ["sh", "-c",
            "nmcli dev show \"" + netDrop.iface + "\" | " +
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
                if      (key === "ip")  netDrop.infoIp      = val || "—"
                else if (key === "gw")  netDrop.infoGateway = val || "—"
                else if (key === "dns") netDrop.infoDns     = val || "—"
            }
        }
    }

    // --------------------------------------------------------
    // EVENT-DRIVEN REFRESH — nmcli monitor fires on every NM event
    // A 1.5 s debounce avoids hammering nmcli while a connection
    // is still being brought up.
    // --------------------------------------------------------
    Process {
        id: nmMonitorProc
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: data => nmDebounce.restart()
        }
    }

    Timer {
        id: nmDebounce
        interval: 1500
        repeat: false
        onTriggered: ifaceProc.running = true
    }

    // Initial fetch at startup
    Component.onCompleted: ifaceProc.running = true

    Process {
        id: nmConnEditor
        running: false
        command: ["nm-connection-editor"]
    }

        // ── Info column ───────────────────────────────────
        Column {
            x: 16 + 14
            y: 16 + netDrop.headerHeight + 12
            width: netDrop.panelWidth - 28
            spacing: 0

            // Helper component: one info row
            component InfoRow: Item {
                property string label: ""
                property string value: "—"
                width: parent.width
                height: 36

                Text {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    text: label
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1
                    color: Qt.rgba(netDrop.accentColor.r,
                                   netDrop.accentColor.g,
                                   netDrop.accentColor.b, 0.7)
                }
                Text {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    text: value
                    font.pixelSize: 11
                    color: netDrop.textColor
                    elide: Text.ElideRight
                    width: parent.width * 0.62
                    horizontalAlignment: Text.AlignRight
                }
                // thin separator
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }
            }

            InfoRow { label: "CONNECTION"; value: netDrop.infoConnection }

            // ── VLAN row — accent pill badge ───────────────────────
            Item {
                width: parent.width
                height: 36

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "VLAN"
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1
                    color: Qt.rgba(netDrop.accentColor.r,
                                   netDrop.accentColor.g,
                                   netDrop.accentColor.b, 0.7)
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 6

                    // Accent pill: VLAN10
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 20
                        width: vlanBadgeText.implicitWidth + 14
                        radius: 5
                        color: netDrop.infoVlanId === "—"
                            ? Qt.rgba(1, 1, 1, 0.05)
                            : Qt.rgba(netDrop.accentColor.r,
                                      netDrop.accentColor.g,
                                      netDrop.accentColor.b, 0.15)
                        border.color: netDrop.infoVlanId === "—"
                            ? Qt.rgba(1, 1, 1, 0.10)
                            : Qt.rgba(netDrop.accentColor.r,
                                      netDrop.accentColor.g,
                                      netDrop.accentColor.b, 0.50)
                        border.width: 1

                        Behavior on color       { ColorAnimation { duration: 220 } }
                        Behavior on border.color { ColorAnimation { duration: 220 } }

                        Text {
                            id: vlanBadgeText
                            anchors.centerIn: parent
                            text: netDrop.infoVlanId
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 0.5
                            color: netDrop.infoVlanId === "—"
                                ? Qt.rgba(1, 1, 1, 0.25)
                                : netDrop.accentColor
                            Behavior on color { ColorAnimation { duration: 220 } }
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }
            }

            InfoRow { label: "IP";         value: netDrop.infoIp         }
            InfoRow { label: "GATEWAY";    value: netDrop.infoGateway    }
            InfoRow { label: "DNS";        value: netDrop.infoDns        }
        }

        // ── nm-connection-editor button ───────────────────
        Item {
            anchors {
                left:         parent.left
                right:        parent.right
                bottom:       parent.bottom
                leftMargin:   16 + 14
                rightMargin:  16 + 14
                bottomMargin: 14
            }
            height: 40

            Rectangle {
                id: nmBtn
                anchors.fill: parent
                radius: 10
                color: nmBtnArea.containsMouse
                    ? Qt.rgba(netDrop.accentColor.r,
                              netDrop.accentColor.g,
                              netDrop.accentColor.b, 0.22)
                    : Qt.rgba(netDrop.accentColor.r,
                              netDrop.accentColor.g,
                              netDrop.accentColor.b, 0.10)
                border.color: Qt.rgba(netDrop.accentColor.r,
                                      netDrop.accentColor.g,
                                      netDrop.accentColor.b, 0.35)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 160 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󱘖"
                        font.family: fontFamily
                        font.pixelSize: 18
                        color: netDrop.accentColor
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Connection Editor"
                        font.pixelSize: 12
                        font.bold: true
                        color: netDrop.textColor
                    }
                }

                MouseArea {
                    id: nmBtnArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        nmConnEditor.running = true
                        netDrop.closePanel()
                    }
                }
            }
        }
}
