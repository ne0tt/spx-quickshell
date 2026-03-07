import Quickshell
import Quickshell.Io
import QtQuick

Rectangle {
    id: yayUpdatePanel
    property color backgroundColor: colors.col_background
    property color borderColor: "black"
    property string fontFamily: config.fontFamily
    property int    fontSize:   13
    property int    iconSize:   15
    property int    fontWeight: config.fontWeight

    property bool   isActive:   false
    property color  accentColor: colors.col_source_color
    property color  activeColor: colors.col_source_color
    property color  hoverColor:  colors.col_source_color
    property color  dimColor:    Qt.rgba(1, 1, 1, 0.4)

    property bool   _hovered:   false

    signal clicked(real clickX)

    property int updateInterval: 900000 // ms (15 minutes)
    property int yayUpdateCount: 0
    property bool yayUpdateAvailable: false

    width: 55
    height: 24
    radius: 7
    color: backgroundColor
    border.color: borderColor
    border.width: 1
    visible: yayUpdateAvailable

    Row {
        anchors.centerIn: parent
        spacing: 4
        height: parent.height

        Text {
            id: updateIcon
            anchors.verticalCenter: parent.verticalCenter
            text: " "
            color: yayUpdatePanel.isActive ? yayUpdatePanel.activeColor : yayUpdatePanel._hovered ? yayUpdatePanel.hoverColor : yayUpdatePanel.accentColor
            font.family: yayUpdatePanel.fontFamily
            font.styleName: "Solid"
            font.pixelSize: yayUpdatePanel.iconSize
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        Text {
            id: updateText
            anchors.verticalCenter: parent.verticalCenter
            color: yayUpdatePanel.isActive ? yayUpdatePanel.activeColor : yayUpdatePanel._hovered ? yayUpdatePanel.hoverColor : yayUpdatePanel.accentColor
            font.family: yayUpdatePanel.fontFamily
            font.pixelSize: yayUpdatePanel.fontSize
            font.weight: yayUpdatePanel.fontWeight
            text: yayUpdatePanel.yayUpdateCount
            opacity: 1.0
            Behavior on color { ColorAnimation { duration: 160 } }
        }
    }

    // Only pulse when updates are actually available — stops the
    // animation (and its render-tree invalidations) at zero updates.
    SequentialAnimation {
        id: updatePulseAnim
        running: yayUpdatePanel.yayUpdateAvailable
        loops: 10
        ParallelAnimation {
            ColorAnimation { target: updateIcon; property: "color"; to: "white"; duration: 600 }
            ColorAnimation { target: updateText; property: "color"; to: "white"; duration: 600 }
        }
        ParallelAnimation {
            ColorAnimation { target: updateIcon; property: "color"; to: yayUpdatePanel.accentColor; duration: 600 }
            ColorAnimation { target: updateText; property: "color"; to: yayUpdatePanel.accentColor; duration: 600 }
        }
        onStopped: {
            updateIcon.color = Qt.binding(() => yayUpdatePanel.accentColor)
            updateText.color = Qt.binding(() => yayUpdatePanel.accentColor)
        }
    }

    Process {
        id: yayUpdateProc
        command: ["sh", "-c", "{ checkupdates 2>/dev/null; yay -Qua 2>/dev/null; } | wc -l"]
        stdout: SplitParser {
            onRead: data => {
                var count = parseInt(data.trim());
                yayUpdatePanel.yayUpdateCount = isNaN(count) ? 0 : count;
                yayUpdatePanel.yayUpdateAvailable = yayUpdatePanel.yayUpdateCount > 0;
            }
        }
    }
    Timer {
        interval: updateInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: yayUpdateProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: yayUpdatePanel._hovered = true
        onExited:  yayUpdatePanel._hovered = false
        onClicked: {
            runUpgrade.running = true
            var pos = yayUpdatePanel.mapToItem(null, 0, 0)
            yayUpdatePanel.clicked(pos.x + yayUpdatePanel.width / 2)
        }
    }

    // Opens a terminal, runs yay -Syu, then re-checks the count
    Process {
        id: runUpgrade
        command: ["kitty", "--hold", "sh", "-c", "yay -Syu"]
        onRunningChanged: if (!running) yayUpdateProc.running = true
    }
}
