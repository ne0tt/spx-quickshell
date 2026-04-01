import QtQuick
import Quickshell.Io
import "../.."

Item {
    id: root
    width: 62
    height: 24

    property string fontFamily: config.fontFamily
    property int    fontSize: config.fontSize
    property int    iconSize: 15
    property int    fontWeight: config.fontWeight

    property bool   isActive: false
    property color  accentColor: Colors.col_primary
    property color  activeColor: Colors.col_source_color
    property color  hoverColor: Colors.col_source_color
    property color  dimColor: Qt.rgba(1, 1, 1, 0.4)
    property bool   _hovered: false

    property bool   isPresent: false
    property string devicePath: ""
    property int    percentage: 0
    property string percentageText: "--%"
    property string state: "unknown"
    property string timeToFull: "--"
    property string timeToEmpty: "--"
    property string energy: "--"
    property string energyFull: "--"
    property string technology: "--"

    readonly property string iconGlyph: {
        if (!isPresent) return ""
        if (state === "charging" || state === "pending-charge") return ""
        if (percentage >= 95) return ""
        if (percentage >= 70) return ""
        if (percentage >= 40) return ""
        if (percentage >= 15) return ""
        return ""
    }

    readonly property color displayColor:
        isActive ? activeColor :
        _hovered ? hoverColor :
        accentColor

    signal clicked(real clickX)

    function refreshBattery() {
        if (!batteryProc.running)
            batteryProc.running = true
    }

    function _applyLine(line) {
        var idx = line.indexOf("=")
        if (idx <= 0) return

        var key = line.substring(0, idx).trim()
        var value = line.substring(idx + 1).trim()

        if (key === "present") {
            root.isPresent = value === "yes"
        } else if (key === "path") {
            root.devicePath = value
        } else if (key === "state") {
            root.state = value
        } else if (key === "percentage") {
            root.percentageText = value
            var numeric = parseInt(value)
            if (!isNaN(numeric))
                root.percentage = numeric
        } else if (key === "time_to_full") {
            root.timeToFull = value
        } else if (key === "time_to_empty") {
            root.timeToEmpty = value
        } else if (key === "energy") {
            root.energy = value
        } else if (key === "energy_full") {
            root.energyFull = value
        } else if (key === "technology") {
            root.technology = value
        }
    }

    Timer {
        interval: 30000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshBattery()
    }

    Process {
        id: batteryProc
        running: false
        command: ["bash", "-c",
            "DEV=$(upower -e | grep -m1 -E 'battery|BAT'); " +
            "if [ -z \"$DEV\" ]; then " +
            "  echo 'present=no'; " +
            "  exit 0; " +
            "fi; " +
            "echo 'present=yes'; " +
            "echo \"path=$DEV\"; " +
            "upower -i \"$DEV\" | awk -F: '" +
            "/^[[:space:]]*state:/ {gsub(/^[ \\t]+/, \"\", $2); print \"state=\" $2} " +
            "/^[[:space:]]*percentage:/ {gsub(/^[ \\t]+/, \"\", $2); print \"percentage=\" $2} " +
            "/^[[:space:]]*time to full:/ {gsub(/^[ \\t]+/, \"\", $2); print \"time_to_full=\" $2} " +
            "/^[[:space:]]*time to empty:/ {gsub(/^[ \\t]+/, \"\", $2); print \"time_to_empty=\" $2} " +
            "/^[[:space:]]*energy:/ {gsub(/^[ \\t]+/, \"\", $2); print \"energy=\" $2} " +
            "/^[[:space:]]*energy-full:/ {gsub(/^[ \\t]+/, \"\", $2); print \"energy_full=\" $2} " +
            "/^[[:space:]]*technology:/ {gsub(/^[ \\t]+/, \"\", $2); print \"technology=\" $2}'"
        ]
        stdout: SplitParser {
            onRead: data => {
                var lines = data.split(/\r?\n/)
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line.length > 0)
                        root._applyLine(line)
                }
            }
        }
        onExited: {
            if (!root.isPresent) {
                root.devicePath = ""
                root.state = "unknown"
                root.percentage = 0
                root.percentageText = "--%"
                root.timeToFull = "--"
                root.timeToEmpty = "--"
                root.energy = "--"
                root.energyFull = "--"
                root.technology = "--"
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.isPresent ? root.iconGlyph : ""
            color: root.displayColor
            font.family: root.fontFamily
            font.pixelSize: root.iconSize
            font.weight: root.fontWeight
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        Text {
            text: root.isPresent ? root.percentageText : "AC"
            color: root.displayColor
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            font.weight: root.fontWeight
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 160 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: root._hovered = true
        onExited: root._hovered = false
        onClicked: {
            var pos = root.mapToItem(null, 0, 0)
            root.clicked(pos.x + root.width / 2)
        }
    }
}