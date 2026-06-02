// modules/network/CommStatusButton.qml

import QtQuick
import Quickshell.Io
import "../.."

// ============================================================
// COMM STATUS BUTTON — static bar label styled to match
// the SystemGraphs bar aesthetic (sharp rect, black border).
// Checks internet connectivity every 5 seconds.
// ============================================================
Item {
    id: root

    property color backgroundColor: Colors.col_background
    property color textColor:       Colors.col_primary
    property int  fontSize:         11
    property color statusBarColor:  root.online ? Colors.col_source_color : Colors.col_primary

    property bool online: true
    property int  horizontalMargin: 0

    // ── Connectivity check ───────────────────────────────────
    Process {
        id: pingProc
        running: false
        command: ["sh", "-c", "ping -c 1 -W 2 1.1.1.1 > /dev/null 2>&1 && echo ok || echo fail"]
        stdout: SplitParser {
            onRead: data => {
                root.online = data.trim() === "ok"
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!pingProc.running) pingProc.running = true
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
            text: "//COMMS LINK : DISCONNECTED"
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
                text:           "COMM LINK 1 :  "
                font.pixelSize: root.fontSize
                font.bold:      true
                color:          Colors.col_primary
                anchors.verticalCenter: statusRow.verticalCenter
            }

            Item {
                id: statusGraphWrap
                width: 75
                height: 12
                anchors.verticalCenter: statusRow.verticalCenter

                Rectangle {
                    id: commStatusBar
                    anchors.fill: parent
                    radius: 0
                    color: Colors.col_background
                    border.color: "black"
                    border.width: 1

                    Rectangle {
                        id: commStatusFill
                        anchors.left: parent.left
                        anchors.leftMargin: 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, Math.round((parent.width - 2) * (root.online ? 1 : 0)))
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
