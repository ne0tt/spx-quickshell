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
    │   ├── BluetoothButton.qml      # Bluetooth toggle button in bar
    │   └── BluetoothDropdown.qml    # Bluetooth device management panel
    ├── calendar/
    │   └── CalendarPanel.qml        # Calendar dropdown (extends DropdownBase)
    ├── chat/
    │   └── ChatShortcut.qml         # Quick chat access button
    ├── clock/
    │   └── ClockPanel.qml           # Time/date display (driven by SystemClock)
    ├── network/
    │   ├── NetworkAdminDropdown.qml # Full NetworkManager admin panel
    │   ├── NetworkButton.qml        # IP address pill in bar
    │   └── NetworkDropdown.qml      # Ethernet status and details dropdown
    ├── power/
    │   ├── PowerProfileButton.qml   # Power profile icon in bar
    │   ├── PowerProfileDropdown.qml # Power profile selector
    │   └── TemperatureButton.qml    # CPU temperature indicator in bar
    ├── rightPanelSlider/
    │   ├── RightPanelButton.qml     # Bar icon that opens the right-side panel
    │   └── RightPanelSlider.qml     # Panel that slides in from the right edge
    ├── settings/
    │   ├── SettingsButton.qml       # Settings gear button in bar
    │   ├── SettingsDropdown.qml     # Quick toggles (night light, animations, blur…)
    │   └── settings.json            # Persisted settings (animations, blur, monitor…)
    ├── systemTray/
    │   ├── SystemTrayPanel.qml      # SNI system tray area
    │   └── TrayMenu.qml             # Right-click context menu for tray icons
    ├── volume/
    │   ├── VolumeButton.qml         # Volume icon + percentage in bar
    │   └── VolumeDropdown.qml       # Volume slider & media stream controls
    ├── vpn/
    │   ├── VlanButton.qml           # VLAN icon button in bar
    │   ├── VlanDropdown.qml         # VLAN management panel
    │   ├── VPNDropdown.qml          # WireGuard connection controls
    │   └── VPNModule.qml            # VPN/IP status pill in bar
    ├── wallpaper/
    │   ├── WallpaperButton.qml      # Wallpaper picker icon button in bar
    │   └── WallpaperDropdown.qml    # Wallpaper browser and picker
    ├── weather/
    │   ├── WeatherButton.qml        # Current conditions indicator in bar
    │   └── WeatherDropdown.qml      # Detailed weather forecast panel
    ├── workspaces/
    │   ├── WorkspaceGlowOverlay.qml # Fullscreen glow that follows active workspace
    │   └── WorkspacesPanel.qml      # Hyprland workspace switcher
    └── yayUpdate/
        └── YayUpdateButton.qml      # Arch package update count indicator
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

### Right Panel (`RightPanelSlider`)
`RightPanelSlider` is a `PanelWindow` anchored to the right+top+bottom edges that slides in from the right. It reserves an exclusive zone on the right edge when open so Hyprland windows reflow around it. Opened and closed via `RightPanelButton` in the bar or the `SUPER, R` global shortcut (`quickshell:toggleRightPanel`). Content is added via the `panelContent` default alias. API: `openPanel()`, `closePanel()`, `isOpen`.

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
`PowerProfileDropdown` uses `power-profiles-daemon` (selectable cards). `TemperatureButton` reads CPU temp from system sensors with color coding.

### Settings
`SettingsDropdown` provides five toggle rows: Night Light (`hyprshade`), Animations, Blur (both via `hyprctl keyword`), and Launcher mode. A monitor selector writes to `settings.json`. State is persisted via a debounced JSON write; `Config.qml` picks up changes immediately via inotify.

Settings file lives at `modules/settings/settings.json`:
```json
{"animations": true, "blur": true, "launcherFloating": false, "barMonitor": "DP-1"}
```

### System Tray
`SystemTrayPanel` hosts SNI tray items via `Quickshell.Services.SystemTray`. `TrayMenu` extends `DropdownBase` for right-click context menus.

> **Naming convention:** Bar button components are named `*Button` (e.g. `BluetoothButton`, `VolumeButton`). Dropdown panels that extend `DropdownBase` keep the `*Panel` or `*Dropdown` suffix. The four exceptions that use `*Panel` as bar items — `ClockPanel`, `CalendarPanel`, `SystemTrayPanel`, `WorkspacesPanel` — are more complex widgets with their own internal layout rather than simple icon buttons.

### Workspaces
`WorkspacesPanel` filters `Hyprland.workspaces` to the configured monitor. `WorkspaceGlowOverlay` is a separate `PanelWindow` that renders a glow behind the active workspace indicator, animating horizontally as workspaces change.

### Package Updates (`YayUpdateButton`)
Runs `checkupdates` + `yay -Qua` every 15 minutes (configurable via `updateInterval`). Hidden when count is zero. Clicking opens a `kitty` terminal running `yay -Syu` and re-checks the count on completion. Pulses 10 times when updates first become available.

---

## Hyprland Integration

Add to your `hyprland.conf`:
```conf
# Quickshell global shortcuts
bind = , escape,       global, quickshell:closeAllDropdowns
bind = SUPER CTRL, W,  global, quickshell:toggleWallpaperDropdown
bind = SUPER, Space,   global, quickshell:toggleAppLauncher
bind = SUPER, R,       global, quickshell:toggleRightPanel

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



## License & Credits

This configuration is part of the SiSPX dotfiles collection. Built with [Quickshell](https://quickshell.outfoxxed.me/).

**Font**: JetBrains Mono Nerd Font  
**Compositor**: Hyprland  
**Color Generation**: matugen

---

**Last Updated**: March 8, 2026
