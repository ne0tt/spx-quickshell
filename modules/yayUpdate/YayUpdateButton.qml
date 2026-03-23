import Quickshell
import Quickshell.Io
import QtQuick

Rectangle {
    id: yayUpdateButton
    property color backgroundColor: colors.col_background
    property color borderColor: "black"
    property string fontFamily: config.fontFamily
    property int    fontSize:   13
    property int    iconSize:   15
    property int    fontWeight: config.fontWeight

    property bool   isActive:   false
    property color  accentColor: colors.col_source_color
    property color  activeColor: colors.col_source_color
    property color  hoverColor:  colors.col_source_color
    property color  dimColor:    Qt.rgba(1, 1, 1, 0.4)

    property bool   _hovered:   false

    signal clicked(real clickX)

    property int yayUpdateCount: 0
    property bool yayUpdateAvailable: false
    // -1 so the very first check notifies if updates are found
    property int _prevCount: -1

    // Public method to trigger update from external components (e.g., GlobalShortcut)
    function triggerUpdate() {
        if (yayUpdateAvailable) {
            runUpgrade.running = true
            var pos = mapToItem(null, 0, 0)
            clicked(pos.x + width / 2)
        }
    }

    width: 55
    height: 24
    radius: 7
    color: backgroundColor
    border.color: borderColor
    border.width: 1
    visible: yayUpdateAvailable

    Row {
        anchors.centerIn: parent
        spacing: 4
        height: parent.height

        Text {
            id: updateIcon
            anchors.verticalCenter: parent.verticalCenter
            text: " "
            color: yayUpdateButton.isActive ? yayUpdateButton.activeColor : yayUpdateButton._hovered ? yayUpdateButton.hoverColor : yayUpdateButton.accentColor
            font.family: yayUpdateButton.fontFamily
            font.styleName: "Solid"
            font.pixelSize: yayUpdateButton.iconSize
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        Text {
            id: updateText
            anchors.verticalCenter: parent.verticalCenter
            color: yayUpdateButton.isActive ? yayUpdateButton.activeColor : yayUpdateButton._hovered ? yayUpdateButton.hoverColor : yayUpdateButton.accentColor
            font.family: yayUpdateButton.fontFamily
            font.pixelSize: yayUpdateButton.fontSize
            font.weight: yayUpdateButton.fontWeight
            text: yayUpdateButton.yayUpdateCount
            opacity: 1.0
            Behavior on color { ColorAnimation { duration: 160 } }
        }
    }

    // Only pulse when updates are actually available — stops the
    // animation (and its render-tree invalidations) at zero updates.
    SequentialAnimation {
        id: updatePulseAnim
        running: yayUpdateButton.yayUpdateAvailable
        loops: 10
        ParallelAnimation {
            ColorAnimation { target: updateIcon; property: "color"; to: "white"; duration: 600 }
            ColorAnimation { target: updateText; property: "color"; to: "white"; duration: 600 }
        }
        ParallelAnimation {
            ColorAnimation { target: updateIcon; property: "color"; to: yayUpdateButton.accentColor; duration: 600 }
            ColorAnimation { target: updateText; property: "color"; to: yayUpdateButton.accentColor; duration: 600 }
        }
        onStopped: {
            updateIcon.color = Qt.binding(() => yayUpdateButton.accentColor)
            updateText.color = Qt.binding(() => yayUpdateButton.accentColor)
        }
    }

    Process {
        id: yayUpdateProc
        command: ["sh", "-c", "{ checkupdates 2>/dev/null; yay -Qua 2>/dev/null; } | wc -l"]
        stdout: SplitParser {
            onRead: data => {
                var count = parseInt(data.trim());
                count = isNaN(count) ? 0 : count;
                yayUpdateButton.yayUpdateCount     = count;
                yayUpdateButton.yayUpdateAvailable = count > 0;
                if (count > 0 && count !== yayUpdateButton._prevCount)
                    notifProc.running = true;
                yayUpdateButton._prevCount = count;
            }
        }
    }

    Process {
        id: notifProc
        running: false
        command: [
            "notify-send",
            "--app-name", "yay",
            "--icon", "system-software-update",
            "System updates available",
            yayUpdateButton.yayUpdateCount + " package" + (yayUpdateButton.yayUpdateCount === 1 ? "" : "s") + " ready to update"
        ]
    }
    // Fire once at startup, then re-check at each hour boundary (aligns with
    // SystemClock.Hours so the process is spawned at most ~25 times/day instead
    // of the previous unconditional 96 times/day with a 15-minute Timer).
    Component.onCompleted: yayUpdateProc.running = true

    SystemClock {
        precision: SystemClock.Hours
        onHoursChanged: yayUpdateProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: yayUpdateButton._hovered = true
        onExited:  yayUpdateButton._hovered = false
        onClicked: {
            runUpgrade.running = true
            var pos = yayUpdateButton.mapToItem(null, 0, 0)
            yayUpdateButton.clicked(pos.x + yayUpdateButton.width / 2)
        }
    }

    // Opens a terminal, runs yay -Syu, then re-checks the count
    Process {
        id: runUpgrade
        command: ["kitty", "--config", Quickshell.env("HOME") + "/dotfiles/.config/kitty/kitty-qs-yay.conf", "--title", "qs-kitty-yay", "--hold", "sh", "-c", "yay -Syu"]
        onRunningChanged: if (!running) yayUpdateProc.running = true
    }
    
    // Hyprland window rule for floating terminal:
    // windowrule {
    //     name = qs-kitty-yay
    //     match:initial_title = ^(qs-kitty-yay)$
    //     float = true
    //     size = 800 600
    //     center = true
    // }
}
