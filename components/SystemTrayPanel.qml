// components/SystemTrayPanel.qml
// System tray using the StatusNotifierItem protocol (Solaar, Remmina, etc.)

import Quickshell
import Quickshell.Services.SystemTray

import QtQuick
import QtQuick.Controls

Item {
    id: root

    implicitWidth: trayRow.implicitWidth > 0 ? trayRow.implicitWidth : 0
    implicitHeight: 24
    visible: trayRow.visibleChildren.length > 0 || SystemTray.items.count > 0

    // ============================================================
    // TRAY ROW
    // ============================================================
    Row {
        id: trayRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: trayDelegate
                required property SystemTrayItem modelData

                width: 24
                height: 24

                // ------------------------------------------------
                // BACKGROUND (hover highlight)
                // ------------------------------------------------
                Rectangle {
                    id: bg
                    anchors.fill: parent
                    radius: 5
                    color: area.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }

                // ------------------------------------------------
                // TRAY ICON
                // ------------------------------------------------
                Image {
                    anchors.centerIn: parent
                    source: trayDelegate.modelData.icon
                    width: 18
                    height: 18
                    smooth: true
                    mipmap: true
                    fillMode: Image.PreserveAspectFit

                    // Tooltip
                    ToolTip.visible: area.containsMouse
                    ToolTip.delay: 600
                    ToolTip.text: trayDelegate.modelData.tooltip.title !== ""
                        ? trayDelegate.modelData.tooltip.title
                        : trayDelegate.modelData.title
                }

                // ------------------------------------------------
                // MOUSE INTERACTION
                // Left-click  → activate (show/hide app window)
                // Right-click → native app menu
                // ------------------------------------------------
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor

                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            trayDelegate.modelData.activate();
                        } else if (mouse.button === Qt.RightButton) {
                            if (trayDelegate.modelData.menu) {
                                // Map the icon's bottom-left corner to global screen coords
                                var gpos = trayDelegate.mapToGlobal(0, trayDelegate.height);
                                nativeMenuAnchor.anchor.rect.x = gpos.x;
                                nativeMenuAnchor.anchor.rect.y = gpos.y;
                                nativeMenuAnchor.anchor.rect.width  = trayDelegate.width;
                                nativeMenuAnchor.anchor.rect.height = 0;
                                nativeMenuAnchor.open();
                            } else {
                                // Fallback: ask the app to show its own context menu
                                trayDelegate.modelData.secondaryActivate();
                            }
                        }
                    }
                }

                // Native DBus menu (Remmina connections, Solaar devices, etc.)
                QsMenuAnchor {
                    id: nativeMenuAnchor
                    menu: trayDelegate.modelData.menu
                    anchor.edges: Edges.Bottom
                }
            }
        }
    }
}
