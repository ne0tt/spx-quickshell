import QtQuick
import Quickshell.Io

Item {
    id: root
    width: 40
    height: 24

    property string fontFamily: config.fontFamily
    property int    fontSize:   11
    property int    iconSize:   16
    property int    fontWeight: Font.Normal

    property bool   isActive:   false
    property color  accentColor: "white"
    property color  activeColor: "white"
    property color  hoverColor:  accentColor
    property color  dimColor:    Qt.rgba(1, 1, 1, 0.4)

    property bool   _hovered:   false

    signal clicked(real clickX)

    // Resolved at startup by scanning /sys/class/hwmon for a CPU temp sensor.
    // Falls back to the first temp1_input found if no "coretemp"/"k10temp" label
    // is present, and to an empty string (panel hidden) if nothing is found.
    property string sensorPath: ""
    property string temperature: "--°C"

    // ============================================================
    // SENSOR AUTO-DETECT — find the right hwmon entry on startup.
    // Prefers coretemp (Intel) -> k10temp (AMD) -> first temp1_input.
    // ============================================================
    Process {
        id: _sensorDetect
        // Print "name:path" pairs so we can pick the best one.
        command: ["sh", "-c",
            "for d in /sys/class/hwmon/hwmon*; do " +
            "  name=$(cat \"$d/name\" 2>/dev/null); " +
            "  [ -f \"$d/temp1_input\" ] && echo \"$name:$d/temp1_input\"; " +
            "done"]
        stdout: SplitParser {
            // Collect candidates: prefer coretemp (Intel) or k10temp (AMD).
            property string _best:     ""
            property string _fallback: ""
            onRead: data => {
                var line = data.trim()
                if (line === "") return
                var sep  = line.indexOf(":")
                if (sep < 0) return
                var name = line.substring(0, sep)
                var path = line.substring(sep + 1)
                if (_best === "" && (name === "coretemp" || name === "k10temp"))
                    _best = path
                else if (_fallback === "")
                    _fallback = path
            }
        }
        onExited: {
            var best = _sensorDetect.stdout._best !== ""
                       ? _sensorDetect.stdout._best
                       : _sensorDetect.stdout._fallback
            root.sensorPath = best
            if (best !== "") tempFile.reload()
        }
    }

    // ============================================================
    // FILEVIEW — reads sysfs directly, no fork/exec overhead
    // ============================================================
    FileView {
        id: tempFile
        path: root.sensorPath
        // sysfs pseudo-files don't emit inotify events, so we poll manually
        watchChanges: false
        onLoaded: {
            let value = parseInt(tempFile.text().trim())
            root.temperature = !isNaN(value) ? Math.round(value / 1000) + "°C" : "--°C"
        }
    }

    // ============================================================
    // TIMER — reload every 5 s (temp changes slowly, 2 s was excessive)
    // ============================================================
    Timer {
        interval: 5000
        running: root.sensorPath !== ""
        repeat: true
        triggeredOnStart: false
        onTriggered: tempFile.reload()
    }

    // ============================================================
    // DISPLAY
    // ============================================================
    Row {
        anchors.centerIn: parent
        height: parent.height
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            color: root.isActive ? root.activeColor : root._hovered ? root.hoverColor : root.accentColor
            font.family: root.fontFamily
            font.styleName: "Solid"
            font.pixelSize: root.iconSize
            font.weight: root.fontWeight
            Behavior on color { ColorAnimation { duration: 160 } }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.temperature
            color: root.isActive ? root.activeColor : root._hovered ? root.hoverColor : root.accentColor
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            font.weight: root.fontWeight
            Behavior on color { ColorAnimation { duration: 160 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: root._hovered = true
        onExited:  root._hovered = false
        onClicked: {
            var pos = root.mapToItem(null, 0, 0)
            root.clicked(pos.x + root.width / 2)
        }
    }

    Component.onCompleted: _sensorDetect.running = true
}
