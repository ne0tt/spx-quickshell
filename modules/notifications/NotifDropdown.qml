pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "../../base"

// ============================================================
// NOTIF DROPDOWN — notification history panel (DropdownBase).
//
// Shows all non-closed notifications from NotifService.list
// as SelectableCard items, matching the VlanDropdown style.
// ============================================================
DropdownBase {
    id: drop

    reloadableId: "notifDropdown"

    readonly property var _history: [...NotifService.list].filter(n => !n.closed)
    readonly property int _cardH: 48
    readonly property int _gapH:  8

    /// Set from shell.qml to systemUpdatesButton.systemUpdateCount
    property int systemUpdateCount: 0
    /// Emitted when the user clicks the update card
    signal upgradeRequested()

    // ── Deferred action after close animation starts ──────────────────────
    property var _pendingAction: null
    Timer {
        id: _actionTimer
        interval: 120   // enough for closePanel() to start rolling up
        repeat:   false
        onTriggered: {
            if (drop._pendingAction) {
                drop._pendingAction();
                drop._pendingAction = null;
            }
        }
    }
    function _closeAndRun(fn) {
        drop._pendingAction = fn;
        drop.closePanel();
        _actionTimer.start();
    }

    panelTitle:      "Notifications"
    panelTitleRight: _history.length > 0 ? _history.length + "" : ""
    panelIcon:       "󰂚"
    headerHeight:    34
    panelWidth:      390
    // Each card = 48px + 8px gap; top pad = 10; clearAll strip = 24+8 when shown
    panelFullHeight: {
        var n = _history.length + (systemUpdateCount > 0 ? 1 : 0);
        return n > 0 ? 44 + n * 56 : 80;
    }
    implicitHeight:  panelFullHeight + headerHeight + 52

    // ── Content column ────────────────────────────────────────────────────
    Column {
        x:       16 + 14
        y:       16 + drop.headerHeight + 10
        width:   drop.panelWidth - 28
        spacing: drop._gapH

        // ── "Clear All" link — only shown when there are notifications ────
        Item {
            visible: drop._history.length > 0
            width:   parent.width
            height:  24

            Text {
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
                text:           "Clear All"
                font.family:    config.fontFamily
                font.pixelSize: 11
                color:          clearMouse.containsMouse ? drop.accentColor : drop.dimColor
                Behavior on color { ColorAnimation { duration: 120 } }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    NotifService.clearAll()
                }
            }
        }

        // ── Yay update card — shown when updates are available ──────────────
        SelectableCard {
            visible:     drop.systemUpdateCount > 0
            width:       parent.width
            isActive:    true
            cardIcon:    "󰚰"
            label:       drop.systemUpdateCount + " update" + (drop.systemUpdateCount === 1 ? "" : "s") + " available"
            subtitle:    "Click to run yay -Syu"
            accentColor: drop.accentColor
            textColor:   drop.textColor
            dimColor:    drop.dimColor
            onClicked:   drop._closeAndRun(function() { drop.upgradeRequested() })
        }

        // ── Notification history items ────────────────────────────────────
        Repeater {
            model: ScriptModel { values: drop._history }

            delegate: Item {
                id: histRow
                required property var modelData
                width:  parent.width
                height: drop._cardH

                SelectableCard {
                    width:       parent.width
                    isActive:    false
                    cardIcon:    "󰂚"
                    label:       histRow.modelData.summary !== ""
                                     ? histRow.modelData.summary
                                     : histRow.modelData.appName
                    subtitle:    histRow.modelData.appName
                    accentColor: drop.accentColor
                    textColor:   drop.textColor
                    dimColor:    drop.dimColor
                    onClicked:   drop._closeAndRun(function() { histRow.modelData.close() })
                }
            }
        }

        // ── Empty state ───────────────────────────────────────────────────
        SelectableCard {
            visible:     drop._history.length === 0 && drop.systemUpdateCount === 0
            width:       parent.width
            isActive:    false
            cardIcon:    "󰂚"
            label:       "No notifications"
            subtitle:    ""
            accentColor: drop.accentColor
            textColor:   drop.textColor
            dimColor:    drop.dimColor
        }
    }
}
