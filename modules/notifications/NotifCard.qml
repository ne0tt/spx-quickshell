pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "../../"

// ============================================================
// NOTIF CARD — visual representation of a single notification.
//
// Usage: instantiated by NotifPopups ListView delegate.
//
// Interactions:
//   • Fade in on appear; fade out on dismiss
//   • Hover → pause expire timer
//   • Drag X-axis past 40% card width → dismiss popup
//   • Middle-click → close notification entirely
//   • Close button (×) → close notification entirely
//   • Action buttons → invoke action and close
// ============================================================
Rectangle {
    id: root

    required property var modelData
    readonly property var notif: (modelData && typeof modelData === "object") ? modelData : null

    readonly property bool hasImage:   !!(notif && notif.image && notif.image.length > 0)
    readonly property bool hasAppIcon: !!(notif && notif.appIcon && notif.appIcon.length > 0)
    readonly property bool isCritical: !!(notif && notif.urgency === NotificationUrgency.Critical)
    readonly property string appName:  (notif && notif.appName) ? notif.appName : ""
    readonly property string summary:  (notif && notif.summary) ? notif.summary : ""
    readonly property string body:     (notif && notif.body) ? notif.body : ""
    readonly property var actions:     (notif && notif.actions) ? notif.actions : []

    function _timerStop() {
        if (notif && notif.timer) notif.timer.stop()
    }

    function _timerStart() {
        if (notif && notif.timer) notif.timer.start()
    }

    function _closeNotif() {
        if (notif && notif.close) notif.close()
    }

    // Dimensions
    readonly property int cardWidth:  360
    readonly property int padH:       14
    readonly property int padV:       12

    implicitWidth:  cardWidth
    implicitHeight: inner.implicitHeight + padV * 2
    clip:           true

    radius:       8
    color:        Colors.col_background
    border.color: isCritical ? Colors.col_error : Colors.col_source_color
    border.width: 2

    // ── Fade in on appear ────────────────────────────────────────────────
    opacity: 0
    Component.onCompleted: {
        fadeIn.start()
        if (notif && notif.lock) notif.lock(root)
    }
    Component.onDestruction: {
        if (notif && notif.unlock) notif.unlock(root)
    }

    NumberAnimation {
        id: fadeIn
        target: root
        property: "opacity"
        from: 0; to: 1
        duration: 220
        easing.type: Easing.OutCubic
    }

    // ── Drag-to-dismiss + hover handling ────────────────────────────────
    MouseArea {
        id: dragArea

        property real startX: 0

        anchors.fill:    parent
        hoverEnabled:    true
        preventStealing: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        drag.target: root
        drag.axis:   Drag.XAxis

        onEntered: root._timerStop()
        onExited:  { if (!pressed) root._timerStart() }

        onPressed: event => {
            if (event.button === Qt.MiddleButton) {
                root._closeNotif()
                return
            }
            root._timerStop()
            startX = event.x
        }

        onReleased: {
            if (!containsMouse)
                root._timerStart()

            // Spring back if not dragged far enough, otherwise dismiss.
            if (Math.abs(root.x) < root.cardWidth * 0.4)
                root.x = 0
            else
                if (root.notif) root.notif.popup = false
        }
    }

    // ── Card content ─────────────────────────────────────────────────────
    ColumnLayout {
        id: inner

        anchors {
            left:        parent.left
            right:       parent.right
            top:         parent.top
            leftMargin:  root.padH
            rightMargin: root.padH
            topMargin:   root.padV
        }

        spacing: 5

        // ── Header: icon + app name + close button ────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // App icon (shown when available)
            Rectangle {
                id: iconBg

                width:            22
                height:           22
                radius:           4
                color:            root.isCritical ? "#5c2020" : "#234442"
                visible:          root.hasAppIcon
                Layout.alignment: Qt.AlignVCenter

                Image {
                    anchors.fill:    parent
                    anchors.margins: 3
                    source:          root.hasAppIcon ? Quickshell.iconPath(root.notif.appIcon) : ""
                    fillMode:        Image.PreserveAspectFit
                    smooth:          true
                    visible:         root.hasAppIcon && status !== Image.Error
                }
            }

            // Fallback bell icon when no appIcon is set
            Text {
                text:             "󰂚"
                color:            root.isCritical ? "#ff8080" : "#80d5d4"
                font.family:      config.fontFamily
                font.pixelSize:   16
                visible:          !root.hasAppIcon
                Layout.alignment: Qt.AlignVCenter
            }

            // App name
            Text {
                text:              root.appName.length > 0
                                       ? root.appName
                                       : "Notification"
                color:             root.isCritical ? "#ff9090" : "#80d5d4"
                font.family:       config.fontFamily
                font.pixelSize:    14
                font.bold:         true
                elide:             Text.ElideRight
                Layout.fillWidth:  true
                Layout.alignment:  Qt.AlignVCenter
                verticalAlignment: Text.AlignVCenter
            }

            // Close button
            Text {
                text:             "󰅖"
                color:            closeMouseArea.containsMouse ? "#ffffff" : "#80d5d4"
                font.family:      config.fontFamily
                font.pixelSize:   14
                Layout.alignment: Qt.AlignVCenter

                Behavior on color {
                    ColorAnimation { duration: 100 }
                }

                MouseArea {
                    id: closeMouseArea
                    anchors.fill:    parent
                    anchors.margins: -6
                    hoverEnabled:    true
                    onClicked:       root._closeNotif()
                }
            }
        }

        // ── Summary ───────────────────────────────────────────────────────
        Text {
            text:                root.summary
            color:               "#e8f5f4"
            font.family:         config.fontFamily
            font.pixelSize:      13
            font.bold:           true
            wrapMode:            Text.WrapAtWordBoundaryOrAnywhere
            horizontalAlignment: Text.AlignLeft
            Layout.fillWidth:    true
            visible:             text.length > 0
            maximumLineCount:    3
            elide:               Text.ElideRight
        }

        // ── Body (full width, flush left) ─────────────────────────────────
        Text {
            text:                root.body
            color:               "#a8cccb"
            font.family:         config.fontFamily
            font.pixelSize:      12
            wrapMode:            Text.WrapAtWordBoundaryOrAnywhere
            horizontalAlignment: Text.AlignLeft
            Layout.fillWidth:    true
            visible:             text.length > 0
            // Limit to 4 lines to keep cards compact
            maximumLineCount:    4
            elide:               Text.ElideRight
        }

        // ── Action buttons ────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing:          6
            visible:          root.actions.length > 0

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    id: actionBtn

                    required property var modelData

                    radius:         6
                    color:          actionMouse.containsMouse ? "#2a5a58" : "#1f4442"
                    Layout.fillWidth: true
                    implicitWidth:  actionLabel.implicitWidth + 20
                    implicitHeight: 26

                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text:             actionBtn.modelData.text
                        color:            "#80d5d4"
                        font.family:      config.fontFamily
                        font.pixelSize:   11
                        width:            Math.max(0, actionBtn.width - 12)
                        elide:            Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (actionBtn.modelData && actionBtn.modelData.invoke)
                                actionBtn.modelData.invoke()
                            root._closeNotif()
                        }
                    }
                }
            }
        }
    }
}
