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

    readonly property bool hasImage:   modelData.image.length > 0
    readonly property bool hasAppIcon: modelData.appIcon.length > 0
    readonly property bool isCritical: modelData.urgency === NotificationUrgency.Critical

    // Dimensions
    readonly property int cardWidth:  360
    readonly property int padH:       14
    readonly property int padV:       12

    implicitWidth:  cardWidth
    implicitHeight: inner.implicitHeight + padV * 2

    radius:       10
    color:        isCritical ? "#2d1a1a" : "#1b3534"
    border.color: isCritical ? "#7a2020" : themeColors.col_source_color
    border.width: 2

    Colors { id: themeColors }

    // ── Fade in on appear ────────────────────────────────────────────────
    opacity: 0
    Component.onCompleted: {
        fadeIn.start();
        modelData.lock(root);
    }
    Component.onDestruction: modelData.unlock(root)

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

        onEntered: root.modelData.timer.stop()
        onExited:  { if (!pressed) root.modelData.timer.start(); }

        onPressed: event => {
            if (event.button === Qt.MiddleButton) {
                root.modelData.close();
                return;
            }
            root.modelData.timer.stop();
            startX = event.x;
        }

        onReleased: {
            if (!containsMouse)
                root.modelData.timer.start();

            // Spring back if not dragged far enough, otherwise dismiss.
            if (Math.abs(root.x) < root.cardWidth * 0.4)
                root.x = 0;
            else
                root.modelData.popup = false;
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

            // App icon
            Rectangle {
                id: iconBg

                width:   22
                height:  22
                radius:  5
                color:   root.isCritical ? "#5c2020" : "#234442"
                visible: root.hasAppIcon

                Image {
                    anchors.fill:    parent
                    anchors.margins: 3
                    source:          root.hasAppIcon ? Quickshell.iconPath(root.modelData.appIcon) : ""
                    fillMode:        Image.PreserveAspectFit
                    smooth:          true
                    visible:         root.hasAppIcon && status !== Image.Error
                }
            }

            // Fallback icon when no appIcon is set
            Text {
                text:                 "󰂚"
                color:                root.isCritical ? "#ff8080" : "#80d5d4"
                font.family:          "Hack Nerd Font"
                font.pixelSize:       16
                visible:              !root.hasAppIcon
                Layout.alignment:     Qt.AlignVCenter
            }

            // App name
            Text {
                text:              root.modelData.appName.length > 0
                                       ? root.modelData.appName
                                       : "Notification"
                color:             root.isCritical ? "#ff9090" : "#80d5d4"
                font.family:       "Hack Nerd Font"
                font.pixelSize:    11
                elide:             Text.ElideRight
                Layout.fillWidth:  true
                Layout.alignment:  Qt.AlignVCenter
                verticalAlignment: Text.AlignVCenter
            }

            // Close button
            Text {
                text:             "󰅖"
                color:            closeMouseArea.containsMouse ? "#ffffff" : "#80d5d4"
                font.family:      "Hack Nerd Font"
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
                    onClicked:       root.modelData.close()
                }
            }
        }

        // ── Summary ──────────────────────────────────────────────────────
        Text {
            text:              root.modelData.summary
            color:             "#e8f5f4"
            font.family:       "Hack Nerd Font"
            font.pixelSize:    13
            font.bold:         true
            wrapMode:          Text.WordWrap
            Layout.fillWidth:  true
            visible:           text.length > 0
        }

        // ── Body ─────────────────────────────────────────────────────────
        Text {
            text:              root.modelData.body
            color:             "#a8cccb"
            font.family:       "Hack Nerd Font"
            font.pixelSize:    12
            wrapMode:          Text.WordWrap
            Layout.fillWidth:  true
            visible:           text.length > 0
            // Limit to 4 lines to keep cards compact
            maximumLineCount:  4
            elide:             Text.ElideRight
        }

        // ── App image (if present) ────────────────────────────────────────
        Image {
            source:               root.hasImage ? Qt.resolvedUrl(root.modelData.image) : ""
            fillMode:             Image.PreserveAspectFit
            Layout.fillWidth:     true
            Layout.maximumHeight: 120
            visible:              root.hasImage
            smooth:               true
            clip:                 true
        }

        // ── Action buttons ────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing:          6
            visible:          root.modelData.actions.length > 0

            Repeater {
                model: root.modelData.actions

                delegate: Rectangle {
                    id: actionBtn

                    required property var modelData

                    radius:         6
                    color:          actionMouse.containsMouse ? "#2a5a58" : "#1f4442"
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
                        font.family:      "Hack Nerd Font"
                        font.pixelSize:   11
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            actionBtn.modelData.invoke();
                            root.modelData.close();
                        }
                    }
                }
            }
        }
    }
}
