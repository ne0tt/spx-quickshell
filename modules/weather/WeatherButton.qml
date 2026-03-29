import QtQuick
import "../../state"
import "../.."

// ============================================================
// WEATHER BUTTON — bar pill showing icon + temperature.
// All data comes from AppState (shared with WeatherDropdown).
// ============================================================
Rectangle {
    id: root

    property string fontFamily:      config.fontFamily
    property int    fontSize:        config.fontSize
    property int    iconSize:        16
    property int    fontWeight:      config.fontWeight

    property bool   isActive:        false
    property color  accentColor:     Colors.col_primary
    property color  activeColor:     Colors.col_source_color
    property color  hoverColor:      Colors.col_source_color
    property color  dimColor:        Qt.rgba(1, 1, 1, 0.4)

    property color  backgroundColor: "transparent"
    property color  borderColor:     "transparent"

    // ── Shared state (AppState singleton) ──────────────────────

    signal clicked(real clickX)

    width:  60
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
            visible: WeatherState.wIcon !== "" && WeatherState.wIcon !== "…"
            text:    WeatherState.wIcon
            color:   root.isActive ? root.activeColor : btnArea.containsMouse ? root.hoverColor : root.accentColor
            font.family:    root.fontFamily
            font.styleName: "Solid"
            font.pixelSize: root.iconSize
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        Text {
            text: {
                if (WeatherState.wLoading) return "…"
                return WeatherState.wTemp !== "" ? WeatherState.wTemp : "…"
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
