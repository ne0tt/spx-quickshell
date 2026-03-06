// components/ChatShortcut.qml

import QtQuick

Item {
    id: root
    width: 30
    height: 24

    // ============================================================
    // PUBLIC PROPERTIES
    // ============================================================
    property string fontFamily: config.fontFamily
    property int fontSize: 16

    property color accentColor: "white"
    property color hoverColor: "#00ffaa"

    property bool enableGlow: true

    // URL to open (change if needed)
    property string targetUrl: "https://chatgpt.com/"

    // ============================================================
    // INTERNAL STATE
    // ============================================================
    property bool hovered: false

    // ============================================================
    // INTERACTION
    // ============================================================
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: root.hovered = true
        onExited: root.hovered = false

        onClicked: Qt.openUrlExternally(root.targetUrl)
    }

    // ============================================================
    // ICON
    // ============================================================
    Text {
        id: icon
        anchors.centerIn: parent
        text: ""   // your robot icon
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        color: root.hovered ? root.hoverColor : root.accentColor

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }
}
