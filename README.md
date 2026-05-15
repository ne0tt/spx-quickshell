# Quickshell Configuration

![Screenshot](assets/screenshot2.png)

A highly customized Wayland status bar and system interface built with [Quickshell](https://quickshell.outfoxxed.me/) for Hyprland.

**Last Updated**: May 14, 2026 — `shaders.lua` replaces `hyprshade` as the night light backend (Hyprland 0.55 breaking changes)

---

## Overview

A feature-rich top panel for Hyprland with smooth animations, reactive system state, and dropdown panels for everything. The bar is divided into three sections:

- **Left** — App launcher button
- **Center** — Hyprland workspace indicators with glow overlay
- **Right** — Package updates, Bluetooth, volume with audio visualizer, power profile, temperature, notifications, settings, VLAN, system tray, clock, power

---

## Module Status

### ✅ Active Modules
Currently imported and enabled in `shell.qml`:
- **appLauncher** — App search and launcher (floating or dropdown mode)
- **bluetooth** — Bluetooth power toggle and device management
- **calendar** — Calendar dropdown from clock
- **clock** — Time/date display in bar
- **dashboard** — Tabbed info panel (Dashboard/Media/Performance/Weather/Network with VPN)
- **lockscreen** — Session locking with PAM authentication
- **network** — VLAN connection status and management
- **notifications** — D-Bus notification server with popups and history
- **power** — Battery, power profile, temperature, and power actions (lock/logout/reboot/shutdown)
- **settings** — Quick toggles for animations, blur, night light, and more
- **systemTray** — SNI system tray area
- **systemUpdates** — Package update count and upgrade terminal
- **volume** — Volume control with media player integration and audio visualizer
- **wallpaper** — Wallpaper browser and picker with matugen color generation
- **workspaces** — Hyprland workspace switcher with glow overlay

### ⏸️ Available Modules (Not Currently Enabled)
These modules have qmldir configuration files and can be enabled by adding imports to `shell.qml`:
- **chat** — Chat shortcut widget (has qmldir, not imported)
- **weather** — Standalone weather button and dropdown (has qmldir, not imported; weather data used in Dashboard)
- **rightPanelSlider** — Slide-in panel from right edge (has qmldir, not imported)

### 🚧 Incomplete Modules
Modules that exist but lack proper configuration:
- **pomodoro** — Timer module files exist but no qmldir, not integrated into shell
- **vpn** — Module files exist but no qmldir; VPN functionality is integrated into Dashboard Network tab instead

---

## File Structure

```
quickshell/
├── shell.qml                        # Entry point & top bar layout
├── Colors.qml                       # Theme color tokens (auto-updated by matugen)
├── Config.qml                       # Global settings (font, barMonitor, animations, blur)
├── NumbersToText.qml                # Global utility: converts integers to English words
├── cava.conf                        # CAVA audio visualizer configuration
├── qmldir                           # Root module exports (Colors, Config, utilities)
│
├── state/
│   ├── VolumeState.qml              # Singleton: PipeWire default-sink volume & mute
│   ├── WeatherState.qml             # Singleton: open-meteo weather fetch & forecast data
│   ├── BluetoothState.qml           # Singleton: rfkill power control + bluetoothctl monitor
│   └── Audio.qml                    # Singleton: CAVA audio visualizer service
│
├── base/                            # Shared primitives used across modules
│   ├── DropdownBase.qml             # Base for all dropdown panels
│   ├── DropdownTopFlare.qml         # "Ears" decoration at the top of dropdowns
│   ├── HexSweepPanel.qml            # Animated hex grid footer effect
│   ├── MatrixRain.qml               # Matrix-style digital rain canvas effect
│   ├── OverlayPanel.qml             # Centered floating panel (non-bar-anchored)
│   ├── SelectableCard.qml           # Reusable selectable card widget
│   └── SettingsToggleRow.qml        # Icon + label + toggle row for settings
│
└── modules/
    ├── appLauncher/
    │   ├── AppLaunchDropdown.qml    # Bar-anchored inline app search dropdown
    │   └── AppLauncher.qml          # Fullscreen rofi-style launcher (Super+Space)
    ├── bluetooth/
    │   ├── BluetoothButton.qml      # Bluetooth toggle button in bar
    │   └── BluetoothDropdown.qml    # Bluetooth device management panel
    ├── calendar/
    │   └── CalendarPanel.qml        # Calendar dropdown (extends DropdownBase)
    ├── chat/                            # (has qmldir, not imported in shell.qml)
    │   ├── ChatShortcut.qml             # Quick chat access button
    │   └── qmldir                       # Module exports
    ├── dashboard/
    │   ├── DashboardButton.qml      # Dashboard icon button in bar
    │   └── DashboardDropdown.qml    # Tabbed info panel (Dashboard / Media / Performance / Weather / Network)
    ├── clock/
    │   └── ClockPanel.qml           # Time/date display (driven by SystemClock)
    ├── lockscreen/
    │   ├── LockscreenButton.qml     # Lockscreen trigger button in bar
    │   ├── LockscreenContext.qml    # PAM authentication handler
    │   ├── LockscreenService.qml    # Entry point for lockscreen process
    │   ├── LockscreenSurface.qml    # Multi-monitor login UI
    │   ├── pam/password.conf        # Custom PAM configuration
    │   ├── Colors.qml               # Theme colors symlink
    │   └── qmldir                   # Module exports
    ├── network/
    │   ├── NetworkAdminDropdown.qml     # Full NetworkManager admin panel
    │   ├── NetworkButton.qml            # IP address pill in bar
    │   ├── NetworkDropdown.qml          # Ethernet status and details dropdown
    │   ├── VlanButton.qml               # VLAN icon button in bar
    │   ├── VlanDropdown.qml             # VLAN management panel
    │   └── qmldir                       # Module exports
    ├── notifications/
    │   ├── NotifService.qml         # Singleton: D-Bus notification server + list management
    │   ├── NotifCard.qml            # Visual card for a single notification (fade in/out)
    │   ├── NotifPopups.qml          # WlrLayer.Overlay popup stack (top-right)
    │   ├── NotifButton.qml          # Bell icon button in bar with unread count badge
    │   ├── NotifDropdown.qml        # Notification history + yay update card (DropdownBase)
    │   └── qmldir                   # Module exports
    ├── power/
    │   ├── BatteryButton.qml        # Battery percentage + icon indicator in bar
    │   ├── BatteryDropdown.qml      # Battery detail panel (state, ETA, energy)
    │   ├── PowerButton.qml          # Power icon button in bar
    │   ├── PowerDropdown.qml        # Hold-to-confirm power actions (lock, logout, reboot, shutdown)
    │   ├── PowerProfileButton.qml   # Power profile icon in bar
    │   ├── PowerProfileDropdown.qml # Power profile selector
    │   ├── TemperatureButton.qml    # CPU temperature indicator in bar
    │   ├── logout.sh                # Logout helper script invoked by PowerDropdown
    │   ├── reboot.sh                # Reboot helper script invoked by PowerDropdown
    │   └── shutdown.sh              # Shutdown helper script invoked by PowerDropdown
    ├── pomodoro/                        # (no qmldir, not integrated)
    │   ├── PomodoroButton.qml       # Bar button that shows icon or live timer countdown
    │   └── PomodoroDropdown.qml     # Pomodoro controls (work/break, start/pause/reset, durations)
    ├── rightPanelSlider/                # (has qmldir, not imported in shell.qml)
    │   ├── RightPanelButton.qml         # Bar icon that opens the right-side panel
    │   ├── RightPanelSlider.qml         # Panel that slides in from the right edge
    │   └── qmldir                       # Module exports
    ├── settings/
    │   ├── SettingsButton.qml       # Settings gear button in bar
    │   ├── SettingsDropdown.qml     # Quick toggles (night light, animations, blur…)
    │   └── settings.json            # Persisted settings (animations, blur, monitor…)
    ├── systemTray/
    │   ├── SystemTrayPanel.qml      # SNI system tray area
    │   └── TrayMenu.qml             # Right-click context menu for tray icons
    ├── volume/
    │   ├── VolumeButton.qml         # Volume icon + percentage in bar
    │   └── VolumeDropdown.qml       # Volume slider, media controls & audio visualizer
    ├── vpn/                             # (no qmldir; VPN integrated into Dashboard Network tab)
    │   ├── VPNDropdown.qml          # WireGuard connection controls (standalone, unused)
    │   └── VPNModule.qml            # VPN/IP status pill in bar (standalone, unused)
    ├── wallpaper/
    │   ├── WallpaperButton.qml      # Wallpaper picker icon button in bar
    │   └── WallpaperDropdown.qml    # Wallpaper browser and picker
    ├── weather/                         # (has qmldir, not imported in shell.qml)
    │   ├── WeatherButton.qml            # Current conditions indicator in bar
    │   ├── WeatherDropdown.qml          # Detailed weather forecast panel (WeatherState used by Dashboard)
    │   └── qmldir                       # Module exports
    ├── workspaces/
    │   ├── WorkspaceGlowOverlay.qml # Fullscreen glow that follows active workspace
    │   └── WorkspacesPanel.qml      # Hyprland workspace switcher
    └── systemUpdates/
        └── SystemUpdatesButton.qml  # System package update count indicator
```

---

## Core Architecture

### `shell.qml`
Entry point. Hosts the `PanelWindow` (70px tall, 50px exclusive zone), instantiates all modules, and wires up nine global shortcuts. Key utilities:

| Function | Purpose |
|---|---|
| `switchPanel(fn)` | Closes any open dropdown then calls `fn` to open the next one, preventing animation conflicts |
| `closeAllDropdowns()` | Closes every panel and the app launcher |
| `isAnyPanelOpen()` | Returns true if anything is currently open |

The `dropdowns` array is the single registry for all panels — add a new dropdown there and both `closeAllDropdowns` and `isAnyPanelOpen` handle it automatically.

### State Singletons (`state/`)
Reactive state is split into one `Singleton` per concern. All three are registered in the `qs.state` module and accessed directly by name from any file that imports `"../../state"` or `qs.state`.

#### `VolumeState.qml`
Reactive `Quickshell.Services.Pipewire` binding — zero polling, updates instantly on any PipeWire sink change. Volume capped at 100.

| Property / Function | Description |
|---|---|
| `volume` | Current sink volume 0–100 |
| `muted` | Whether the default sink is muted |
| `toggleMute()` | Toggle mute on the default sink |
| `volumeUp()` / `volumeDown()` | ±5% step |
| `setVolume(v)` | Set volume to 0–100, clamped |

#### `WeatherState.qml`
`open-meteo` API (no key required). Auto-detects location via `ipinfo.io`. Fetched once on `Component.onCompleted`, then refreshed hourly via `SystemClock { precision: SystemClock.Hours }`.

| Property | Description |
|---|---|
| `wIcon`, `wDesc`, `wTemp`, `wFeels` | Current conditions |
| `wHumidity`, `wWind`, `wSunrise`, `wSunset` | Extra current detail |
| `wForecast` | 7-day array `{date, icon, desc, min, max}` |
| `wHourly` | 24-hour array `{time, temp, icon}` |
| `wLoading` | `true` while the fetch is in-flight |
| `refresh()` | Force an immediate re-fetch |

#### `BluetoothState.qml`
`rfkill` for power control, `bluetoothctl monitor` as a long-lived process for live state updates, power re-read debounced 600 ms. A 400 ms delay after `rfkill unblock` gives the adapter time to initialize.

| Property / Function | Description |
|---|---|
| `btPowered` | `true` when the BT adapter is on |
| `togglePower()` | On ↔ Off |
| `powerOn()` / `powerOff()` | Explicit transitions |

### `state/Audio.qml`
A separate `Singleton` that manages CAVA audio visualizer integration. Provides real-time audio spectrum data for visual effects.

| Property | Description |
|---|---|
| **`cava.values`** | Array of 24 normalized bar heights (0-1 range) representing audio spectrum |
| **`cava.active`** | Boolean indicating if audio is currently detected |
| **CAVA Process** | Long-running `cava` process with auto-restart on failure. Uses `~/.config/quickshell/cava.conf` for configuration. |
| **Data Format** | Raw CAVA output parsed from semicolon-delimited values, normalized to 0-1 range |

### `Colors.qml`
A `pragma Singleton` registered in the root `qmldir`. Four color tokens used everywhere, accessed directly as `Colors.col_*` from any file (no instantiation needed). Auto-regenerated by [matugen](https://github.com/InioX/matugen) on wallpaper change — manual edits may be overwritten.

| Property | Default | Role |
|---|---|---|
| `col_background` | `#0e1514` | Widget backgrounds |
| `col_source_color` | `#2decec` | Primary accent (cyan) |
| `col_primary` | `#80d5d4` | Lighter accent |
| `col_main` | `#1b3534` | Bar background |

### `NumbersToText.qml`
Registered in the root `qmldir`. A `QtObject` instantiated as `numbersToText` in `shell.qml`, accessible from any component in the tree.

Provides a single `convert(n)` function that converts an integer to sentence-cased English words:

| Input | Output |
|---|---|
| `3` | `"Three"` |
| `38` | `"Thirty eight"` |
| `145` | `"One hundred and forty five"` |
| `1001` | `"One thousand and one"` |

Handles 0–999,999. Falls back to the raw number string for values ≥ 1,000,000.

Usage from any QML file: `numbersToText.convert(someNumber)`

### `Config.qml`
Registered in the root `qmldir`. Shell-wide non-color settings with persistent storage. All persisted settings are read from and written to `modules/settings/settings.json` via `FileView` inotify. A 750 ms debounce timer coalesces rapid changes into single file writes.

| Property | Default | Purpose |
|---|---|---|
| `fontFamily` | `"Hack Nerd Font"` | Font used throughout the shell |
| `fontSize` | `12` | Base font size in pixels |
| `fontWeight` | `Font.Normal` | Font weight for text |
| `barMonitor` | `"DP-1"` | Monitor to display the bar on |
| `animations` | `true` | Enable/disable shell animations |
| `blur` | `true` | Enable/disable background blur effects |
| `launcherFloating` | `false` | Use fullscreen overlay launcher instead of dropdown |
| `workspaceGlow` | `true` | Animated glow behind the active workspace indicator |
| `wallpaperFolder` | `"wallpaper"` | Path to wallpaper directory (absolute or `~/`-relative) |
| `wallpaperSubdirs` | `true` | Search subdirectories when scanning for wallpapers |
| `currentWallpaper` | `""` | Last applied wallpaper path — restored on reload |
| `nightLightStrength` | `"warm"` | Night light intensity: `"soft"` \| `"warm"` \| `"hot"` \| `"max"` |
| `matugenType` | `"scheme-tonal-spot"` | Matugen color scheme algorithm (see Wallpaper section) |

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

**Keyboard focus and Escape-to-close:** `DropdownBase` owns a `keyboardFocusEnabled: bool` property (default `false`). When set to `true`, it binds `WlrLayershell.keyboardFocus` to `WlrKeyboardFocus.Exclusive` while the panel is open, giving it keyboard events directly from the compositor, and releases to `WlrKeyboardFocus.None` on close. All current dropdown subclasses set `keyboardFocusEnabled: true`. Each panel also has a focused `Item` with `Keys.onEscapePressed` that calls `closePanel()` so Escape alone closes the open panel without a global shortcut.

### `OverlayPanel.qml`
Like `DropdownBase` but not anchored to the bar — centers on screen. Used for things that need to appear independently of bar position. API: `show()`, `hide()`, `toggle()`, `isOpen`.

### `HexSweepPanel.qml`
Animated hexagonal grid painted to a `Canvas`. Repaints are rate-limited to ~20 fps via a `Timer` while the animation runs, halving CPU vs vsync-driven repaints. Call `trigger()` to run a sweep.

### `MatrixRain.qml`
Matrix-style digital rain canvas effect with configurable cascade animation. Features adjustable speed, density, trail lengths, and character colors. Currently unused but available for background effects or easter eggs. Runs at ~20 fps with Canvas optimization. (It's a bit buggy, but I may pick it up again soon)

### `SelectableCard.qml`
Card widget used in power profile, VPN, VLAN, notification history, and power action dropdowns for single-select or informational lists.

**Standard props:**

| Prop | Default | Purpose |
|---|---|---|
| `isActive` | `false` | Highlight / selected state |
| `isBusy` | `false` | Disables click while a command is in-flight |
| `cardIcon` | `""` | Nerd-font glyph for the left circle |
| `label` | `""` | Primary text (bold, 13 px) |
| `subtitle` | `""` | Secondary text (12 px); hidden when empty |
| `isPanelOpen` | `false` | Drives the status-dot idle pulse |
| `accentColor` | `white` | Primary accent (from `DropdownBase`) |
| `textColor` | `white` | Primary text colour |
| `dimColor` | `#888888` | Inactive / muted colour |
| `dotActiveColor` | `accentColor` | Colour of the status dot when active |

**Hold-to-confirm props (optional — leave `holdDuration: 0` to disable):**

| Prop | Default | Purpose |
|---|---|---|
| `holdDuration` | `0` | Hold time in ms; `0` = normal click mode |
| `flashLoops` | `3` | Number of border flash cycles after hold |
| `flashOpacityLow` | `0.25` | Lowest opacity during card flash |
| `flashDuration` | `120` | ms per opacity step during card flash |

**Hold-to-confirm behaviour (when `holdDuration > 0`):**
1. Press and hold → accent-colored border traces clockwise from the right-edge midpoint over `holdDuration` ms
2. Status dot pulses accent color while holding
3. Border flashes `flashLoops` × 2 times (80 ms per step) to confirm
4. Card briefly shows full selected state; `clicked()` fires immediately
5. Releasing early or closing the panel cancels everything cleanly

**Signals / methods:**
- `clicked` — emitted when the card is activated (tap or hold-to-confirm)
- `flash()` — trigger the card opacity flash externally
- `resetHoldState()` — cancel all hold animations and reset state

### `SettingsToggleRow.qml`
Icon circle + label + optional subtitle + animated toggle pill. Has an `isBusy` spinner state.

---

## Modules

### Notifications

`NotifService` is a `pragma Singleton` that owns the D-Bus `NotificationServer` and all notification state. Any file in the `qs.modules.notifications` module can reference it directly.

| Component | Purpose |
|---|---|
| `NotifService` | D-Bus server; holds `list` (all notifications) and `popups` (active, non-closed). Provides `clearAll()` and `dnd` toggle. |
| `NotifCard` | Visual card per notification. Fades in on appear; dragging or timeout fades it out. Hover pauses the expire timer. Summary/body are bounded and ellipsized to prevent overflow. |
| `NotifPopups` | `PanelWindow` on `WlrLayer.Overlay`, top-right corner. `ListView` backed by `NotifService.popups`. Cards fade in/out; wrapper collapses height to pull remaining cards up. |
| `NotifButton` | Bell icon (`󰂚`) in the bar. Shows a count badge when there are unread notifications. Click opens `NotifDropdown`. |
| `NotifDropdown` | History panel extending `DropdownBase`. Shows all non-closed notifications as `SelectableCard` items with strict single-line ellipsis truncation for long titles/subtitles. Includes a `systemUpdateCount` card at the top when updates are pending — clicking it closes the panel then launches the system upgrade terminal. |

The notification popup window hides itself when `NotifService.popups` is empty. Each `Notif` object holds a `Set`-based lock mechanism so visual animations can finish before the object is destroyed.

### Battery (`BatteryButton` + `BatteryDropdown`)

`BatteryButton` reads `/sys/class/power_supply/` via `upower` to display a dynamic icon and percentage. Hidden when no battery is detected (desktop systems). `BatteryDropdown` shows full detail: state (charging / discharging / fully-charged), time-to-full or time-to-empty, energy and capacity values, and battery technology.

### App Launcher
Two modes, switchable via Settings:
- **Floating** (`AppLauncher`) — fullscreen overlay with exclusive keyboard focus. Ranked search: exact match → starts-with → contains → generic name → keywords, powered by `DesktopEntries`.
- **Dropdown** (`AppLaunchDropdown`) — bar-anchored, same search engine, results capped at 190 px with scroll.

### Clock (`ClockPanel`)
Uses `SystemClock { precision: SystemClock.Seconds }` — updates aligned to the actual system clock tick rather than a drifting 1 s `Timer`.

### Right Panel (`RightPanelSlider`)
`RightPanelSlider` is a `PanelWindow` anchored to the right+top+bottom edges that slides in from the right. It reserves an exclusive zone on the right edge when open so Hyprland windows reflow around it. Content is added via the `panelContent` default alias. API: `openPanel()`, `closePanel()`, `isOpen`.

*Note: RightPanelSlider module is currently not imported in shell.qml but has proper qmldir configuration and can be enabled. See [Enabling Disabled Modules](#enabling-disabled-modules) section.*

### Weather
`WeatherDropdown` reads all data from `WeatherState`. The dropdown shows current conditions (icon, description, temp, feels-like, humidity, wind, sunrise/sunset) and a multi-day forecast. `onAboutToOpen` triggers a manual `WeatherState.refresh()`.

*Note: Weather module is currently not imported in shell.qml as a standalone button/dropdown, but WeatherState singleton is actively used by the Dashboard's Weather tab (Tab 3). The standalone weather button and dropdown remain available with proper qmldir configuration and can be enabled. See [Enabling Disabled Modules](#enabling-disabled-modules) section.*

### Volume
`VolumeButton` shows icon + percentage, scroll-to-adjust. `VolumeDropdown` provides comprehensive audio control:

- **System Volume**: Main PipeWire sink volume slider 
- **Media Player Control**: Full media player integration via `playerctl` with browser detection
- **Playback Timeline**: Horizontal seek bar with current time on the left and total duration on the right (shared layout with dashboard media tab)
- **Browser Support**: Explicit browser sink detection (Chrome, Firefox, Brave, Vivaldi, Opera)
- **Media Volume**: Separate volume control for active media players with sync capability; slider calls `VolumeState.setVolume()`
- **Audio Visualizer**: Real-time 20-bar CAVA spectrum display with gradient coloring and smooth animation
- **Smart Polling**: Refreshes on open, 800ms polling while active, disabled when closed
- **Robust Metadata Parsing**: Position/duration values are validated and clamped to avoid malformed player metadata breaking layout
- **Dynamic Height**: Adapts from 70px (no media) to 410px (media active) based on content

The audio visualizer is fed by the global `Audio` singleton, displaying normalized spectrum data with 30ms smooth transitions.

### Network
- `NetworkDropdown` — connection name, IP, gateway, DNS via `nmcli`. Button to open `nm-connection-editor`.
- `NetworkAdminDropdown` — three views: connections list (activate/deactivate/delete), connection editor (DHCP/static IP/gateway/DNS), Wi-Fi scanner with connect dialog.
- `VlanButton` and `VlanDropdown` are actively used in the bar (see [VPN / VLAN](#vpn--vlan) section for details).

### Lockscreen
Complete session locking system using Wayland's `WlSessionLock` protocol:

- **Multi-monitor Support**: Login form on primary monitor, black background on secondary monitors
- **PAM Authentication**: Custom PAM configuration with bypass mode for testing
- **Separate Process**: Runs as standalone quickshell instance for security isolation
- **Visual Design**: Clock, date, password input with theme consistency via symlinked Colors.qml
- **Global Shortcut**: Triggered by `quickshell:lockScreen` (typically `SUPER, L`)
- **Session Integration**: Proper Wayland session locking that works with power management
> **⚠️ Bypass button** — `LockscreenSurface.qml` contains a hidden "Bypass" button in the **top-right corner** of the screen. It is invisible (`opacity: 0.0` on both background and label) but fully clickable — it calls `enableBypass()` + `tryUnlock()` to skip PAM authentication entirely. This exists purely for troubleshooting during initial setup. **Remove it (or set `visible: false`) once you are happy with your configuration.** Leaving it in place means anyone with physical access can unlock the screen without a password.
Components:
- **LockscreenButton.qml** — Bar trigger button (icon: 󰌾)
- **LockscreenService.qml** — Entry point for separate process
- **LockscreenSurface.qml** — Multi-monitor UI with authentication
- **LockscreenContext.qml** — PAM integration with testing bypass

> **🖼️ Wallpapers** — The lockscreen uses background wallpapers that are **not included** in this repo. You will need to supply your own and update the path in `LockscreenSurface.qml` to point to them.

> **🦕 Audio** — On lock, a sound clip of Dennis Nedry from *Jurassic Park* plays ("Ah ah ah, you didn't say the magic word!", because I am a man child.). The audio file is included in the `assets/` directory.

### VPN / VLAN

**VLAN (`VlanButton` + `VlanDropdown`):**  
`VlanButton` is displayed in the bar showing VLAN network status. `VlanDropdown` lists VLANs with active state. Runs `nmcli monitor` while open for live updates (debounced 800 ms).

**VPN (integrated into Dashboard Network tab):**  
WireGuard VPN management is integrated into the Dashboard's Network tab (Tab 4), not as standalone bar components. The standalone `vpn/` module directory contains unused VPNDropdown.qml and VPNModule.qml files. See the [Network tab (Tab 4)](#dashboard-dashboardbutton--dashboarddropdown) section for full VPN functionality including:
- WireGuard connection management via `nmcli`
- Selectable cards for each VPN connection  
- Geographic location mapping with pulsing geo-dot on world map
- Keyboard navigation (Up/Down/Enter)
- Flash animation on connection toggle

### Bluetooth
Power controlled via `rfkill`. Live state from `bluetoothctl monitor` parsed in `BluetoothState`. See [`BluetoothState.qml`](#bluetoothstateqml) for debounce and initialization delay details.

### Power & Temperature
`PowerProfileDropdown` uses `power-profiles-daemon` (selectable cards). `PowerDropdown` provides hold-to-confirm power actions: lockscreen, logout, reboot, and shutdown. `TemperatureButton` auto-detects a processor temperature sensor by prioritizing CPU-oriented hwmon devices (`coretemp`, `k10temp`, `zenpower`, `cpu_thermal`, `x86_pkg_temp`) and falls back safely if needed. See [`### Battery`](#battery-batterybutton--batterydropdown) for battery detail.

### Settings
`SettingsDropdown` provides an expandable Night Light card plus seven rows of controls.

**Night Light** (expandable card at the top of the panel):
- Toggle pill enables / disables the screen shader
- Strength slider — 4 snap positions, shader selected by `config.nightLightStrength`:

| Label | Value | Shader file applied |
|---|---|---|
| Soft | `"soft"` | `blue-light-filter-25.glsl` |
| Warm *(default)* | `"warm"` | `blue-light-filter-50.glsl` |
| Hot | `"hot"` | `blue-light-filter-75.glsl` |
| Max | `"max"` | `blue-light-filter-100.glsl` |

> **Hyprland 0.55 — `hyprshade` replaced by `shaders.lua`**
> See [Hyprland 0.55 — Lua Config & Breaking Changes](#hyprland-055--lua-config--breaking-changes) for the full explanation. In short: `hyprshade` is gone; shaders are now applied via `hyprctl eval "hl.config({ decoration = { screen_shader = path } })"` from Quickshell, and `hyprland/shaders.lua` handles the keyboard shortcut cycle and reload restoration natively inside Hyprland. The keybinding **`SUPER + CTRL + Delete`** cycles `off → 25% → 50% → 75% → 100%`. Shader `.glsl` files live in `~/.config/hypr/shaders/`.

**Toggle rows:**

| Row | Label | Bound to |
|---|---|---|
| 1 | Animations | `config.animations` → `hyprctl keyword animations.enabled` |
| 2 | Blur | `config.blur` → `hyprctl eval "hl.config({ decoration = { blur = { enabled = … } } })"` (0.55+) |
| 3 | Bluetooth | `BluetoothState.btPowered` → `rfkill` |
| 4 | Floating Launcher | `config.launcherFloating` (fullscreen vs dropdown) |
| 5 | Workspace Glow | `config.workspaceGlow` |

**Action rows:** Change Wallpaper (opens `WallpaperDropdown`) and Lock Screen.

**Bar Monitor card** (expandable): lists all detected Wayland outputs; click to reassign `config.barMonitor`.

**Settings keyboard navigation:** The panel has full keyboard control with exclusive focus while open.

| Key | Context | Action |
|---|---|---|
| Up / Down | Normal nav | Move focus between the 9 rows (0=Night Light … 8=Lock Screen) |
| Enter | Normal nav | Activate / toggle the focused row; for expandable cards (Night Light, Bar Monitor) opens the sub-nav |
| Space | Night Light focused | Toggle the Night Light on/off immediately |
| Left / Right | Night Light sub-nav | Move the strength slider (Soft → Warm → Hot → Max) |
| Enter | Night Light sub-nav | Apply the highlighted strength and collapse |
| Up / Down | Bar Monitor sub-nav | Move focus between detected monitors |
| Enter | Bar Monitor sub-nav | Apply the selected monitor as `config.barMonitor` and close |
| Escape | Sub-nav open | Exit sub-nav and collapse the expanded card |
| Escape | Normal nav | Close the settings panel |

Card index reference for keyboard nav:

| Index | Card |
|---|---|
| 0 | Night Light (expandable) |
| 1 | Animations |
| 2 | Blur |
| 3 | Bluetooth |
| 4 | Floating Launcher |
| 5 | Workspace Glow |
| 6 | Wallpaper (opens picker) |
| 7 | Bar Monitor (expandable) |
| 8 | Lock Screen |

All state is persisted via the debounced JSON write in `Config.qml`; `FileView` inotify ensures changes are picked up immediately on the next reload.

Settings file lives at `modules/settings/settings.json`:
```json
{
  "barMonitor": "DP-1",
  "animations": true,
  "blur": true,
  "launcherFloating": false,
  "workspaceGlow": true,
  "wallpaperFolder": "/home/user/wallpaper",
  "wallpaperSubdirs": true,
  "currentWallpaper": "",
  "nightLightStrength": "warm",
  "matugenType": "scheme-tonal-spot"
}
```

### Wallpaper (`WallpaperButton` + `WallpaperDropdown`)
`WallpaperButton` is an icon-only button (`󰸉`) that opens `WallpaperDropdown` — a scrollable 4-column thumbnail grid for browsing and applying wallpapers. The button component exists but is not currently placed in the bar; the picker is accessible via the `toggleWallpaperDropdown` global shortcut (`SUPER CTRL + W`) or the **Change Wallpaper** action row in `SettingsDropdown`.

**Wallpaper daemon:** [`awww`](https://github.com/LGFae/swww) (the successor to swww). Wallpapers are applied via:

```sh
awww img <path> --transition-type fade --transition-angle 0 --transition-duration 0.5
```

The current wallpaper is queried on open with `awww query`, so the highlight always reflects what the compositor is actually displaying. The last applied path is also saved to `settings.json` and restored on shell reload.

**Color scheme generation:** After setting a wallpaper, [matugen](https://github.com/InioX/matugen) is run in parallel:

```sh
matugen image <path> --source-color-index 0 --type <matugenType>
```

The `--type` argument is configurable from inside the dropdown itself and persisted to `settings.json`. Available schemes:

| Scheme | Description |
|---|---|
| `scheme-tonal-spot` | Default — subtle, balanced |
| `scheme-content` | Follows image colours closely |
| `scheme-expressive` | Vivid, diverges from source |
| `scheme-fidelity` | Faithful to image palette |
| `scheme-fruit-salad` | Tertiary/secondary colours swapped |
| `scheme-monochrome` | Greyscale |
| `scheme-neutral` | Low chroma |
| `scheme-rainbow` | Full hue range |

**Configurable options (persisted):**

| Option | UI control | Behaviour |
|---|---|---|
| Wallpaper folder | Browse button (zenity / kdialog) | Absolute or `~/`-relative path |
| Include subdirectories | Subdirs toggle pill | Adds `-maxdepth 1` to `find` when off |
| Matugen scheme type | Horizontally scrollable pill row | Saved to `settings.json`; used on next apply |

**Keyboard navigation:** The grid has `WlrKeyboardFocus.Exclusive` while open. Arrow keys move the cursor, Enter applies the focused wallpaper.

### System Tray
`SystemTrayPanel` hosts SNI tray items via `Quickshell.Services.SystemTray`. `TrayMenu` extends `DropdownBase` for right-click context menus.

> **Naming convention:** Bar button components are named `*Button` (e.g. `BluetoothButton`, `VolumeButton`). Dropdown panels that extend `DropdownBase` keep the `*Panel` or `*Dropdown` suffix. The four exceptions that use `*Panel` as bar items — `ClockPanel`, `CalendarPanel`, `SystemTrayPanel`, `WorkspacesPanel` — are more complex widgets with their own internal layout rather than simple icon buttons.

### Dashboard (`DashboardButton` + `DashboardDropdown`)

`DashboardButton` is an icon button (`󱇘`) that opens `DashboardDropdown` — a tabbed panel with five tabs, navigable by clicking or with **Left / Right arrow keys** on the keyboard. The button component exists but is not currently placed in the bar; the dashboard is accessible via the `toggleDashboardDropdown` global shortcut (`SUPER CTRL + D`).

**Tabs:**

| Tab | Icon | Contents |
|---|---|---|
| Dashboard | `󰕮` | Weather card, system info card, clock + inline calendar |
| Media | `󰝚` | Full media player with album art |
| Performance | `󰻠` | CPU / RAM / Disk circular gauges |
| Weather | `󰖕` | Full weather: current + 12-hour strip + 7-day forecast |
| Network | `󰈀` | VLAN IP/gateway/DNS info + WireGuard VPN cards + world map |

**Dashboard tab (Tab 0)** is the default on every open. It shows two side-by-side cards:

- **Weather card** — current icon, temperature, and description from `WeatherState`
- **System info card** — two columns:
  - *Left*: kernel version (`uname -r`), Hyprland version (`hyprctl version`), uptime, and a package update row. When updates are available the row is clickable — clicking it closes the panel and launches a `kitty` terminal running `yay -Syu`. The row flashes white when the update count first increases.
  - *Right*: CPU / RAM / Disk percentage as thin animated progress bars (turns red above 85%).

Below the info cards sits a **clock + date + inline calendar** row:
- Left side: large HH:MM display, full day name, and full date (e.g. `Sunday — 29 March 2026`), driven by `SystemClock { precision: SystemClock.Minutes }` — reactive bindings with no manual `Timer`
- Right side: a mini month calendar with prev/next month navigation arrows. Today's date has a pulsing filled circle; overflow days (previous/next month) are rendered at low opacity.

**Media tab (Tab 1)** provides a full media player:
- Album art (95×95, rounded corners) with an animated cycling border color while playing
- Scrolling marquee for long track titles
- Previous / Play-Pause / Next buttons via `playerctl`
- Volume slider wired to `VolumeState.setVolume()` (same sink as the volume dropdown)

**Performance tab (Tab 2)** shows three circular arc gauges (120×120 Canvas):

| Gauge | Source | Subtitle |
|---|---|---|
| CPU | `vmstat 1 2` — all-core average | "All cores avg" |
| RAM | `free -m` | Used / Total (human-readable GiB/TiB) |
| Disk | `df /` | Used / Total GB |

All gauges animate smoothly (600 ms `OutCubic`) and turn red when ≥ 85%. The tab content is now wrapped in a full card-style box to match other tabs. The tab re-fetches data immediately on becoming visible, then shares the 3 s polling timer.

**Weather tab (Tab 3)** pulls all data from `WeatherState` (same source as the standalone WeatherDropdown):
- Current conditions card: big icon, temp, feels-like, wind, humidity, sunrise
- Hourly strip: next 12 hours from the current hour (horizontally scrollable Flickable, label "Next 12 hours")
- 7-day weekly forecast grid: day name, date, icon, high/low temps. Today/Tomorrow are labelled explicitly.
- Sunrise / Sunset / Wind summary row at the bottom

**Data refresh:**
- On open: all processes run immediately except update checks (`uptimeProc`, `mediaProc`, `perfProc`, `kernelProc`, `hyprlandVerProc`)
- After open animation: `updatesProc` runs once the dropdown is fully rolled down
- While open: a 3 s `Timer` re-polls uptime (tab 0), media (tab 1), and perf (tabs 0 & 2)
- When the upgrade terminal closes: `updatesProc` re-runs locally **and** `upgradeCompleted` signal fires so `SystemUpdatesButton` re-checks the bar count too (see below)

**Cross-panel update sync:** When `dashUpgradeProc` (the kitty upgrade terminal launched from the dashboard) finishes, it emits `upgradeCompleted()`. `shell.qml` connects this to `systemUpdatesButton.recheckUpdates()`, which re-runs the full `checkupdates + yay -Qua` check and updates the bar button count — so all three upgrade paths (bar button, dashboard, notifications) leave the system in a consistent state.

**Network tab (Tab 4)** shows the current VLAN network connection alongside WireGuard VPN management and a speed test panel:

- **Network info**: detects the active VLAN interface via `nmcli`, shows IP address, gateway, and DNS servers. The VLAN ID is derived from the third IP octet (e.g. `192.168.10.x` → `VLAN10`).
- **WireGuard VPN cards**: lists all `nmcli` WireGuard connections as `SelectableCard` items. Click (or keyboard Enter) to bring a connection up or down. Cards flash on activation; busy spinner while toggling.
- **World map**: a colorized equirectangular world map fills the right column. When no VPN is active a darker map variant is shown. When a VPN is active the map switches to the colorized version and a **pulsing geo-dot** appears at the VPN server's location (three staggered ripple rings + inner white dot). The server location is resolved via `http://ip-api.com/json` using the current external IP — when a full-tunnel VPN is active this automatically resolves to the VPN server's geographic location without needing root access.
- **Layout**: the WireGuard header/cards and map are contained inside a shared card-style box for consistency with other tabs.
- **Connection Editor button**: a full-width button sits below the Network box and opens `nm-connection-editor`.
- **Data refresh**: network info and VPN list re-fetch immediately on switching to this tab and every 3 s while the tab is visible.

**Speed test panel (expandable, bottom of Network tab):**

An expandable card runs the Ookla CLI speed test (`speedtest --format=json --progress=yes`):

- **Header row**: shows last result summary (`↓ X.X  ↑ X.X Mbps · DD Mon HH:MM`) and a ▶ / ■ run/stop button. Clicking the header row or pressing Space toggles expand.
- **Gauges**: two circular arc rings (download left, upload right) fill in real-time as bandwidth data streams in. The speed value and "Mbps" label are shown inside each ring in the accent color.
- **Arrows**: a large `↓` and `↑` arrow between the gauges flash the accent color during their respective phases — `↓` during download, `↑` during upload. Both stay on accent color when their phase completes.
- **Status text**: shows `Running…` while the test is active and `Speedtest complete` when done, pinned to the bottom of the panel.
- **Side labels**: Download / Upload headings with ping status (`Testing…` → `Ping: X ms` on completion). Upload side shows `Waiting…` until upload phase begins.
- **Persistence**: results (download, upload, ping, last run time) are cached to `modules/dashboard/speedtest_cache.json` and reloaded on next launch. The cache file is auto-created on first startup.
- **Error handling**: stderr output from the CLI is captured and displayed if the test fails.

**Network tab keyboard navigation:**

| Key | Action |
|---|---|
| Up / Down | Move focus ring between VPN connection cards and the Connection Editor button |
| Enter | Toggle focused VPN (up/down) or open `nm-connection-editor` if the button is focused |
| Left / Right | Switch to previous/next tab |
| Escape | Close the panel |

**Keyboard:** Left/Right arrow keys cycle all five tabs; Escape closes the panel (exclusive keyboard focus while open).

**Global shortcut:** `SUPER CTRL, D` → `quickshell:toggleDashboardDropdown`

---

### Workspaces
`WorkspacesPanel` filters `Hyprland.workspaces` to the configured monitor. `WorkspaceGlowOverlay` is a separate `PanelWindow` that renders a glow behind the active workspace indicator, animating horizontally as workspaces change.

### Package Updates (`SystemUpdatesButton`)
Runs `checkupdates` + `yay -Qua` on startup, hourly via `SystemClock.Hours`, and on a 15-minute periodic refresh to keep state current. The count is also rechecked when Dashboard opens and after any upgrade flow completes. Hidden when count is zero. When updates are found for the first time (or the count changes), a D-Bus notification is sent through QuickShell's own notification server so it appears as a popup. Clicking the bar button opens a floating `kitty` terminal running `yay -Syu`.

Update counting logic is shared with `DashboardDropdown`: repo updates come from `checkupdates`, AUR updates are added via `yay -Qua` when `yay` is available, and missing `yay` gracefully falls back to repo-only counts.

**Position:** First item in the right section of the bar — always leftmost, before Bluetooth and Volume.

**Display toggle — `numberToText` property:**

| Value | Display |
|---|---|
| `true` *(default)* | `"Three updates available"` — uses `NumbersToText.convert()` |
| `false` | `"3"` — raw integer only |

Override on the instance in `shell.qml`: `numberToText: false`

- **Floating Terminal**: Uses kitty with `--title "qs-kitty-yay"` and custom config file
- **Hyprland Integration**: Requires window rule for floating behavior (800x600, centered)
- **Auto-cleanup**: Re-checks package count when terminal closes
- **Visual Feedback**: Pulses 10 times when updates first become available
- **Hold Mode**: Terminal stays open after `yay -Syu` completes for review
- **Notification panel**: The update count card in `NotifDropdown` suppresses the "No notifications" empty state when updates are pending
- **Cross-panel sync**: All upgrade paths re-check the count after the terminal closes — see [Cross-panel update sync](#cross-panel-update-sync) in the Dashboard section for full details.

---

## Hyprland Integration

### Hyprland 0.55 — Lua Config & Breaking Changes

Hyprland 0.55 shipped a native Lua config system (`hyprland.lua` replaces `hyprland.conf`). Several things that previously relied on external tools or colon-delimited config paths changed:

#### Night Light — `hyprshade` replaced by `shaders.lua`

`hyprshade` stopped working in 0.55 because the `decoration:screen_shader` config key was renamed to a dot-path (`decoration.screen_shader`) and the way external tools were expected to apply shaders changed. The fix is a pure-Lua module loaded directly by Hyprland — no external package needed.

`hyprland/shaders.lua` (symlinked / included from `hyprland.lua` via `require("config.shaders")`) handles everything:

- Applies shaders with `hl.config({ decoration = { screen_shader = path } })`.
- Persists the active shader name to `/tmp/hypr_shader_state` so the correct filter survives config reloads (e.g. triggered by matugen after a wallpaper change).
- A `hl.on("config.reloaded", ...)` hook reads that file and re-applies the shader automatically after every reload.
- The keybinding `SUPER + CTRL + Delete` cycles `off → 25% → 50% → 75% → 100%` filter strengths.
- Shader `.glsl` files must be present in `~/.config/hypr/shaders/`.

From the Quickshell side, the Settings night light toggle and strength slider call `hyprctl eval` to invoke `hl.config(...)` directly at runtime, bypassing any need for `hyprshade`.

#### Blur Toggle — `hyprctl eval` instead of `hyprctl keyword`

In Hyprland 0.55 Lua configs, `hyprctl keyword decoration:blur:enabled true` no longer works — the colon-delimited path format is gone. The blur toggle in `SettingsDropdown` now uses `hyprctl eval` to call Lua directly:

```
hyprctl eval "hl.config({ decoration = { blur = { enabled = true } } }); hl.dispatch(hl.dsp.force_renderer_reload())"
```

`force_renderer_reload()` is called immediately after to apply the change without requiring a full config reload. The same pattern is used for `animations.enabled` and `decoration.screen_shader`.

#### Lua Config Structure

The full Hyprland config lives in `~/.config/hypr/hyprland.lua` and loads modular files via `require()`:

| File | Purpose |
|---|---|
| `config/colors.lua` | Color variables sourced by other modules (auto-updated by matugen) |
| `config/decoration.lua` | Blur, rounding, opacity, shadows — uses dot-path Lua syntax |
| `config/animations.lua` | Bezier curves and animation definitions |
| `config/shaders.lua` | Night light / blue-light filter (hyprshade replacement) |
| `config/keybindings.lua` | All binds; layout-aware via `workspace_data.uses_master_layout()` |
| `config/windowrules.lua` | Table-driven window rules with helper functions |
| `config/workspace.lua` | Workspace rules from `workspace_data.lua` |
| `config/workspace_data.lua` | Source of truth for workspace rules and master-layout detection |
| `config/events.lua` | Runtime hooks (opt-in via `ENABLE_EVENT_DEBUG`, `ENABLE_STARTUP_NOTIFICATION`) |
| `config/autostart.lua` | Startup applications |

---

Add to your `hyprland.conf` (or equivalent Lua binds in `config/keybindings.lua`):
```conf
# Quickshell global shortcuts
bind = , escape,       global, quickshell:closeAllDropdowns
bind = SUPER CTRL, W,  global, quickshell:toggleWallpaperDropdown
bind = SUPER, Space,   global, quickshell:toggleAppLauncher
bind = SUPER, L,       global, quickshell:lockScreen
bind = SUPER CTRL, U,  global, quickshell:triggerSystemUpdate
bind = SUPER CTRL, S,  global, quickshell:toggleSettingsDropdown
bind = SUPER CTRL, V,  global, quickshell:toggleVolumeDropdown
bind = SUPER CTRL, N,  global, quickshell:toggleNotifDropdown
bind = SUPER CTRL, D,  global, quickshell:toggleDashboardDropdown

# Volume keys (capped at 100%)
bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.0
bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = , XF86AudioMicMute,     exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
bind = , XF86AudioMute,        exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

# Window rule for floating yay update terminal
windowrule = float, title:^(qs-kitty-yay)$
windowrule = size 800 600, title:^(qs-kitty-yay)$
windowrule = center, title:^(qs-kitty-yay)$
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
2. Create a `qmldir` file in `modules/<name>/` listing all exported components:
   ```
   ComponentName 1.0 ComponentName.qml
   AnotherComponent 1.0 AnotherComponent.qml
   ```
3. Add the `import qs.modules.<name>` line to `shell.qml` (near the top with other imports)
4. Instantiate it in the appropriate bar section (`leftRow`, `centerRow`, `rightRow`)
5. If it's a dropdown, add it to the `dropdowns` array in `shell.qml` so `closeAllDropdowns()` works correctly
6. If adding a global shortcut, create a `GlobalShortcut` block in shell.qml and document it in this README

### Code Style Guidelines
- Use `config.fontFamily` instead of hardcoded font names
- Prefer `Colors.col_*` properties over hardcoded color values
- All modules should have a `qmldir` file to be properly loadable as QML modules
- Use consistent naming: `*Button.qml` for bar buttons, `*Dropdown.qml` for panels extending DropdownBase
- Follow the established pattern for integrating new modules: create qmldir, import in shell.qml, add to dropdowns array if applicable
- Add global shortcuts for new dropdowns in both shell.qml and document them in the README

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
| `cava` | ✅ | Audio spectrum visualizer |
| `playerctl` | ✅ | Media player control and detection |
| `python3` | ✅ | Browser sink detection scripts |
| `awww` | ✅ | Wallpaper daemon (successor to swww) |
| `pam` | ✅ | Lockscreen authentication |
| `kitty` | ✅ | Terminal for package updates |
| `upower` | recommended | Battery status |
| `hyprshade` | ~~recommended~~ **removed** | Replaced by `shaders.lua` — see [Hyprland 0.55 section](#hyprland-055--lua-config--breaking-changes) |
| `zenity` or `kdialog` | recommended | Folder picker dialog in wallpaper panel |
| `yay` | recommended | Package update count |
| `matugen` | recommended | Auto-generate colors from wallpaper — 8 color scheme algorithms |
| `lm_sensors` | recommended | CPU temperature |
| `speedtest-cli` (Ookla) | recommended | Speed test panel in Dashboard Network tab — install via `yay -S speedtest-cli` |

> **Hyprland 0.55 — `hyprshade` removal:** `hyprshade` is no longer used or needed. See [Hyprland 0.55 — Lua Config & Breaking Changes](#hyprland-055--lua-config--breaking-changes) for the full explanation of what changed and how night light and blur are now handled.

> **Note on Python scripts** — Two files reference personal Python scripts for controlling keyboard RGB lighting: `LockscreenSurface.qml` (sets the keyboard to red on lock, restores on unlock) and `VolumeDropdown.qml` (browser audio sink detection). The keyboard RGB scripts (`keyboard-breathing-toggle.py`, `keyboard-rgb.py`) are specific to one hardware setup and are **not needed by most users** — you can safely comment out those `Process` blocks. The `python3` inline commands in `VolumeDropdown.qml` for browser sink detection are more broadly useful and can be kept.

---

## Enabling Disabled Modules

Some modules are currently not imported in `shell.qml` but have proper qmldir configuration and can be enabled:

### Weather Module (Standalone Button)
The weather data is already available via `WeatherState` singleton and used in the Dashboard. To add a dedicated weather button to the bar:

```qml
// In shell.qml imports section:
import qs.modules.weather

// In rightRow section (or wherever you want it):
WeatherButton {
    id: weatherButton
    anchors.verticalCenterOffset: 1
    isActive: weatherDropdown.isOpen
    onClicked: function (clickX) {
        weatherDropdown.panelX = Math.max(0, clickX - weatherDropdown.panelWidth / 2 - 16);
        if (weatherDropdown.isOpen) {
            weatherDropdown.closePanel();
        } else {
            root.switchPanel(() => weatherDropdown.openPanel());
        }
    }
}

// Add dropdown instance (with other dropdowns):
WeatherDropdown {
    id: weatherDropdown
    screen: root.screen
}

// Add to dropdowns array:
readonly property var dropdowns: [..., weatherDropdown]
```

### Right Panel Slider
```qml
// In shell.qml imports section:
import qs.modules.rightPanelSlider

// Add the panel instance:
RightPanelSlider {
    id: rightPanel
    screen: root.screen
}

// Add button to bar:
RightPanelButton {
    id: rightPanelButton
    anchors.verticalCenterOffset: 1
    isActive: rightPanel.isOpen
    onClicked: {
        if (rightPanel.isOpen) {
            rightPanel.closePanel();
        } else {
            root.switchPanel(() => rightPanel.openPanel());
        }
    }
}

// Optional: Add global shortcut
GlobalShortcut {
    name: "toggleRightPanel"
    description: "Open/close the right panel"
    onPressed: {
        if (rightPanel.isOpen) {
            rightPanel.closePanel();
        } else {
            root.switchPanel(() => rightPanel.openPanel());
        }
    }
}
```

### Chat Module
```qml
// In shell.qml imports section:
import qs.modules.chat

// Add to appropriate bar section:
ChatShortcut {
    // your configuration
}
```

### Enabling Pomodoro Module
The pomodoro module currently lacks a qmldir file and is not integrated. To enable it:

1. Create `/modules/pomodoro/qmldir`:
```
PomodoroButton 1.0 PomodoroButton.qml
PomodoroDropdown 1.0 PomodoroDropdown.qml
```

2. Add to `shell.qml` imports:
```qml
import qs.modules.pomodoro
```

3. Add button and dropdown following the same pattern as other modules (see Weather example above).

---

## Potential Improvements

1. **Multi-monitor support** — The bar currently targets a single monitor (`barMonitor`). `ShellRoot` could use `Variants` over `Quickshell.screens` to spawn one bar per monitor, with workspace filtering already per-monitor ready to go.

2. **Error states in panels** — External processes (`yay`, `nmcli`, weather fetch) silently produce empty UI on failure. Adding a visible error/retry state to each panel would make failures obvious and recoverable.

3. **Process timeouts** — Long-running fetches (weather, NM scan) have no timeout guard. A hung process keeps the loading state forever; a `Timer`-based cancel would fix this.

4. **Hardcoded positioning magic numbers** — Several dropdown `panelX` calculations (`pos.x + width/2 - panelWidth/2 - 16 + 250`) are inline in `shell.qml`. Extracting these into a small `alignDropdown(anchor, drop)` helper would remove the duplication and make positioning easier to tune.

5. **Transition type UI** — The `awww` transition type (`fade`, `wipe`, `wave`, `grow`, etc.) and duration are hardcoded in `WallpaperDropdown.qml`. Exposing them in the wallpaper panel (similar to the matugen scheme picker) would let users tune the transition without editing QML.

6. **`settings.json` schema validation** — The JSON is parsed with a bare `JSON.parse` and no schema check. Corrupted or partially-written JSON silently resets all settings. Adding a validation step before applying would prevent this.

7. **Keyboard navigation in dropdowns** — Dropdowns currently require mouse interaction. Tab/arrow key support and a visible focus ring would improve usability and make the launcher more keyboard-friendly beyond the search field.

8. **spring/overshoot animations** — The open/close animations use `OutCubic`/`InCubic`. Replacing the open easing with `OutBack` or a spring curve would give the panels a more playful, polished feel consistent with the hex sweep aesthetic.

9. **`AppLauncher` launch history** — The launcher ranks results purely by string match. Tracking recently launched apps and surfacing them at the top would make it noticeably faster to use day-to-day.

10. **Notification grouping** — Repeated notifications from the same app (e.g. a build system firing many alerts) stack up as separate cards. Grouping them by `appName` with a collapse toggle would keep the popup stack tidy.

---

## License & Credits

This configuration is part of the SiSPX dotfiles collection. Built with [Quickshell](https://quickshell.outfoxxed.me/).

**Font**: Hack Nerd Font  
**Compositor**: Hyprland  
**Color Generation**: matugen

---

## Disclaimer

This was created as a fun learning project — inspiration taken from end_4, Noctalia, etc. Love those drawer animations!
This is in no way to be taken as a "this is how to do a thing..." it is purely "this is how I have done a thing..."

I found there was a lack of tutorials and trying to learn by reverse engineering some other dotfiles was a little overwhelming.

Much of the code was initially created using Claude AI. I then ventured into the Quickshell Discord and sought some help and advice.
Since then I have learnt quite a bit (still more to learn!)

I'm putting this out there in the hope it may help or inspire people.

Feel free to use however you want, just give me a shout out (SiSPX_ on reddit) if you find it helpful.

Once again, a massive shout out to the people on Discord for helping me out.


