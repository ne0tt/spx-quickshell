// components/TrayMenu.qml
// Themed right-click context menu for system tray icons.
// Subclasses DropdownBase so it inherits the standard panel look.

import Quickshell
import QtQuick
import "../../base"

DropdownBase {
    id: _drop
    reloadableId: "trayMenu"

    panelWidth:  320
    // Height is bound dynamically to the column content
    panelFullHeight: Math.max(30, _menuColumn.implicitHeight + 16)
    implicitHeight: panelFullHeight + 44   // +16 ears +28 footer
    footerHeight: 28

    property var menuHandle: null

    function openAt(handle, x) {
        menuHandle = handle
        // Center the menu under the icon: icon center is x+12 (icon is 24px wide),
        // then subtract panelWidth/2 to center the panel, minus 16 for the wrapper gutter.
        panelX = Math.max(4, x + 12 - panelWidth / 2 - 16)
        // Delay one event loop tick so QsMenuOpener can populate children
        Qt.callLater(function() { openPanel() })
    }

    // Populates entries from the tray item's DBus menu handle
    QsMenuOpener {
        id: _opener
        menu: _drop.menuHandle
    }

    // ── Menu items ───────────────────────────────────────
    Column {
        id: _menuColumn
        x: 16   // clear the 16px left gutter of the wrapper
        y: 16   // clear the 16px ear zone
        width: _drop.panelWidth
        spacing: 2

        Repeater {
            model: _opener.children

            delegate: Column {
                id: _entryDelegate
                required property var modelData

                width: _drop.panelWidth
                spacing: 0

                property bool expanded: false

                QsMenuOpener {
                    id: _subOpener
                    menu: _entryDelegate.modelData
                }

                // Separator line
                Item {
                    visible: modelData.isSeparator
                    width: parent.width
                    height: 9

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        height: 1
                        color: colors.col_primary
                        opacity: 0.2
                    }
                }

                // Menu item row
                Rectangle {
                    visible: !modelData.isSeparator
                    width: parent.width
                    height: 30
                    radius: 4
                    color: _itemArea.containsMouse && (modelData.enabled || modelData.hasChildren)
                           ? Qt.rgba(colors.col_source_color.r, colors.col_source_color.g, colors.col_source_color.b, 0.15)
                           : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: _chevron.visible ? _chevron.left : parent.right
                        anchors.rightMargin: 8
                        text: modelData.text || ""
                        font.family: config.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        color: (!modelData.enabled && !modelData.hasChildren)
                               ? Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.35)
                               : _itemArea.containsMouse ? colors.col_source_color : colors.col_primary
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    Text {
                        id: _chevron
                        visible: modelData.hasChildren
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        text: _entryDelegate.expanded ? "▾" : "▸"
                        font.pixelSize: 10
                        color: _itemArea.containsMouse ? colors.col_source_color : colors.col_primary
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    MouseArea {
                        id: _itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: modelData.enabled || modelData.hasChildren
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.hasChildren) {
                                _entryDelegate.expanded = !_entryDelegate.expanded
                            } else {
                                modelData.triggered()
                                _drop.closePanel()
                            }
                        }
                    }
                }

                // Expandable sub-items
                Column {
                    visible: modelData.hasChildren && _entryDelegate.expanded
                    width: parent.width
                    spacing: 2
                    topPadding: 2

                    Repeater {
                        model: _subOpener.children

                        delegate: Item {
                            required property var modelData

                            width: parent.width
                            height: modelData.isSeparator ? 9 : 30

                            Rectangle {
                                visible: modelData.isSeparator
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 24
                                anchors.rightMargin: 4
                                height: 1
                                color: colors.col_primary
                                opacity: 0.2
                            }

                            Rectangle {
                                visible: !modelData.isSeparator
                                anchors.fill: parent
                                radius: 4
                                color: _subArea.containsMouse && modelData.enabled
                                       ? Qt.rgba(colors.col_source_color.r, colors.col_source_color.g, colors.col_source_color.b, 0.15)
                                       : "transparent"
                                Behavior on color { ColorAnimation { duration: 80 } }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 24
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    text: modelData.text || ""
                                    font.family: config.fontFamily
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    color: !modelData.enabled
                                           ? Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.35)
                                           : _subArea.containsMouse ? colors.col_source_color : colors.col_primary
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }

                                MouseArea {
                                    id: _subArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: modelData.enabled
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        modelData.triggered()
                                        _drop.closePanel()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
