import Quickshell
import Quickshell.Services.UPower
import QtQuick

Rectangle {
    id: powerProfileButton

    property string fontFamily:      config.fontFamily
    property int    iconSize:        14
    property int    fontWeight:      config.fontWeight

    property bool   isActive:        false
    property color  accentColor:     colors.col_primary
    property color  activeColor:     colors.col_source_color
    property color  hoverColor:      colors.col_source_color
    property color  dimColor:        Qt.rgba(1, 1, 1, 0.4)

    property color  backgroundColor: "transparent"
    property color  borderColor:     "transparent"
    property bool   _hovered:        false
    property var icons: ({
        "power-saver": "󰌪",
        "balanced":    "",
        "performance":  ""
    })

    // Derived from the reactive PowerProfiles singleton — no polling needed
    readonly property string currentProfile: {
        switch (PowerProfiles.profile) {
            case PowerProfile.PowerSaver:  return "power-saver"
            case PowerProfile.Balanced:    return "balanced"
            case PowerProfile.Performance: return "performance"
            default:                       return ""
        }
    }
    width: 30
    height: 24
    radius: 7
    color: backgroundColor
    border.color: borderColor
    border.width: 1

    Text {
        id: iconText
        anchors.centerIn: parent
        color: powerProfileButton.isActive ? powerProfileButton.activeColor : powerProfileButton._hovered ? powerProfileButton.hoverColor : powerProfileButton.accentColor
        font.family: fontFamily
        font.pixelSize: iconSize
        font.weight: fontWeight
        text: icons[currentProfile] || "?"
        opacity: 1.0
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    signal clicked(real clickX)

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: powerProfileButton._hovered = true
        onExited:  powerProfileButton._hovered = false
        onClicked: {
            var pos = powerProfileButton.mapToItem(null, 0, 0)
            powerProfileButton.clicked(pos.x + powerProfileButton.width / 2)
        }
    }

}
