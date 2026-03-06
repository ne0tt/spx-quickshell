# Quickshell Configuration

A highly customized Wayland status bar and system interface built with [Quickshell](https://quickshell.outfoxxed.me/) for Hyprland. This configuration provides a modern, feature-rich desktop panel with dropdown menus, system monitoring, and application launching capabilities.

## Disclaimer

This was created out of a fun learning project - Inspiration taken from end_4, Noctalia etc - Love them drawer animations!
This is in no way to be taken as a "this is how to do a thing..." it is purely "this is how I have done a thing..."
Much of the code was initially fleshed out using Claude AI.

I'm putting this out there in the hope it may inspire or help people like me that like the lok of quickshell but wanted to rtry an build something from the ground up rather than using someone elses dots.

Feel free to use however you want but it will be some what unsupported.

I will continue to update as I learn more about quickshell etc.
Feel free to let me know if I am doing anything horribly wrong or anything can be improved.

## Overview

This Quickshell configuration creates a comprehensive top panel with:
- **Left Section**: App launcher and wallpaper picker
- **Center Section**: Hyprland workspace indicators
- **Right Section**: System status widgets (updates, network, VPN, Bluetooth, audio, power profiles, temperature, weather, system tray, and clock)

All interactive elements feature smooth animations, hover effects, and dropdown panels for detailed information and controls.

---

## File Structure

```
/home/sispx/dotfiles/.config/quickshell/
├── shell.qml                    # Main entry point & top panel layout
├── Colors.qml                   # Theme color palette (auto-updated by matugen)
├── Config.qml                   # Global configuration (fonts, bar monitor, etc.)
├── components/                  # Reusable UI components
│   ├── AppLaunchDropdown.qml    # Bar-embedded app search dropdown
│   ├── AppLauncher.qml          # Rofi-style centered application launcher
│   ├── BluetoothDropdown.qml    # Bluetooth device management panel
│   ├── BluetoothPanel.qml       # Bluetooth toggle button in bar
│   ├── BluetoothState.qml       # Shared Bluetooth power state manager
│   ├── CalendarPanel.qml        # Calendar dropdown
│   ├── ChatShortcut.qml         # Quick chat access button (if enabled)
│   ├── ClockPanel.qml           # Time/date display in bar
│   ├── DropdownBase.qml         # Base template for all dropdown panels
│   ├── DropdownTopFlare.qml     # Top decorative "ears" for dropdowns
│   ├── FlaredArcCanvas.qml      # Custom shape painter for dropdown frames
│   ├── HexSweepPanel.qml        # Animated hexagonal grid effect (dropdown footer)
│   ├── NetworkAdminDropdown.qml # Full NetworkManager admin panel
│   ├── NetworkDropdown.qml      # Ethernet connection details dropdown
│   ├── NetworkPanel.qml         # Ethernet IP indicator in bar
│   ├── OverlayPanel.qml         # Centered floating overlay base (non-bar-anchored)
│   ├── PowerProfileDropdown.qml # Power profile selector
│   ├── PowerProfilePanel.qml    # Power profile icon indicator in bar
│   ├── SelectableCard.qml       # Reusable selectable card widget
│   ├── SettingsDropdown.qml     # Quick settings dropdown (toggles, monitor, launcher mode)
│   ├── SettingsPanel.qml        # Settings gear icon button in bar
│   ├── SettingsToggleRow.qml    # Reusable icon + label + toggle switch row
│   ├── SystemTrayPanel.qml      # SNI system tray area
│   ├── TemperaturePanel.qml     # CPU temperature monitor
│   ├── TrayMenu.qml             # Right-click context menu for tray icons
│   ├── VlanDropdown.qml         # VLAN network management panel
│   ├── VlanPanel.qml            # VLAN icon button in bar
│   ├── VolumeDropdown.qml       # Volume slider & media controls
│   ├── VolumePanel.qml          # Volume icon + percentage in bar
│   ├── VolumeState.qml          # Shared volume state (PipeWire reactive)
│   ├── VPNDropdown.qml          # VPN connection controls
│   ├── VPNModule.qml            # VPN IP status pill in bar
│   ├── WallpaperDropdown.qml    # Wallpaper picker panel
│   ├── WallpaperPanel.qml       # Wallpaper picker icon button in bar
│   ├── WeatherDropdown.qml      # Detailed weather forecast panel
│   ├── WeatherPanel.qml         # Current weather indicator in bar
│   ├── WeatherState.qml         # Shared weather data fetcher (hourly poll)
│   ├── WorkspaceGlowOverlay.qml # Fullscreen overlay: glow follows active workspace
│   ├── WorkspacesPanel.qml      # Hyprland workspace switcher
│   └── YayUpdatePanel.qml       # Arch package update count indicator
└── README.md                    # This file
```

---

## Core Files

### `shell.qml`
The main entry point that orchestrates the entire panel. Key responsibilities:
- Defines the top panel window (70px tall, 50px exclusive zone)
- Manages global keyboard shortcuts (registered in Hyprland config)
- Implements panel switching logic (closes one dropdown before opening another)
- Arranges left/center/right sections of the bar
- Instantiates all dropdown panels and shared state managers
- Provides `closeAllDropdowns()`, `isAnyPanelOpen()`, and `switchPanel()` utilities
- `dropdowns` property is a single registry list used by both close and open-check functions — add a new dropdown here and both functions automatically handle it

**Global Shortcuts**:
- `quickshell:closeAllDropdowns` - Close all open panels (bind to ESC)
- `quickshell:toggleWallpaperDropdown` - Toggle wallpaper picker (SUPER+CTRL+W)
- `quickshell:toggleAppLauncher` - Toggle app launcher (SUPER+Space)

### `Colors.qml`
Centralized color theme configuration. Properties:
- `col_background` - Dark background for widgets (#0e1514)
- `col_source_color` - Primary accent color (#2decec, cyan)
- `col_primary` - Lighter accent shade (#80d5d4)
- `col_main` - Bar background color (#1b3534)

**Note**: This file is auto-generated by [matugen](https://github.com/InioX/matugen) based on wallpaper colors. Manual changes may be overwritten.

### `Config.qml`
Global non-color settings:
- `fontFamily` - Font used throughout the shell (currently: `"JetBrainsMonoNF-Regular"`)

Modify this file to change fonts universally across all components.

---

## Component Architecture

### Base Components

#### `DropdownBase.qml`
Abstract base for all dropdown panels. Provides:
- Animated slide-down/slide-up transitions (220ms)
- Optional header with icon & title
- Content area with dynamic height
- Footer with rounded corners and optional `HexSweepPanel`
- `DropdownTopFlare` "ears" decoration
- Public API: `openPanel()`, `closePanel()`, `isOpen` property, `aboutToOpen` signal

**Layout Structure**:
```
┌─────────────────────────────────────┐  
│  DropdownTopFlare (16px ears)       │  
├─────────────────────────────────────┤  
│  Header (optional, icon + title)    │  
├─────────────────────────────────────┤  
│  Content Area (your custom UI)      │  
├─────────────────────────────────────┤  
│  Footer (HexSweepPanel)             │  
└─────────────────────────────────────┘  
```

#### `FlaredArcCanvas.qml`
Custom shape painter for dropdown panels:
- Top corners flare outward (16px notch)
- Rounded bottom corners (16px radius)
- Optional border stroke
- Optional blur shadow effect

#### `HexSweepPanel.qml`
Animated hexagonal grid effect for dropdown footers:
- Call `trigger()` to run a sweep animation
- Configurable colors: `glowColor`, `trailColor`, `ambientColor`
- Supports left-to-right or right-to-left sweep (`mirrored` property)
- 1000ms default duration

### Panel Widgets

#### `WorkspacesPanel.qml`
Displays Hyprland workspaces for the current monitor:
- Monitor bound via `monitorName` property (defaults to `config.barMonitor`)
- Filters Hyprland workspace list to only show workspaces on that monitor
- Highlights active workspace with `col_source_color`
- 50px width per workspace, 5px spacing

#### `AppLauncher.qml`
Rofi-style fullscreen application launcher (toggled via `SUPER+Space` or settings):
- Uses Quickshell's built-in `DesktopEntries` API — no subprocess or `.desktop` file parsing
- Ranked search: exact name match → starts-with → contains → generic name → keywords
- Exclusive keyboard focus when open
- Dark overlay background with blur effect
- Reworked thanks to Steel on Discord ;)

#### `AppLaunchDropdown.qml`
Bar-anchored inline app search dropdown (alternative to the floating launcher):
- Same `DesktopEntries`-powered ranked search as `AppLauncher`
- Animated rotating border on the search field
- Results list capped at 190px height, scrollable
- Toggle mode controlled by `SettingsDropdown` (`launcherFloating` property)

#### `WeatherState.qml` & `WeatherPanel.qml`
**WeatherState** fetches weather data once on startup, then hourly:
- Uses external weather API or service
- Provides: icon, description, temp, feels-like, humidity, wind, sunrise/sunset, forecast
- Call `refresh()` to force immediate update

**WeatherPanel** displays current conditions in the bar with hover effects.

#### `VolumeState.qml` & `VolumePanel.qml`
**VolumeState** manages volume reactively via `Quickshell.Services.Pipewire`:
- Binds directly to `Pipewire.defaultAudioSink.audio` — no polling needed
- `volume` (0–100 int) and `muted` (bool) update automatically on PipeWire change signals
- Mutations (`toggleMute()`, `volumeUp()`, `volumeDown()`, `setVolume(v)`) write directly to the PipeWire node
- No external processes or timers required

**VolumePanel** shows volume icon and percentage with interactive hover.

#### `YayUpdatePanel.qml`
Monitors Arch Linux package updates:
- Runs `yay -Qu` to count available updates every 15 minutes
- Only visible when updates are available
- Shows update count with icon

#### `TemperaturePanel.qml`
Displays CPU temperature:
- Reads from system sensors
- Color-coded based on temp thresholds

#### `PowerProfilePanel.qml` & `PowerProfileDropdown.qml`
**Panel**: Shows current power profile icon (performance/balanced/power-saver)
**Dropdown**: Allows switching between profiles using system power-profiles-daemon

#### `BluetoothState.qml`
Shared Bluetooth power state singleton:
- Runs `bluetoothctl monitor` as a long-lived process to receive live power events
- `btPowered` bool updates reactively via debounced output parsing
- `powerOn()` / `powerOff()` / `togglePower()` — uses `rfkill` and `bluetoothctl`
- Shared between `BluetoothPanel`, `BluetoothDropdown`, and `SettingsDropdown`

#### `BluetoothPanel.qml` & `BluetoothDropdown.qml`
**Panel**: Bluetooth toggle button with dimmed state when off
**Dropdown**: Device pairing, connection management, and controls

#### `VPNModule.qml` & `VPNDropdown.qml`
**Module**: Shows VPN connection status
**Dropdown**: Connect/disconnect VPN profiles

#### `NetworkPanel.qml`
Ethernet IP pill widget in the bar:
- Displays current IP address with a network icon
- Pill background uses `colors.col_background`; highlights on hover/active

#### `NetworkDropdown.qml` & `NetworkAdminDropdown.qml`
**NetworkDropdown**: Lightweight ethernet status view (IP, MAC, interface info) via `nmcli`
**NetworkAdminDropdown**: Full NetworkManager admin panel with three views:
- **connections** — list all saved connections; activate, deactivate, delete
- **edit** — edit IP method (DHCP/static), IP, gateway, DNS for a selected connection
- **wifi** — scan for nearby networks and connect with password prompt

#### `VlanPanel.qml` & `VlanDropdown.qml`
**VlanPanel**: VLAN icon button in the bar (shows active state)
**VlanDropdown**: Lists VLANs and their active status; runs `nmcli monitor` while open for live updates

#### `OverlayPanel.qml`
Centered floating overlay base (distinct from `DropdownBase` which anchors to the bar):
- Appears at screen center by default; `panelX`/`panelY` are configurable
- Fade + scale animation (180ms open, 140ms close)
- `default property alias content` — place child items directly inside it
- Public API: `show()`, `hide()`, `toggle()`, `isOpen`

#### `SettingsPanel.qml`
Settings gear icon button in the bar (opens `SettingsDropdown`).

#### `SettingsDropdown.qml`
Quick settings panel with persistent state saved to `settings.json`:
- **Night Light** toggle (via `wl-gammarelay` or equivalent)
- **Bluetooth** toggle (reads/writes `BluetoothState`)
- **Animations** toggle — disables HexSweepPanel and transition effects
- **Blur** toggle — controls compositor blur hint
- **Launcher mode** — switches between floating `AppLauncher` and bar-anchored `AppLaunchDropdown`
- **Monitor selector** — choose which monitor the bar appears on; written to `settings.json` and reloaded
- State persisted via `settings.json` using a debounced write process

#### `SettingsToggleRow.qml`
Reusable row widget for settings entries:
- Icon circle + label + optional subtitle + animated toggle pill
- `isBusy` property shows a spinner while an action is in progress
- Used exclusively inside `SettingsDropdown`

#### `SystemTrayPanel.qml`
SNI system tray (`Quickshell.Services.SystemTray`) for applications like:
- Solaar (Logitech devices)
- Remmina (remote desktop)
- Other tray-compatible apps

#### `TrayMenu.qml`
Right-click context menu for system tray icons, extending `DropdownBase`:
- `openAt(handle, x)` receives the SNI `menuHandle` and bar X position
- Renders `SystemTrayItem.menu` entries as a scrollable column
- Highlights hovered item with a semi-transparent `col_source_color` background

#### `WallpaperPanel.qml`
Wallpaper picker icon button in the bar (opens `WallpaperDropdown`).

#### `WorkspaceGlowOverlay.qml`
Fullscreen `PanelWindow` overlay that draws a glow under the active workspace indicator:
- Mirrors `WorkspacesPanel` geometry (50px cell width, 5px gap) to align precisely
- Glow item animates horizontally to follow the focused workspace
- Separate window layer so the glow renders behind bar content but above wallpaper

#### `ClockPanel.qml` & `CalendarPanel.qml`
**ClockPanel**: Displays current time/date
**CalendarPanel**: Full calendar view dropdown

#### `WallpaperDropdown.qml`
Wallpaper selection interface:
- Browse wallpaper directory
- Preview and apply wallpapers
- Triggers matugen color scheme update

#### `SelectableCard.qml`
Reusable card component for selections in dropdowns (used in power profiles, wallpaper picker, etc.)

---

## Customization

### Changing Colors
Edit [`Colors.qml`](Colors.qml) directly, or configure matugen to auto-generate colors:
```qml
Colors {
    property color col_background: "#0e1514"
    property color col_source_color: "#2decec"  // Primary accent
    property color col_primary: "#80d5d4"       // Secondary accent
    property color col_main: "#1b3534"          // Bar background
}
```

### Changing Fonts
Edit [`Config.qml`](Config.qml):
```qml
QtObject {
    property string fontFamily: "JetBrainsMonoNF-Regular"  // Your font here
}
```

### Adjusting Monitor
In [`shell.qml`](shell.qml), change the monitor name:
```qml
PanelWindow {
    screen: Quickshell.screens.find(s => s.name === "DP-1")  // Change "DP-1"
```

Also update [`WorkspacesPanel.qml`](components/WorkspacesPanel.qml):
```qml
property string monitorName: "DP-1"  // Match your monitor
```

### Adding/Removing Widgets
In [`shell.qml`](shell.qml), locate the right section `Row` (lines ~350-570) and add/remove components:
```qml
Row {
    // ... existing widgets ...
    
    YourNewWidget {
        fontFamily: root.fontFamily
        accentColor: colors.col_primary
    }
}
```

### Panel Height & Colors
In [`shell.qml`](shell.qml):
```qml
PanelWindow {
    implicitHeight: 70    // Total window height
    exclusiveZone: 50     // Reserved space (actual bar height)
```

Bar styling:
```qml
Rectangle {
    id: mainBar
    radius: 10            // Corner radius
    color: Qt.rgba(colors.col_main.r, colors.col_main.g, colors.col_main.b, 1.0)
    border.color: "black"
    border.width: 0       // Add border if desired
```

---

## Hyprland Integration

Register global shortcuts in your `~/.config/hypr/hyprland.conf`:
```conf
# Quickshell shortcuts
bind = , escape,       global, quickshell:closeAllDropdowns
bind = SUPER CTRL, W,  global, quickshell:toggleWallpaperDropdown
bind = SUPER, Space,   global, quickshell:toggleAppLauncher
```

### Reloading Quickshell
After editing QML files:
```bash
quickshell --reload
```

Or restart completely:
```bash
pkill quickshell && quickshell &
```

---

## Dependencies

**Required**:
- `quickshell` - The shell framework
- `qt6-base`, `qt6-declarative` - Qt6 runtime
- `hyprland` - Wayland compositor
- `foot` - Terminal emulator (for app launcher)
- Nerd Fonts (JetBrains Mono NF recommended) - For icons

**Optional**:
- `matugen` - Auto-generate colors from wallpaper
- `yay` - AUR helper for update notifications
- `pipewire` - Audio control (used natively via `Quickshell.Services.Pipewire`)
- `power-profiles-daemon` - Power profile switching
- `bluez` - Bluetooth support
- `networkmanager` - Network management
- Weather API/service - For weather data

---

## Suggestions & Observations

### Architecture Strengths
1. **Excellent Separation of Concerns**: The `DropdownBase.qml` abstraction eliminates code duplication across 9+ dropdown panels.
2. **Shared State Pattern**: `WeatherState.qml` and `VolumeState.qml` provide centralized state management. `VolumeState` uses `Quickshell.Services.Pipewire` for zero-overhead reactive binding to the default audio sink.
3. **Consistent Design Language**: All panels use the same flared-arc shape and animation timings (220ms), creating visual cohesion.
4. **Performance Optimization**: The `focusedScreen` cached property reduces repeated array lookups.
5. **Smart Panel Management**: `switchPanel()` logic prevents animation conflicts by waiting for close transitions before opening new panels.

### Potential Improvements

#### 1. **Configuration Externalization**
Consider moving hardcoded values to `Config.qml`:
```qml
// Config.qml
QtObject {
    property string fontFamily: "JetBrainsMonoNF-Regular"
    property string monitorName: "DP-1"              // NEW
    property int panelHeight: 70                     // NEW
    property int animationDuration: 220              // NEW
    property string weatherApiKey: "YOUR_KEY_HERE"   // NEW
}
```

This would make the shell more portable and easier to customize.

#### 2. **Error Handling**
Many components spawn external processes (`yay`, `foot`, weather fetchers) but don't handle failures gracefully:
- Add timeout detection for hung processes
- Display error messages in panels when data fetch fails
- Implement retry logic for network-dependent components

#### 3. **Accessibility**
- Add keyboard navigation for dropdowns (Tab/Shift+Tab between options)
- Implement screen reader hints (Qt's Accessible properties)
- Allow font size scaling for vision impairment

#### 4. **Multi-Monitor Support**
Currently hardcoded to `"DP-1"`:
- Auto-spawn one bar per connected monitor
- Make monitor name configurable per-instance
- Sync dropdown state across monitors (close all on any monitor)

#### 5. **Performance Monitoring**
Consider adding debug mode to track:
- Panel open/close animation frame rates
- Process spawn times for app launcher
- Weather API response times
- Memory usage over time

#### 6. **Theme Variants**
With matugen integration, consider:
- Light/dark mode toggle
- Multiple color scheme presets
- Time-based automatic theme switching (day/night)

#### 7. **Component Documentation**
Add JSDoc-style comments to key functions:
```qml
/**
 * Closes all open dropdowns and opens the requested panel after animation completes.
 * @param {function} openFn - Callback to open the new panel
 */
function switchPanel(openFn) { ... }
```

#### 8. **State Persistence**
Consider saving/restoring:
- Last selected wallpaper
- VPN connection preferences
- Power profile preference
- Volume levels

#### 9. **Animation Polish**
- Add spring physics to dropdown animations (ease-out-back)
- Implement staggered animation for workspace indicators
- Add subtle parallax effect to dropdown background

#### 10. **Testing**
Create a test harness for:
- Panel animations (ensure no visual glitches)
- External process handling (mock process outputs)
- Color theme generation (validate contrast ratios)

### Code Quality Observations

**Excellent Practices**:
- Consistent naming convention (`col_*` for colors, `_*` for private)
- Proper use of `readonly` for derived properties
- Color animations for smooth transitions
- Z-indexing to control layer order

**Minor Issues**:
- Some magic numbers (e.g., `pos.x + wallpaperButton.width / 2 - wpDropdown.panelWidth / 2 - 16 + 250`)
  - Extract these positioning calculations into named functions
- Repeated dropdown positioning logic could be abstracted into a helper
- ~~The `closeAllDropdowns()` array could be auto-populated via a registry pattern~~ (resolved: `dropdowns` property is now the single registry)

### Security Considerations
- The app launcher uses Quickshell's `DesktopEntries` API — no shell process or path handling, so injection risk is eliminated
- Weather data fetching may expose API keys in process listings - use environment variables
- VPN/network dropdowns may expose sensitive info - consider privacy mode toggle

### Future Enhancement Ideas
1. **Plugin System**: Allow loading custom components from `~/.config/quickshell/plugins/`
2. **Notification Center**: Integrate with notification daemon
3. **Media Controls**: Add Spotify/MPRIS integration
4. **Quick Settings**: Android-style quick toggle panel
5. **Color Picker**: Built-in dropper tool for theming
6. **Screenshot Integration**: Trigger screenshot/screen recording from bar
7. **Workspace Presets**: Save/restore workspace layouts
8. **Performance Graph**: Real-time CPU/RAM/network graph widget

---

## License & Credits

This configuration is part of the SiSPX dotfiles collection. Built with [Quickshell](https://quickshell.outfoxxed.me/).

**Font**: JetBrains Mono Nerd Font  
**Compositor**: Hyprland  
**Color Generation**: matugen

---

**Last Updated**: March 6, 2026
