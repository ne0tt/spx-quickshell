import QtQuick

// ============================================================
// WEATHER PANEL — bar pill showing icon + temperature.
// All data comes from WeatherState (shared with WeatherDropdown).
// ============================================================
Rectangle {
    id: root

    property string fontFamily:      config.fontFamily
    property int    fontSize:        11
    property int    iconSize:        21
    property int    fontWeight:      Font.Bold

    property bool   isActive:        false
    property color  accentColor:     "white"
    property color  activeColor:     "white"
    property color  hoverColor:      accentColor
    property color  dimColor:        Qt.rgba(1, 1, 1, 0.4)

    property color  backgroundColor: "transparent"
    property color  borderColor:     "transparent"

    // Injected from shell.qml — the shared WeatherState instance
    property QtObject weatherData: null

    signal clicked(real clickX)

    width:  40
    height: 24
    radius: 7
    color:  backgroundColor
    border.color: borderColor
    border.width: 1

    Row {
        id: contentRow
        anchors.centerIn: parent
        height: parent.height
        spacing: 5

        Text {
            visible: weatherData && weatherData.wIcon !== "" && weatherData.wIcon !== "…"
            text:    weatherData ? weatherData.wIcon : ""
            color:   root.isActive ? root.activeColor : btnArea.containsMouse ? root.hoverColor : root.accentColor
            font.family:    root.fontFamily
            font.styleName: "Solid"
            font.pixelSize: root.iconSize
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        Text {
            text: {
                if (!weatherData || weatherData.wLoading) return "…"
                return weatherData.wTemp !== "" ? weatherData.wTemp : "…"
            }
            color: root.isActive ? root.activeColor : btnArea.containsMouse ? root.hoverColor : root.accentColor
            font.family:    root.fontFamily
            font.pixelSize: root.fontSize
            font.weight:    root.fontWeight
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 160 } }
        }
    }

    MouseArea {
        id: btnArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            var pos = root.mapToItem(null, 0, 0)
            root.clicked(pos.x + root.width / 2)
        }
    }
}
