import QtQuick
import Quickshell.Io
import "../.."

Item {
    id: root
    width: 40
    height: 24

    property string fontFamily: config.fontFamily
    property int    fontSize:   config.fontSize
    property int    iconSize:   16
    property int    fontWeight: config.fontWeight

    property bool   isActive:   false
    property color  accentColor: Colors.col_primary
    property color  activeColor: Colors.col_source_color
    property color  hoverColor:  Colors.col_source_color
    property color  dimColor:    Qt.rgba(1, 1, 1, 0.4)

    property bool   _hovered:   false

    signal clicked(real clickX)

    property string sensorPath: ""
    property string temperature: "--°C"
    property int    _tempValue:   0
    readonly property string _icon:
        _tempValue >= 80 ? "" :
        _tempValue >= 70 ? "" :
                           ""
    property bool   _flashOn:   false
    readonly property color _displayColor:
        (_tempValue >= 85 && _flashOn) ? "#ffffff" :
        isActive                       ? activeColor :
        _hovered                       ? hoverColor  :
                                         accentColor

    Timer {
        id: flashTimer
        interval: 500
        repeat:   true
        running:  root._tempValue >= 85
        onTriggered: root._flashOn = !root._flashOn
        onRunningChanged: if (!running) root._flashOn = false
    }
    // ============================================================
    // AUTO-DETECT SENSOR — find first available hwmon temp sensor
    // ============================================================
    Process {
        id: sensorDetect
        running: false
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do [ -d \"$d\" ] || continue; n=$(cat \"$d/name\" 2>/dev/null); case \"$n\" in coretemp|k10temp|zenpower|cpu_thermal|x86_pkg_temp) for l in \"$d\"/temp*_label; do [ -r \"$l\" ] || continue; t=$(cat \"$l\" 2>/dev/null); case \"$t\" in *Package*|*Tctl*|*Tdie*|*CPU*) i=\"${l%_label}_input\"; [ -r \"$i\" ] && echo \"$i\" && exit 0;; esac; done; for i in \"$d\"/temp*_input; do [ -r \"$i\" ] && echo \"$i\" && exit 0; done;; esac; done; for i in /sys/class/hwmon/hwmon*/temp*_input; do [ -r \"$i\" ] && echo \"$i\" && exit 0; done"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var path = data.trim()
                if (path && path.startsWith("/sys/class/hwmon/")) {
                    root.sensorPath = path
                    tempFile.reload()
                }
            }
        }
    }

    Component.onCompleted: {
        sensorDetect.running = true
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
            if (!isNaN(value)) {
                root._tempValue  = Math.round(value / 1000)
                root.temperature = root._tempValue + "°C"
            } else {
                root._tempValue  = 0
                root.temperature = "--°C"
            }
        }
    }

    // ============================================================
    // TIMER — reload every 5 s (temp changes slowly, 2 s was excessive)
    // ============================================================
    Timer {
        interval: 5000
        running: root.visible && root.sensorPath !== ""
        repeat: true
        triggeredOnStart: true
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
            text: root._icon
            color: root._displayColor
            font.family: root.fontFamily
            font.styleName: "Solid"
            font.pixelSize: root.iconSize
            font.weight: root.fontWeight
            Behavior on color { ColorAnimation { duration: 160 } }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.temperature
            color: root._displayColor
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
}