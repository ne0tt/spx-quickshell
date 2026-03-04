// components/VolumePanel.qml

import QtQuick

Item {
    id: root
    width: 50
    height: 24

    // ============================================================
    // PUBLIC PROPERTIES
    // ============================================================
    property string fontFamily: config.fontFamily
    property int    fontSize:   11
    property int    iconSize:   25
    property int    fontWeight: Font.Bold

    property bool   isActive:   false
    property color  accentColor: "white"
    property color  activeColor: "white"
    property color  hoverColor:  accentColor
    property color  dimColor:    Qt.rgba(1, 1, 1, 0.4)

    property bool   _hovered:   false

    signal clicked(real clickX)

    // ── Shared state (from VolumeState singleton) ─────────────
    property QtObject volumeData: null

    readonly property int  volume: volumeData ? volumeData.volume : 0
    readonly property bool muted:  volumeData ? volumeData.muted  : false

    // ============================================================
    // USER INTERACTION
    // ============================================================
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: root._hovered = true
        onExited:  root._hovered = false

        onClicked: {
            var pos = root.mapToItem(null, 0, 0)
            root.clicked(pos.x + root.width / 2)
        }

        onWheel: event => {
            if (!volumeData) return
            if (event.angleDelta.y > 0) volumeData.volumeUp()
            else                        volumeData.volumeDown()
        }
    }

// ============================================================
// DISPLAY
// ============================================================
Row {
    anchors.centerIn: parent
    spacing: 6
    height: parent.height

    Text {
        text: root.muted ? "󰝟" : ""
        font.family: root.fontFamily
        font.pixelSize: root.iconSize
        color: root.isActive ? root.activeColor : root._hovered ? root.hoverColor : root.accentColor
        anchors.verticalCenter: parent.verticalCenter
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    Text {
        text: root.muted ? "0%" : root.volume + "%"
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        font.weight: root.fontWeight
        color: root.isActive ? root.activeColor : root._hovered ? root.hoverColor : root.accentColor
        anchors.verticalCenter: parent.verticalCenter
        Behavior on color { ColorAnimation { duration: 160 } }
    }
}}