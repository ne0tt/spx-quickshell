// modules/network/CommStatusButton.qml

import QtQuick
import Quickshell.Io
import "../.."

// ============================================================
// SECURE COMM STATUS BUTTON — static bar label styled to match
// the SystemGraphs bar aesthetic (sharp rect, black border).
// Checks Surfshark VPN activity every second.
// ============================================================
Item {
    id: root

    property color backgroundColor: Colors.col_background
    property color textColor:       Colors.col_primary
    property int  fontSize:         11
    property color statusBarColor:  root.vpnActive ? Colors.col_source_color : Colors.col_primary

    property bool vpnActive: false
    property int  horizontalMargin: 0

    // ── Surfshark VPN check ──────────────────────────────────
    Process {
        id: vpnCheckProc
        running: false
        command: [
            "sh", "-c",
            "if nmcli -t -f NAME,TYPE,ACTIVE con show 2>/dev/null | awk -F: '$2==\"wireguard\" && $3==\"yes\" {found=1} END{exit(found?0:1)}'; then "
            + "echo active; "
            + "else "
            + "echo disconnected; "
            + "fi"
        ]
        stdout: SplitParser {
            onRead: data => {
                root.vpnActive = data.trim() === "active"
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!vpnCheckProc.running) vpnCheckProc.running = true
        }
    }

    width:  pill.width
    height: 14

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        width:        implicitLabel.implicitWidth + 5
        height:       14
        radius:       0
        color:        "transparent"

        Text {
            id: implicitLabel
            visible: false
            text: "//SECURE LINK : DISCONNECTED"
            font.pixelSize: root.fontSize
            font.bold: true
        }

        Row {
            id: statusRow
            anchors.centerIn: parent
            spacing: 0

            Text {
                text:           "//"
                font.pixelSize: root.fontSize
                font.bold:      true
                color:          Colors.col_primary
                anchors.verticalCenter: statusRow.verticalCenter
            }

            Text {
                text:           "SECURE LINK :  "
                font.pixelSize: root.fontSize
                font.bold:      true
                color:          Colors.col_primary
                anchors.verticalCenter: statusRow.verticalCenter
            }

            Item {
                id: secureStatusGraphWrap
                width: 75
                height: 12
                anchors.verticalCenter: statusRow.verticalCenter

                Rectangle {
                    id: secureStatusBar
                    anchors.fill: parent
                    radius: 0
                    color: Colors.col_background
                    border.color: "black"
                    border.width: 1

                    Rectangle {
                        id: secureStatusFill
                        anchors.left: parent.left
                        anchors.leftMargin: 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, Math.round((parent.width - 2) * (root.vpnActive ? 1 : 0)))
                        height: parent.height - 2
                        radius: 0
                        color: root.statusBarColor
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }

}
