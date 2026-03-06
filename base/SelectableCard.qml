import QtQuick

// ============================================================
// SELECTABLE CARD — shared active-card widget used by
// VlanDropdown, VPNDropdown and PowerProfileDropdown.
//
// Props:
//   isActive         — highlight / selected state
//   isBusy           — disables click while a command is in-flight
//   cardIcon         — nerd-font / unicode glyph for the left circle
//   label            — primary text (bold, 13 px)
//   subtitle         — secondary text below label (10 px); hidden when ""
//   isPanelOpen      — drives the status-dot pulse animation
//   accentColor      — primary accent (from DropdownBase)
//   textColor        — primary text colour (from DropdownBase)
//   dimColor         — inactive / muted colour (from DropdownBase)
//   dotActiveColor   — dot colour when active (default: accentColor)
//
// Flash animation tuning (override per-instance if needed):
//   flashLoops       — default 3
//   flashOpacityLow  — default 0.25
//   flashDuration    — ms per step, default 120
//
// Signals:
//   clicked          — emitted when the (non-busy) card is clicked
//
// Methods:
//   flash()          — trigger the flash animation from outside
// ============================================================
Item {
    id: card
    width: parent ? parent.width : 0
    height: 48

    // ── Public API ────────────────────────────────────────────
    property bool   isActive:        false
    property bool   isBusy:          false
    property string cardIcon:        ""
    property string label:           ""
    property string subtitle:        ""
    property bool   isPanelOpen:     false
    property string fontFamily:      config.fontFamily

    property color  accentColor:     "white"
    property color  textColor:       "white"
    property color  dimColor:        "#888888"
    property color  dotActiveColor:  accentColor

    // Flash tuning
    property int    flashLoops:      3
    property real   flashOpacityLow: 0.25
    property int    flashDuration:   120

    signal clicked

    // Public: trigger the connect / activate flash
    function flash() { _flashAnim.start() }

    // ── Flash animation ───────────────────────────────────────
    SequentialAnimation {
        id: _flashAnim
        running: false
        loops: card.flashLoops
        PropertyAnimation { target: card; property: "opacity"; to: card.flashOpacityLow; duration: card.flashDuration }
        PropertyAnimation { target: card; property: "opacity"; to: 1.0;                 duration: card.flashDuration }
        onStopped: card.opacity = 1.0
    }

    // ── Card background ───────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: card.isActive
            ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.13)
            : Qt.rgba(0, 0, 0, 0.18)
        border.color: card.isActive
            ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.40)
            : Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        Behavior on color        { ColorAnimation { duration: 260 } }
        Behavior on border.color { ColorAnimation { duration: 260 } }

        // ── Left circle icon ──────────────────────────────────
        Rectangle {
            id: _iconCircle
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            width: 32; height: 32; radius: 16
            color: card.isActive
                ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.22)
                : Qt.rgba(1, 1, 1, 0.05)
            border.color: card.isActive
                ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.55)
                : Qt.rgba(1, 1, 1, 0.10)
            border.width: 1
            Behavior on color        { ColorAnimation { duration: 260 } }
            Behavior on border.color { ColorAnimation { duration: 260 } }

            Text {
                anchors.centerIn: parent
                text: card.cardIcon
                font.family: card.fontFamily
                font.pixelSize: 19
                color: card.isActive
                    ? card.accentColor
                    : Qt.rgba(card.dimColor.r, card.dimColor.g, card.dimColor.b, 0.40)
                Behavior on color { ColorAnimation { duration: 260 } }
            }
        }

        // ── Center: label + subtitle ──────────────────────────
        Column {
            anchors { left: _iconCircle.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 3

            Text {
                text: card.label
                font.pixelSize: 13
                font.bold: true
                color: card.isActive
                    ? card.textColor
                    : Qt.rgba(card.dimColor.r, card.dimColor.g, card.dimColor.b, 0.55)
                Behavior on color { ColorAnimation { duration: 260 } }
            }
            Text {
                visible: card.subtitle !== ""
                text:    card.subtitle
                font.pixelSize: 12
                color: card.isActive
                    ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.85)
                    : Qt.rgba(card.dimColor.r,    card.dimColor.g,    card.dimColor.b,    0.30)
                Behavior on color { ColorAnimation { duration: 260 } }
            }
        }

        // ── Right: status dot ─────────────────────────────────
        Rectangle {
            id: _dot
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            width: 8; height: 8; radius: 4
            color: card.isActive ? card.dotActiveColor : Qt.rgba(1, 1, 1, 0.10)
            Behavior on color { ColorAnimation { duration: 260 } }

            SequentialAnimation {
                running: card.isActive && card.isPanelOpen
                loops: Animation.Infinite
                NumberAnimation { target: _dot; property: "opacity"; to: 0.25; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { target: _dot; property: "opacity"; to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
                onStopped: _dot.opacity = 1.0
            }
        }

        // ── Click handler ─────────────────────────────────────
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            enabled: !card.isBusy
            onClicked: card.clicked()
        }
    }
}
