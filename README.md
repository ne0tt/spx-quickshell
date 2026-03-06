# Quickshell Configuration

A highly customized Wayland status bar and system interface built with [Quickshell](https://quickshell.outfoxxed.me/) for Hyprland.

## Disclaimer

This was created out of a fun learning project — inspiration taken from end_4, Noctalia etc. Love them drawer animations!
This is in no way to be taken as a "this is how to do a thing..." it is purely "this is how I have done a thing..."
Much of the code was initially fleshed out using Claude AI, Then I ventured into the quickshell discord and seeked some help and advice.

I'm putting this out there in the hope it may inspire or help people like me that like the look of quickshell but wanted to try and build something from the ground up rather than using someone else's dots.

Feel free to use however you want, I will continue to update as I learn more about quickshell etc.

Shout out to the peoples on discord for helping me out ;)

---

## Overview

A feature-rich top panel for Hyprland with smooth animations, reactive system state, and dropdown panels for everything. The bar is divided into three sections:

- **Left** — App launcher button, wallpaper picker
- **Center** — Hyprland workspace indicators with glow overlay
- **Right** — Package updates, network, VPN, Bluetooth, volume, power profile, temperature, weather, system tray, clock

---

## File Structure

```
quickshell/
├── shell.qml                        # Entry point & top bar layout
├── Colors.qml                       # Theme color tokens (auto-updated by matugen)
├── Config.qml                       # Global settings (font, barMonitor)
│
├── state/
│   └── AppState.qml                 # Global singleton: volume, weather, bluetooth
│
├── base/                            # Shared primitives used across modules
│   ├── DropdownBase.qml             # Base for all dropdown panels
│   ├── DropdownTopFlare.qml         # "Ears" decoration at the top of dropdowns
│   ├── FlaredArcCanvas.qml          # Custom shape painter for dropdown frames
│   ├── HexSweepPanel.qml            # Animated hex grid footer effect
│   ├── OverlayPanel.qml             # Centered floating panel (non-bar-anchored)
│   ├── SelectableCard.qml           # Reusable selectable card widget
│   └── SettingsToggleRow.qml        # Icon + label + toggle row for settings
│
└── modules/
    ├── appLauncher/
    │   ├── AppLaunchDropdown.qml    # Bar-anchored inline app search dropdown
    │   └── AppLauncher.qml          # Fullscreen rofi-style launcher (Super+Space)
    ├── bluetooth/
    │   ├── BluetoothDropdown.qml    # Bluetooth device management panel
    │   └── BluetoothPanel.qml       # Bluetooth toggle button in bar
    ├── calendar/
    │   └── CalendarPanel.qml        # Calendar dropdown
    ├── chat/
    │   └── ChatShortcut.qml         # Quick chat access button
    ├── clock/
    │   └── ClockPanel.qml           # Time/date display (driven by SystemClock)
    ├── network/
    │   ├── NetworkAdminDropdown.qml # Full NetworkManager admin panel
    │   ├── NetworkDropdown.qml      # Ethernet status and details dropdown
    │   └── NetworkPanel.qml         # IP address pill in bar
    ├── power/
    │   ├── PowerProfileDropdown.qml # Power profile selector
    │   ├── PowerProfilePanel.qml    # Power profile icon in bar
    │   └── TemperaturePanel.qml     # CPU temperature indicator
    ├── settings/
    │   ├── SettingsDropdown.qml     # Quick toggles (night light, animations, blur…)
    │   ├── SettingsPanel.qml        # Settings gear button in bar
    │   └── settings.json            # Persisted settings (animations, blur, monitor…)
    ├── systemTray/
    │   ├── SystemTrayPanel.qml      # SNI system tray area
    │   └── TrayMenu.qml             # Right-click context menu for tray icons
    ├── volume/
    │   ├── VolumeDropdown.qml       # Volume slider & media stream controls
    │   └── VolumePanel.qml          # Volume icon + percentage in bar
    ├── vpn/
    │   ├── VlanDropdown.qml         # VLAN management panel
    │   ├── VlanPanel.qml            # VLAN icon button in bar
    │   ├── VPNDropdown.qml          # WireGuard connection controls
    │   └── VPNModule.qml            # VPN/IP status pill in bar
    ├── wallpaper/
    │   ├── WallpaperDropdown.qml    # Wallpaper browser and picker
    │   └── WallpaperPanel.qml       # Wallpaper picker icon button in bar
    ├── weather/
    │   ├── WeatherDropdown.qml      # Detailed weather forecast panel
    │   └── WeatherPanel.qml         # Current conditions indicator in bar
    ├── workspaces/
    │   ├── WorkspaceGlowOverlay.qml # Fullscreen glow that follows active workspace
    │   └── WorkspacesPanel.qml      # Hyprland workspace switcher
    └── yayUpdate/
        └── YayUpdatePanel.qml       # Arch package update count indicator
```

---

## Core Architecture

### `shell.qml`
Entry point. Hosts the `PanelWindow` (70px tall, 50px exclusive zone), instantiates all modules, and wires up three global shortcuts. Key utilities:

| Function | Purpose |
|---|---|
| `switchPanel(fn)` | Closes any open dropdown then calls `fn` to open the next one, preventing animation conflicts |
| `closeAllDropdowns()` | Closes every panel and the app launcher |
| `isAnyPanelOpen()` | Returns true if anything is currently open |

The `dropdowns` array is the single registry for all panels — add a new dropdown there and both `closeAllDropdowns` and `isAnyPanelOpen` handle it automatically.

### `state/AppState.qml`
A `Singleton` that owns all shared reactive state. Components read from it directly (`AppState.volume`, `AppState.wTemp`, etc.) rather than spawning their own processes.

| Domain | Implementation |
|---|---|
| **Volume** | Reactive `Quickshell.Services.Pipewire` binding — zero polling, updates instantly on any PipeWire sink change. Volume is capped at 100. |
| **Weather** | `open-meteo` (no API key). Auto-detects location via `ipinfo.io`. Fetched once on startup then refreshed by `SystemClock` on the hour. |
| **Bluetooth** | `rfkill` for power control, `bluetoothctl monitor` as a long-lived process for live state updates, debounced 600 ms. |

### `Colors.qml`
Four color tokens used everywhere. Auto-regenerated by [matugen](https://github.com/InioX/matugen) on wallpaper change — manual edits may be overwritten.

| Property | Default | Role |
|---|---|---|
| `col_background` | `#0e1514` | Widget backgrounds |
| `col_source_color` | `#2decec` | Primary accent (cyan) |
| `col_primary` | `#80d5d4` | Lighter accent |
| `col_main` | `#1b3534` | Bar background |

### `Config.qml`
Non-color shell settings. `barMonitor` is read from `modules/settings/settings.json` at startup and kept in sync via inotify (`FileView { watchChanges: true }`).

| Property | Default |
|---|---|
| `fontFamily` | `"Hack Nerd Font"` |
| `barMonitor` | `"DP-1"` |

---

## Base Components

### `DropdownBase.qml`
All dropdown panels extend this. It handles the full panel lifecycle:
- Animated open (480 ms `OutCubic`) and close (220 ms `InCubic`)
- `DropdownTopFlare` "ears" at the top
- Optional header row (`panelTitle`, `panelIcon`, `headerHeight`)
- Content area (`default property alias panelContent`)
- Footer with `HexSweepPanel` hex animation triggered on open
- Click-outside dismissal via a full-screen `MouseArea`
- Title and content both fade in together during the open animation

```
┌──────────────────────────────────────┐
│  DropdownTopFlare (16 px ears)       │
├──────────────────────────────────────┤
│  Header: icon + title  (optional)    │
├──────────────────────────────────────┤
│  panelContent  (your UI here)        │
├──────────────────────────────────────┤
│  Footer: HexSweepPanel               │
└──────────────────────────────────────┘
```

Public API: `openPanel()`, `closePanel()`, `startOpenAnim()`, `resizePanel()`, `isOpen`, `aboutToOpen` signal.

### `OverlayPanel.qml`
Like `DropdownBase` but not anchored to the bar — centers on screen. Used for things that need to appear independently of bar position. API: `show()`, `hide()`, `toggle()`, `isOpen`.

### `HexSweepPanel.qml`
Animated hexagonal grid painted to a `Canvas`. Repaints are rate-limited to ~20 fps via a `Timer` while the animation runs, halving CPU vs vsync-driven repaints. Call `trigger()` to run a sweep.

### `SelectableCard.qml`
Card widget used in power profile, VPN, and VLAN dropdowns for single-select lists.

### `SettingsToggleRow.qml`
Icon circle + label + optional subtitle + animated toggle pill. Has an `isBusy` spinner state.

---

## Modules

### App Launcher
Two modes, switchable via Settings:
- **Floating** (`AppLauncher`) — fullscreen overlay with exclusive keyboard focus. Ranked search: exact match → starts-with → contains → generic name → keywords, powered by `DesktopEntries`.
- **Dropdown** (`AppLaunchDropdown`) — bar-anchored, same search engine, results capped at 190 px with scroll.

### Clock (`ClockPanel`)
Uses `SystemClock { precision: SystemClock.Seconds }` — updates aligned to the actual system clock tick rather than a drifting 1 s `Timer`.

### Weather
`WeatherDropdown` reads all data from `AppState`. The dropdown shows current conditions (icon, description, temp, feels-like, humidity, wind, sunrise/sunset) and a multi-day forecast. `onAboutToOpen` triggers a manual refresh.

### Volume
`VolumePanel` shows icon + percentage, scroll-to-adjust. `VolumeDropdown` has a slider and per-app media stream controls via `pactl`. Volume is hard-capped at 100 in both `AppState` and the Hyprland keybind (`wpctl set-volume ... --limit 1.0`).

### Network
- `NetworkDropdown` — connection name, IP, gateway, DNS via `nmcli`. Button to open `nm-connection-editor`.
- `NetworkAdminDropdown` — three views: connections list (activate/deactivate/delete), connection editor (DHCP/static IP/gateway/DNS), Wi-Fi scanner with connect dialog.

### VPN / VLAN
- `VPNDropdown` — lists all WireGuard connections via `nmcli`, click to bring up/down. `VPNModule` shows a status pill that hides 5 s after the VPN IP clears.
- `VlanDropdown` — lists VLANs with active state. Runs `nmcli monitor` while open for live updates.

### Bluetooth
Power controlled via `rfkill`. Live state from `bluetoothctl monitor` parsed in `AppState`, debounced 600 ms. A 400 ms delay after `rfkill unblock` gives the adapter time to initialize before re-reading state.

### Power & Temperature
`PowerProfileDropdown` uses `power-profiles-daemon` (selectable cards). `TemperaturePanel` reads CPU temp from system sensors with color coding.

### Settings
`SettingsDropdown` provides five toggle rows: Night Light (`hyprshade`), Animations, Blur (both via `hyprctl keyword`), and Launcher mode. A monitor selector writes to `settings.json`. State is persisted via a debounced JSON write; `Config.qml` picks up changes immediately via inotify.

Settings file lives at `modules/settings/settings.json`:
```json
{"animations": true, "blur": true, "launcherFloating": false, "barMonitor": "DP-1"}
```

### System Tray
`SystemTrayPanel` hosts SNI tray items via `Quickshell.Services.SystemTray`. `TrayMenu` extends `DropdownBase` for right-click context menus.

### Workspaces
`WorkspacesPanel` filters `Hyprland.workspaces` to the configured monitor. `WorkspaceGlowOverlay` is a separate `PanelWindow` that renders a glow behind the active workspace indicator, animating horizontally as workspaces change.

### Package Updates (`YayUpdatePanel`)
Runs `yay -Qu` every 15 minutes. Hidden when count is zero.

---

## Hyprland Integration

Add to your `hyprland.conf`:
```conf
# Quickshell global shortcuts
bind = , escape,       global, quickshell:closeAllDropdowns
bind = SUPER CTRL, W,  global, quickshell:toggleWallpaperDropdown
bind = SUPER, Space,   global, quickshell:toggleAppLauncher

# Volume keys (capped at 100%)
bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.0
bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = , XF86AudioMicMute,     exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
bind = , XF86AudioMute,        exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
```

---

## Customization

### Font
Edit `Config.qml`:
```qml
property string fontFamily: "Hack Nerd Font"
```

### Colors
Edit `Colors.qml` directly, or let matugen manage it from your wallpaper.

### Monitor
Change `barMonitor` in `Config.qml` (or via the Settings dropdown at runtime — it writes to `settings.json` and reloads automatically).

### Adding a Widget
1. Create your component in `modules/<name>/`
2. Add the `import "modules/<name>"` line to `shell.qml`
3. Instantiate it in the appropriate bar section (`leftSection`, `centerRow`, `rightRow`)
4. If it's a dropdown, add it to the `dropdowns` array in `shell.qml`

---

## Dependencies

| Package | Required | Purpose |
|---|---|---|
| `quickshell` | ✅ | Shell framework |
| `qt6-base`, `qt6-declarative` | ✅ | Qt6 runtime |
| `hyprland` | ✅ | Compositor |
| Nerd Fonts | ✅ | Icons throughout the UI |
| `pipewire` | ✅ | Volume control (native via `Quickshell.Services.Pipewire`) |
| `networkmanager` | ✅ | Network / VLAN / Wi-Fi panels |
| `bluez` + `bluez-utils` | ✅ | Bluetooth |
| `wireguard-tools` | ✅ | VPN panel |
| `power-profiles-daemon` | ✅ | Power profile switching |
| `wpctl` (wireplumber) | ✅ | Keyboard volume keys |
| `hyprshade` | recommended | Night light toggle in settings (works with DisplayLink monitors) |
| `yay` | recommended | Package update count |
| `matugen` | recommended | Auto-generate colors from wallpaper |
| `lm_sensors` | recommended | CPU temperature |

---

## Potential Improvements

1. **Multi-monitor support** — The bar currently targets a single monitor (`barMonitor`). `ShellRoot` could use `Variants` over `Quickshell.screens` to spawn one bar per monitor, with workspace filtering already per-monitor ready to go.

2. **Error states in panels** — External processes (`yay`, `nmcli`, weather fetch) silently produce empty UI on failure. Adding a visible error/retry state to each panel would make failures obvious and recoverable.

3. **Process timeouts** — Long-running fetches (weather, NM scan) have no timeout guard. A hung process keeps the loading state forever; a `Timer`-based cancel would fix this.

4. **Hardcoded positioning magic numbers** — Several dropdown `panelX` calculations (`pos.x + width/2 - panelWidth/2 - 16 + 250`) are inline in `shell.qml`. Extracting these into a small `alignDropdown(anchor, drop)` helper would remove the duplication and make positioning easier to tune.

5. **hyprshade shader name** — The night light shader name (`blue-light-filter`) is hardcoded in `SettingsDropdown.qml`. Moving it to `Config.qml` would let you switch shaders without touching module code.

6. **`settings.json` schema validation** — The JSON is parsed with a bare `JSON.parse` and no schema check. Corrupted or partially-written JSON silently resets all settings. Adding a validation step before applying would prevent this.

7. **Keyboard navigation in dropdowns** — Dropdowns currently require mouse interaction. Tab/arrow key support and a visible focus ring would improve usability and make the launcher more keyboard-friendly beyond the search field.

8. **spring/overshoot animations** — The open/close animations use `OutCubic`/`InCubic`. Replacing the open easing with `OutBack` or a spring curve would give the panels a more playful, polished feel consistent with the hex sweep aesthetic.

9. **`AppLauncher` launch history** — The launcher ranks results purely by string match. Tracking recently launched apps and surfacing them at the top would make it noticeably faster to use day-to-day.

10. **README / code sync** — The README is hand-written and will drift as the project evolves. A short comment block at the top of each module file (purpose, public API, dependencies) would keep documentation close to the code and easier to maintain.


This was created out of a fun learning project - Inspiration taken from end_4, Noctalia etc - Love them drawer animations!
This is in no way to be taken as a "this is how to do a thing..." it is purely "this is how I have done a thing..."
Much of the code was initially fleshed out using Claude AI.

I'm putting this out there in the hope it may inspire or help people like me that like the look of quickshell but wanted to try and build something from the ground up rather than using someone else's dots.

Feel free to use however you want, I will continue to update as I learn more about quickshell etc.

Shout out to the peoples on discord for helping out ;)


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
