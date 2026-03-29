import Quickshell
import Quickshell.Io
import QtQuick

Rectangle {
    id: systemUpdatesButton

    // ── Toggle: true = word form ("Three updates available")
    //           false = numeric ("3 updates available")
    property bool   numberToText:   true

    property color backgroundColor: colors.col_background
    property color borderColor: "black"
    property string fontFamily: config.fontFamily
    property int    fontSize:   13
    property int    iconSize:   14
    property int    fontWeight: config.fontWeight

    property bool   isActive:   false
    property color  accentColor: colors.col_source_color
    property color  activeColor: colors.col_source_color
    property color  hoverColor:  colors.col_source_color
    property color  dimColor:    Qt.rgba(1, 1, 1, 0.4)

    property bool   _hovered:   false

    signal clicked(real clickX)

    property int systemUpdateCount: 0
    property bool systemUpdateAvailable: false
    // -1 so the very first check notifies if updates are found
    property int _prevCount: -1

    // Public method to trigger update from external components (e.g., GlobalShortcut)
    function triggerUpdate() {
        if (systemUpdateAvailable) {
            runUpgrade.running = true
            var pos = mapToItem(null, 0, 0)
            clicked(pos.x + width / 2)
        }
    }

    // Re-check available updates without launching a terminal (e.g., after upgrade from another panel)
    function recheckUpdates() {
        systemUpdateProc.running = true
    }

    // Width expands to fit the word representation of the count
    width: innerRow.implicitWidth + 14
    height: 24
    radius: 7
    color: backgroundColor
    border.color: borderColor
    border.width: 1
    visible: systemUpdateAvailable

    Row {
        id: innerRow
        anchors.centerIn: parent
        spacing: 4
        height: parent.height

        Text {
            id: updateIcon
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            text: " "
            color: systemUpdatesButton.isActive ? systemUpdatesButton.activeColor : systemUpdatesButton._hovered ? systemUpdatesButton.hoverColor : systemUpdatesButton.accentColor
            font.family: systemUpdatesButton.fontFamily
            font.styleName: "Solid"
            font.pixelSize: systemUpdatesButton.iconSize
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        Text {
            id: updateText
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            color: systemUpdatesButton.isActive ? systemUpdatesButton.activeColor : systemUpdatesButton._hovered ? systemUpdatesButton.hoverColor : systemUpdatesButton.accentColor
            font.family: systemUpdatesButton.fontFamily
            font.pixelSize: systemUpdatesButton.fontSize
            font.weight: systemUpdatesButton.fontWeight
            text: systemUpdatesButton.numberToText
                    ? numbersToText.convert(systemUpdatesButton.systemUpdateCount) + (systemUpdatesButton.systemUpdateCount === 1 ? " update available" : " updates available")
                    : systemUpdatesButton.systemUpdateCount
            opacity: 1.0
            Behavior on color { ColorAnimation { duration: 160 } }
        }
    }

    // Only pulse when updates are actually available — stops the
    // animation (and its render-tree invalidations) at zero updates.
    SequentialAnimation {
        id: updatePulseAnim
        running: systemUpdatesButton.systemUpdateAvailable
        loops: 10
        ParallelAnimation {
            ColorAnimation { target: updateIcon; property: "color"; to: "white"; duration: 600 }
            ColorAnimation { target: updateText; property: "color"; to: "white"; duration: 600 }
        }
        ParallelAnimation {
            ColorAnimation { target: updateIcon; property: "color"; to: systemUpdatesButton.accentColor; duration: 600 }
            ColorAnimation { target: updateText; property: "color"; to: systemUpdatesButton.accentColor; duration: 600 }
        }
        onStopped: {
            updateIcon.color = Qt.binding(() => systemUpdatesButton.accentColor)
            updateText.color = Qt.binding(() => systemUpdatesButton.accentColor)
        }
    }

    Process {
        id: systemUpdateProc
        command: ["sh", "-c", "{ checkupdates 2>/dev/null; yay -Qua 2>/dev/null; } | wc -l"]
        stdout: SplitParser {
            onRead: data => {
                var count = parseInt(data.trim());
                count = isNaN(count) ? 0 : count;
                systemUpdatesButton.systemUpdateCount     = count;
                systemUpdatesButton.systemUpdateAvailable = count > 0;
                // Send notification only when count increases
                if (count > 0 && count !== systemUpdatesButton._prevCount)
                    notifProc.running = true;
                // Clean up all yay notifications when no updates remain
                if (count === 0 && systemUpdatesButton._prevCount > 0) {
                    for (var i = 0; i < NotifService.list.length; i++) {
                        var n = NotifService.list[i];
                        if (n.appName === "yay" && !n.closed) n.close();
                    }
                }
                systemUpdatesButton._prevCount = count;
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
            systemUpdatesButton.systemUpdateCount + " package" + (systemUpdatesButton.systemUpdateCount === 1 ? "" : "s") + " ready to update"
        ]
    }
    // Fire once at startup, then re-check at each hour boundary (aligns with
    // SystemClock.Hours so the process is spawned at most ~25 times/day instead
    // of the previous unconditional 96 times/day with a 15-minute Timer).
    Component.onCompleted: systemUpdateProc.running = true

    SystemClock {
        precision: SystemClock.Hours
        onHoursChanged: systemUpdateProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: systemUpdatesButton._hovered = true
        onExited:  systemUpdatesButton._hovered = false
        onClicked: {
            runUpgrade.running = true
            var pos = systemUpdatesButton.mapToItem(null, 0, 0)
            systemUpdatesButton.clicked(pos.x + systemUpdatesButton.width / 2)
        }
    }

    // Opens a terminal, runs yay -Syu, then re-checks the count
    // Direct Process execution waits for the terminal to close before re-checking
    Process {
        id: runUpgrade
        command: ["kitty", "--config", Quickshell.env("HOME") + "/dotfiles/.config/kitty/kitty-qs-yay.conf", "--title", "qs-kitty-yay", "sh", "-c", "yay -Syu; echo ''; echo 'Press Enter to close...'; read"]
        onRunningChanged: {
            if (running) {
                // Proactively remove yay notifications when upgrade starts
                for (var i = 0; i < NotifService.list.length; i++) {
                    var n = NotifService.list[i];
                    if (n.appName === "yay" && !n.closed) n.close();
                }
            } else {
                // Re-check update count after upgrade completes
                systemUpdateProc.running = true
            }
        }
    }
    
    // Window rules defined in hyprland windowrule.conf (float, size, center, workspace unset)
}
