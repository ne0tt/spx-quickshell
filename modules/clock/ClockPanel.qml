import QtQuick
import Quickshell

Rectangle {
    id: clockPanel

    // ========================================================
    // CONFIGURABLE PROPERTIES
    // ========================================================
    property string fontFamily: config.fontFamily
    property int fontSize: 13
    property int fontWeight: config.fontWeight
    property bool fontBold: false
    property color textColor: "white"
    property color backgroundColor: colors.col_background
    property color borderColor: "black"

    signal clicked(real clickX, real clickY)

    width: 175
    height: 24
    radius: 7
    color: backgroundColor
    border.color: borderColor
    border.width: 1

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            var pos = clockPanel.mapToItem(null, 0, clockPanel.height);
            clockPanel.clicked(pos.x, pos.y);
        }
    }

    // ========================================================
    // CLOCK TEXT
    // ========================================================
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Text {
        id: clockText
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 0
        anchors.centerIn: parent
        color: textColor
        font.family: fontFamily
        font.pixelSize: fontSize
        font.weight: fontBold ? Font.Bold : fontWeight
        text: Qt.formatDateTime(clock.date, "dd/MM/yyyy   HH:mm:ss")
    }
}
