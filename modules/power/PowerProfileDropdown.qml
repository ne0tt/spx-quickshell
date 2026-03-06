import Quickshell
import Quickshell.Io
import QtQuick
import "../../base"

// ============================================================
// POWER PROFILE DROPDOWN — drops down like VlanDropdown
// Shows power-saver, balanced and performance as selectable
// rounded cards; the active profile is highlighted.
// ============================================================
DropdownBase {
    id: ppDrop
    reloadableId: "powerProfileDropdown"

    implicitHeight:  340
    panelFullHeight: 186
    panelWidth:      260
    panelTitle:      "Power Profile"
    panelIcon:       "󰚥"
    headerHeight:    34

    // currentProfile is injected from PowerProfilePanel via shell.qml —
    // the panel's DBus monitor is the single source of truth.
    property string currentProfile: ""

    property var profiles: [
        { id: "power-saver",  label: "Power Saver",  subtitle: "Save energy",     icon: "󰌪" },
        { id: "balanced",     label: "Balanced",     subtitle: "Default",         icon: "" },
        { id: "performance",  label: "Performance",  subtitle: "Maximum power",   icon: "" }
    ]

    Process {
        id: setProfile
        property string target: ""
        command: ["sh", "-c", "powerprofilesctl set " + target]
        // currentProfile updates automatically via the panel's DBus monitor
    }

    function activateProfile(profileId) {
        setProfile.target = profileId
        setProfile.running = true
    }

        // ── Profile list ──────────────────────────────────
        Column {
            x: 16 + 14
            y: 16 + ppDrop.headerHeight + 8
            width: ppDrop.panelWidth - 28
            spacing: 8

            Repeater {
                model: ppDrop.profiles

                Item {
                    id: profileRow
                    width: parent.width
                    height: 48

                    property bool isActive: ppDrop.currentProfile === modelData.id

                    SelectableCard {
                        id: card
                        width: parent.width
                        isActive:        profileRow.isActive
                        cardIcon:        modelData.icon
                        label:           modelData.label
                        subtitle:        modelData.subtitle
                        isPanelOpen:     ppDrop.isOpen
                        accentColor:     ppDrop.accentColor
                        textColor:       ppDrop.textColor
                        dimColor:        ppDrop.dimColor
                        flashLoops:      2
                        flashOpacityLow: 0.4
                        flashDuration:   100
                        onClicked: {
                            if (!profileRow.isActive) {
                                card.flash()
                                ppDrop.activateProfile(modelData.id)
                            }
                        }
                    }
                }
            }
        }
}
