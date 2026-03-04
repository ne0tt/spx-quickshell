import QtQuick
import Quickshell.Io

Item {
    id: root
    width: 40
    height: 24

    property string fontFamily: config.fontFamily
    property int    fontSize:   11
    property int    iconSize:   20
    property int    fontWeight: Font.Bold

    property bool   isActive:   false
    property color  accentColor: "white"
    property color  activeColor: "white"
    property color  hoverColor:  accentColor
    property color  dimColor:    Qt.rgba(1, 1, 1, 0.4)

    property bool   _hovered:   false

    signal clicked(real clickX)

    property string sensorPath: "/sys/class/hwmon/hwmon2/temp1_input"
    property string temperature: "--°C"

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
        running: true
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
            text: ""
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
}