pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

// ============================================================
// NOTIF POPUPS — floating layer-shell window that renders
// the active notification popup stack.
//
// • Anchored top-right, no exclusive zone (overlay).
// • ListView backed by NotifService.popups.
// • Per-item remove animation: collapses height after the card
//   has already animated its x off-screen (see NotifCard).
// • Window hides itself when there are no popups.
//
// Usage in shell.qml (inside ShellRoot):
//   NotifPopups {
//       screen: root.screen
//   }
// ============================================================
PanelWindow {
    id: win

    // ── Layout constants ─────────────────────────────────────────────────
    readonly property int notifWidth:   360
    readonly property int sidePadding:  17
    readonly property int topOffset:    17   // clears the 70 px bar + 6 px gap
    readonly property int cardSpacing:  8

    // ── Wayland surface setup ────────────────────────────────────────────
    anchors.top:   true
    anchors.right: true
    exclusiveZone: 0
    color:         "transparent"

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    implicitWidth:  win.notifWidth + win.sidePadding * 2
    // Size to content; capped to screen height so the surface never overflows.
    // The window is top-anchored (y=0), so the full screen.height is available.
    implicitHeight: Math.max(1,
                        Math.min(
                            win.topOffset + notifList.contentHeight + win.sidePadding,
                            win.screen ? win.screen.height : 1080
                        ))

    // Only render/accept events when there is something to show.
    visible: NotifService.popups.length > 0

    // ── Notification list ────────────────────────────────────────────────
    ListView {
        id: notifList

        x:      win.sidePadding
        y:      win.topOffset
        width:  win.notifWidth
        height: win.implicitHeight - win.topOffset

        // Keep all delegates alive so contentHeight is always accurate.
        cacheBuffer:    100000
        spacing:        0
        clip:           true
        interactive:    false   // scroll is handled by drag on individual cards
        orientation:    ListView.Vertical

        model: ScriptModel {
            // Spread into a JS array — ScriptModel requires QVariantList,
            // but list<T> properties expose a QQmlListReference.
            values: [...NotifService.popups]
        }

        // ── Item remove animation ─────────────────────────────────────
        // NotifCard fades to opacity 0, then the wrapper collapses height
        // to pull remaining cards up smoothly.
        delegate: Item {
            id: wrapper

            required property var modelData
            required property int index

            // Track a stable index that won't flip to -1 during removal.
            property int stableIndex: index
            onIndexChanged: {
                if (index !== -1)
                    stableIndex = index;
            }

            implicitWidth:  notifCard.implicitWidth
            implicitHeight: notifCard.implicitHeight
                            + (stableIndex > 0 ? win.cardSpacing : 0)

            ListView.onRemove: removeAnim.start()

            SequentialAnimation {
                id: removeAnim

                // Lock the delegate in place until animation finishes.
                PropertyAction {
                    target: wrapper
                    property: "ListView.delayRemove"
                    value:    true
                }
                // Disable pointer events on the outgoing card.
                PropertyAction {
                    target: wrapper
                    property: "enabled"
                    value:    false
                }
                // Fade the card out.
                NumberAnimation {
                    target:   notifCard
                    property: "opacity"
                    to:       0
                    duration: 200
                    easing.type: Easing.InCubic
                }
                // Collapse the wrapper height to pull remaining cards up.
                NumberAnimation {
                    target:   wrapper
                    property: "implicitHeight"
                    to:       0
                    duration: 160
                    easing.type: Easing.InQuad
                }
                // Release the delegate so ListView can actually remove it.
                PropertyAction {
                    target: wrapper
                    property: "ListView.delayRemove"
                    value:    false
                }
            }

            NotifCard {
                id: notifCard

                y:         stableIndex > 0 ? win.cardSpacing : 0
                modelData: wrapper.modelData
            }
        }

    }
}
