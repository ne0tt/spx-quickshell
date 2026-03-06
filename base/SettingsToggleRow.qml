import QtQuick

// ============================================================
// SETTINGS TOGGLE ROW — icon circle + label/subtitle + pill switch.
// Mirrors the SelectableCard visual language but for binary on/off.
//
// Props:
//   cardIcon    — nerd-font glyph for the left circle
//   label       — primary text (bold, 13 px)
//   subtitle    — secondary text below label (10 px); hidden when ""
//   checked     — current on/off state
//   isBusy      — disables click while a command is in-flight
//   accentColor — active / highlight colour (from DropdownBase)
//   textColor   — primary text colour (from DropdownBase)
//   dimColor    — inactive / muted colour (from DropdownBase)
//
// Signals:
//   toggled(bool newState) — emitted on click with the next desired state
// ============================================================
Item {
    id: row

    width:  parent ? parent.width : 0
    height: 48

    property string cardIcon:   ""
    property string label:      ""
    property string subtitle:   ""
    property bool   checked:    false
    property bool   isBusy:     false

    property string fontFamily:  config.fontFamily
    property color  accentColor: "white"
    property color  textColor:   "white"
    property color  dimColor:    "#888888"

    signal toggled(bool newState)

    // ── Card background ───────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: row.checked
            ? Qt.rgba(row.accentColor.r, row.accentColor.g, row.accentColor.b, 0.10)
            : Qt.rgba(0, 0, 0, 0.18)
        border.color: row.checked
            ? Qt.rgba(row.accentColor.r, row.accentColor.g, row.accentColor.b, 0.36)
            : Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        Behavior on color        { ColorAnimation { duration: 260 } }
        Behavior on border.color { ColorAnimation { duration: 260 } }

        // ── Left icon circle ──────────────────────────────────
        Rectangle {
            id: _iconCircle
            anchors {
                left:           parent.left
                leftMargin:     12
                verticalCenter: parent.verticalCenter
            }
            width: 32; height: 32; radius: 16
            color: row.checked
                ? Qt.rgba(row.accentColor.r, row.accentColor.g, row.accentColor.b, 0.22)
                : Qt.rgba(1, 1, 1, 0.05)
            border.color: row.checked
                ? Qt.rgba(row.accentColor.r, row.accentColor.g, row.accentColor.b, 0.55)
                : Qt.rgba(1, 1, 1, 0.10)
            border.width: 1
            Behavior on color        { ColorAnimation { duration: 260 } }
            Behavior on border.color { ColorAnimation { duration: 260 } }

            Text {
                anchors.centerIn: parent
                text:           row.cardIcon
                font.family:    row.fontFamily
                font.styleName: "Solid"
                font.pixelSize: 15
                color: row.checked ? row.accentColor : row.dimColor
                Behavior on color { ColorAnimation { duration: 260 } }
            }
        }

        // ── Label and subtitle ────────────────────────────────
        Column {
            anchors {
                left:           _iconCircle.right
                leftMargin:     10
                right:          _pill.left
                rightMargin:    10
                verticalCenter: parent.verticalCenter
            }
            spacing: 2

            Text {
                text:           row.label
                font.family:    row.fontFamily
                font.pixelSize: 13
                font.weight:    Font.DemiBold
                color:          row.textColor
                elide:          Text.ElideRight
                width:          parent.width
            }

            Text {
                visible:        row.subtitle !== ""
                text:           row.subtitle
                font.family:    row.fontFamily
                font.pixelSize: 10
                color:          row.dimColor
                elide:          Text.ElideRight
                width:          parent.width
            }
        }

        // ── Toggle pill ───────────────────────────────────────
        Rectangle {
            id: _pill
            anchors {
                right:          parent.right
                rightMargin:    12
                verticalCenter: parent.verticalCenter
            }
            width: 38; height: 20; radius: 10
            color: row.checked
                ? Qt.rgba(row.accentColor.r, row.accentColor.g, row.accentColor.b, 0.82)
                : Qt.rgba(1, 1, 1, 0.15)
            Behavior on color { ColorAnimation { duration: 200 } }

            Rectangle {
                id: _knob
                width: 14; height: 14; radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: row.checked ? parent.width - width - 3 : 3
                color: row.checked ? "white" : Qt.rgba(1, 1, 1, 0.55)
                Behavior on x     { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation  { duration: 180 } }
            }
        }

        // ── Hit area ──────────────────────────────────────────
        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            enabled:      !row.isBusy
            onClicked:    row.toggled(!row.checked)
        }
    }
}
