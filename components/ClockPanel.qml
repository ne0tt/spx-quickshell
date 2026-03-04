import QtQuick

Rectangle {
    id: clockPanel

    // ========================================================
    // CONFIGURABLE PROPERTIES
    // ========================================================
    property string fontFamily: config.fontFamily
    property int fontSize: 1
    property bool fontBold: false
    property color textColor: "white"
    property color backgroundColor: "#2c2c2c"
    property color borderColor: "black"

    signal clicked(real clickX, real clickY)

    width: 200
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
    property var currentDate: new Date()

    Text {
        id: clockText
        anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 1
        anchors.centerIn: parent
        color: textColor
        font.family: fontFamily
        font.pixelSize: fontSize
        font.bold: fontBold
        text: Qt.formatDateTime(clockPanel.currentDate, "  dd/MM/yyyy   HH:mm:ss")

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clockPanel.currentDate = new Date()
        }
    }
}
