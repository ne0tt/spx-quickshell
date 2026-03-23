pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// ============================================================
// NOTIF SERVICE — D-Bus notification server + list management.
//
// Singleton accessible as `NotifService` from any file in the
// qs.modules.notifications module, or via import elsewhere.
//
// Key API:
//   NotifService.popups   — active popup notifications (filtered list)
//   NotifService.list     — all tracked notifications
//   NotifService.dnd      — Do Not Disturb toggle
//   NotifService.clearAll() — dismiss all
// ============================================================
Singleton {
    id: root

    /// All tracked notifications (including those no longer shown as popups).
    property var list: []

    /// Notifications currently showing as popups (popup=true && !closed).
    /// Used as the model for NotifPopups.
    readonly property var popups: list.filter(n => n.popup && !n.closed)

    /// Do Not Disturb — when true, new notifications don't show as popups.
    property bool dnd: false

    /// Dismiss and remove all notifications.
    function clearAll(): void {
        for (const n of root.list.slice())
            n.close();
    }

    // ── D-Bus notification server ────────────────────────────────────────
    NotificationServer {
        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;
            const item = notifComp.createObject(root, {
                popup: !root.dnd,
                notification: notif
            });
            root.list = [item, ...root.list];
        }
    }

    // ── Notif — wrapper around a single notification ─────────────────────
    component Notif: QtObject {
        id: notif

        /// Whether this notification is currently shown as a popup.
        property bool popup: true

        /// Whether close() has been called. The object stays alive until
        /// all visual locks are released (i.e. animations complete).
        property bool closed: false

        /// Set of visual items that have locked this Notif alive during
        /// their close animation. Use lock(item)/unlock(item).
        property var locks: new Set()

        // Raw notification object from the server. Null for history-only entries.
        property Notification notification: null

        // Notification data — copied from the server object so we can
        // outlive the server's in-memory lifetime.
        property string id: ""
        property string summary: ""
        property string body: ""
        property string appIcon: ""
        property string appName: ""
        property string image: ""
        property real expireTimeout: 5000
        property int urgency: NotificationUrgency.Normal
        property bool resident: false
        property list<var> actions: []

        // Auto-dismiss timer. Stopped while visual item is hovered.
        readonly property Timer timer: Timer {
            running: notif.popup && !notif.closed
            interval: notif.expireTimeout > 0 ? notif.expireTimeout : 5000
            onTriggered: notif.popup = false
        }

        // Mirror property changes pushed by the server (e.g. app updates body).
        readonly property Connections conn: Connections {
            target: notif.notification

            function onClosed(): void {
                notif.close();
            }

            function onSummaryChanged(): void {
                notif.summary = notif.notification.summary;
            }

            function onBodyChanged(): void {
                notif.body = notif.notification.body;
            }

            function onAppIconChanged(): void {
                notif.appIcon = notif.notification.appIcon;
            }

            function onAppNameChanged(): void {
                notif.appName = notif.notification.appName;
            }

            function onExpireTimeoutChanged(): void {
                notif.expireTimeout = notif.notification.expireTimeout;
            }

            function onUrgencyChanged(): void {
                notif.urgency = notif.notification.urgency;
            }

            function onResidentChanged(): void {
                notif.resident = notif.notification.resident;
            }

            function onActionsChanged(): void {
                notif.actions = notif.notification.actions.map(a => ({
                    identifier: a.identifier,
                    text: a.text,
                    invoke: () => a.invoke()
                }));
            }
        }

        /// Call from visual item's Component.onCompleted to keep this Notif alive
        /// while a close animation is running.
        function lock(item: Item): void {
            locks.add(item);
        }

        /// Call from visual item's Component.onDestruction (or after animation ends).
        /// If closed was called while locked, this finalises the destruction.
        function unlock(item: Item): void {
            locks.delete(item);
            if (closed)
                close();
        }

        /// Mark as closed. If no visual locks remain, immediately removes from
        /// the list and destroys this object. Otherwise, destruction is deferred
        /// until all locks are released via unlock().
        function close(): void {
            closed = true;
            if (locks.size === 0 && root.list.includes(this)) {
                root.list = root.list.filter(n => n !== this);
                notification?.dismiss();
                destroy();
            }
        }

        Component.onCompleted: {
            if (!notification)
                return;

            id = notification.id;
            summary = notification.summary;
            body = notification.body;
            appIcon = notification.appIcon;
            appName = notification.appName;
            image = notification.image;
            expireTimeout = notification.expireTimeout > 0 ? notification.expireTimeout : 5000;
            urgency = notification.urgency;
            resident = notification.resident;
            actions = notification.actions.map(a => ({
                identifier: a.identifier,
                text: a.text,
                invoke: () => a.invoke()
            }));
        }
    }

    Component {
        id: notifComp
        Notif {}
    }
}
