import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../state"
import "../.."

Item {
    id: graphs

    property int cpuPercent: 0
    property int ramPercent: 0
    readonly property int volumePercent: VolumeState.muted ? 0 : VolumeState.volume
    readonly property string volumeText: VolumeState.muted ? "MUTED" : VolumeState.volume + "%"
    property string sensorPath: ""
    property int tempC: 0
    property string tempText: "--°C"
    readonly property int tempPercent: _clampPercent(tempC)
    property int panelHeight: 12
    property int labelFontSize: 11
    property int iconFontSize: 12
    property bool showLabelText: true
    property color graphBackgroundColor: Colors.col_background
    property color graphFillColor: Colors.col_source_color
    property bool cpuGlowOn: false
    property bool tempGlowOn: false
    readonly property color cpuGraphFillColor: cpuPercent >= 80 ? "#ff4444" : graphs.graphFillColor
    readonly property color tempGraphFillColor: tempC >= 80 ? "#ff4444" : graphs.graphFillColor
    property color graphTextColor: Colors.col_primary
    readonly property int barWidth: 75
    readonly property int labelGap: 5
    readonly property int labelWidth: 65
    readonly property int labelRightMargin: 10
    readonly property int metricWidth: barWidth + labelGap + labelWidth + labelRightMargin
    readonly property string cpuIcon: "󰍛"
    readonly property string ramIcon: "󰘚"
    readonly property string tempIcon: "󰔏"
    readonly property string volumeIcon: "󰕾"
    readonly property string iconFontFamily: "Symbols Nerd Font Mono"
    property real _prevCpuTotal: -1
    property real _prevCpuIdle: -1

    width: metricWidth * 4 + 24
    height: panelHeight

    function _clampPercent(v) {
        return Math.max(0, Math.min(100, v))
    }

    function _updateFromLine(line) {
        if (line.startsWith("cpu=")) {
            var parts = line.substring(4).split("|")
            if (parts.length !== 2) return

            var total = parseFloat(parts[0])
            var idle = parseFloat(parts[1])
            if (!isNaN(total) && !isNaN(idle)) {
                if (_prevCpuTotal >= 0 && total > _prevCpuTotal) {
                    var dt = total - _prevCpuTotal
                    var di = idle - _prevCpuIdle
                    cpuPercent = _clampPercent(Math.round(((dt - di) * 100) / dt))
                }
                _prevCpuTotal = total
                _prevCpuIdle = idle
            }
        } else if (line.startsWith("mem=")) {
            var m = line.substring(4).split("|")
            if (m.length !== 2) return

            var totalMem = parseFloat(m[0])
            var availMem = parseFloat(m[1])
            if (!isNaN(totalMem) && !isNaN(availMem) && totalMem > 0) {
                ramPercent = _clampPercent(Math.round(((totalMem - availMem) * 100) / totalMem))
            }
        }
    }

    Process {
        id: statsProc
        running: false
        command: [
            "bash",
            "-c",
            "awk '/^cpu /{print \"cpu=\" ($2+$3+$4+$5+$6+$7+$8+$9+$10) \"|\" $5}' /proc/stat; awk '/MemTotal:/{t=$2} /MemAvailable:/{a=$2} END{print \"mem=\" t \"|\" a}' /proc/meminfo"
        ]

        stdout: SplitParser {
            onRead: data => {
                var lines = data.trim().split(/\n+/)
                for (var i = 0; i < lines.length; ++i) {
                    if (lines[i]) graphs._updateFromLine(lines[i].trim())
                }
            }
        }
    }

    // Use the same sensor autodetection approach as TemperatureButton.
    Process {
        id: sensorDetect
        running: false
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do [ -d \"$d\" ] || continue; n=$(cat \"$d/name\" 2>/dev/null); case \"$n\" in coretemp|k10temp|zenpower|cpu_thermal|x86_pkg_temp) for l in \"$d\"/temp*_label; do [ -r \"$l\" ] || continue; t=$(cat \"$l\" 2>/dev/null); case \"$t\" in *Package*|*Tctl*|*Tdie*|*CPU*) i=\"${l%_label}_input\"; [ -r \"$i\" ] && echo \"$i\" && exit 0;; esac; done; for i in \"$d\"/temp*_input; do [ -r \"$i\" ] && echo \"$i\" && exit 0; done;; esac; done; for i in /sys/class/hwmon/hwmon*/temp*_input; do [ -r \"$i\" ] && echo \"$i\" && exit 0; done"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var path = data.trim()
                if (path && path.startsWith("/sys/class/hwmon/")) {
                    graphs.sensorPath = path
                    tempFile.reload()
                }
            }
        }
    }

    FileView {
        id: tempFile
        path: graphs.sensorPath
        watchChanges: false
        onLoaded: {
            var value = parseInt(tempFile.text().trim())
            if (!isNaN(value)) {
                graphs.tempC = Math.round(value / 1000)
                graphs.tempText = graphs.tempC + "°C"
            } else {
                graphs.tempC = 0
                graphs.tempText = "--°C"
            }
        }
    }

    Timer {
        interval: 5000
        running: graphs.visible && graphs.sensorPath !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: tempFile.reload()
    }

    Timer {
        interval: 1200
        running: true
        repeat: true
        onTriggered: {
            if (!statsProc.running) statsProc.running = true
        }
    }

    Timer {
        interval: 500
        running: graphs.cpuPercent >= 80 || graphs.tempC >= 80
        repeat: true
        onTriggered: {
            if (graphs.cpuPercent >= 80) graphs.cpuGlowOn = !graphs.cpuGlowOn
            if (graphs.tempC >= 80) graphs.tempGlowOn = !graphs.tempGlowOn
        }
        onRunningChanged: {
            if (!running) {
                graphs.cpuGlowOn = false
                graphs.tempGlowOn = false
            }
        }
    }

    Component.onCompleted: {
        statsProc.running = true
        sensorDetect.running = true
    }

    Row {
        anchors.fill: parent
        spacing: 8

        Item {
            width: graphs.metricWidth
            height: graphs.panelHeight

            Rectangle {
                id: cpuBar
                width: graphs.barWidth
                height: graphs.panelHeight
                radius: 0
                color: graphs.graphBackgroundColor
                border.color: "black"
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: 0
                    color: "#ff0000"
                    opacity: graphs.cpuPercent >= 80 && graphs.cpuGlowOn ? 0.55 : 0.0
                    visible: opacity > 0
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 20
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, Math.round((parent.width - 2) * graphs.cpuPercent / 100))
                    height: parent.height - 2
                    radius: 0
                    color: graphs.cpuGraphFillColor
                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
            }

            Item {
                anchors.left: cpuBar.right
                anchors.leftMargin: graphs.labelGap
                anchors.verticalCenter: cpuBar.verticalCenter
                width: graphs.labelWidth + graphs.labelRightMargin
                Row {
                    id: cpuLabelRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 0
                    spacing: 3

                    Text {
                        text: graphs.cpuIcon
                        color: graphs.graphTextColor
                        font.family: graphs.iconFontFamily
                        font.pixelSize: graphs.iconFontSize
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "CPU"
                        color: graphs.graphTextColor
                        font.pixelSize: graphs.labelFontSize
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                        visible: graphs.showLabelText
                    }

                    Text {
                        text: graphs.cpuPercent + "%"
                        color: graphs.graphTextColor
                        font.pixelSize: graphs.labelFontSize
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Item {
            width: graphs.metricWidth
            height: graphs.panelHeight

            Rectangle {
                id: ramBar
                width: graphs.barWidth
                height: graphs.panelHeight
                radius: 0
                color: graphs.graphBackgroundColor
                border.color: "black"
                border.width: 1

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, Math.round((parent.width - 2) * graphs.ramPercent / 100))
                    height: parent.height - 2
                    radius: 0
                    color: graphs.graphFillColor
                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
            }

            Item {
                anchors.left: ramBar.right
                anchors.leftMargin: graphs.labelGap
                anchors.verticalCenter: ramBar.verticalCenter
                width: graphs.labelWidth + graphs.labelRightMargin
                Row {
                    id: ramLabelRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 0
                    spacing: 3

                    Text {
                        text: graphs.ramIcon
                        color: graphs.graphTextColor
                        font.family: graphs.iconFontFamily
                        font.pixelSize: graphs.iconFontSize
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "RAM"
                        color: graphs.graphTextColor
                        font.pixelSize: graphs.labelFontSize
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                        visible: graphs.showLabelText
                    }

                    Text {
                        text: graphs.ramPercent + "%"
                        color: graphs.graphTextColor
                        font.pixelSize: graphs.labelFontSize
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Item {
            width: graphs.metricWidth
            height: graphs.panelHeight

            Rectangle {
                id: tempBar
                width: graphs.barWidth
                height: graphs.panelHeight
                radius: 0
                color: graphs.graphBackgroundColor
                border.color: "black"
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: 0
                    color: "#ff0000"
                    opacity: graphs.tempC >= 80 && graphs.tempGlowOn ? 0.55 : 0.0
                    visible: opacity > 0
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 20
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, Math.round((parent.width - 2) * graphs.tempPercent / 100))
                    height: parent.height - 2
                    radius: 0
                    color: graphs.tempGraphFillColor
                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
            }

            Item {
                anchors.left: tempBar.right
                anchors.leftMargin: graphs.labelGap
                anchors.verticalCenter: tempBar.verticalCenter
                width: graphs.labelWidth + graphs.labelRightMargin
                Row {
                    id: tempLabelRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 0
                    spacing: 3

                    Text {
                        text: graphs.tempIcon
                        color: graphs.graphTextColor
                        font.family: graphs.iconFontFamily
                        font.pixelSize: graphs.iconFontSize
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "TEMP"
                        color: graphs.graphTextColor
                        font.pixelSize: graphs.labelFontSize
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                        visible: graphs.showLabelText
                    }

                    Text {
                        text: graphs.tempText
                        color: graphs.graphTextColor
                        font.pixelSize: graphs.labelFontSize
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Item {
            width: graphs.metricWidth
            height: graphs.panelHeight

            Rectangle {
                id: volBar
                width: graphs.barWidth
                height: graphs.panelHeight
                radius: 0
                color: graphs.graphBackgroundColor
                border.color: "black"
                border.width: 1

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, Math.round((parent.width - 2) * graphs.volumePercent / 100))
                    height: parent.height - 2
                    radius: 0
                    color: graphs.graphFillColor
                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }
            }

            Item {
                anchors.left: volBar.right
                anchors.leftMargin: graphs.labelGap
                anchors.verticalCenter: volBar.verticalCenter
                width: graphs.labelWidth + graphs.labelRightMargin
                Row {
                    id: volLabelRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 0
                    spacing: 3

                    Text {
                        text: graphs.volumeIcon
                        color: graphs.graphTextColor
                        font.family: graphs.iconFontFamily
                        font.pixelSize: graphs.iconFontSize
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "VOL"
                        color: graphs.graphTextColor
                        font.pixelSize: graphs.labelFontSize
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                        visible: graphs.showLabelText
                    }

                    Text {
                        text: graphs.volumeText
                        color: graphs.graphTextColor
                        font.pixelSize: graphs.labelFontSize
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
