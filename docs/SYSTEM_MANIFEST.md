# 📋 Complete System Manifest & Inventory

This document details all hardware specifications, system architecture, package breakdowns, and enabled system services captured from this Arch Linux system.

---

## 💻 Hardware & Environment

- **OS:** Arch Linux (Rolling Release, Kernel Linux x86_64)
- **Session Type:** Wayland
- **Compositor:** Hyprland
- **Audio Server:** PipeWire 1.x + WirePlumber (low latency ALSA, PulseAudio, JACK emulation)
- **Display Server Protocol:** Wayland native with XWayland support for legacy apps

---

## 📦 Package Distribution Summary

| Category | Count | Reference File |
| :--- | :--- | :--- |
| **Native Packages (Explicit)** | 309 | [`packages/pacman_native_explicit.txt`](../packages/pacman_native_explicit.txt) |
| **AUR Packages (Explicit)** | 23 | [`packages/aur_explicit.txt`](../packages/aur_explicit.txt) |
| **Total Explicit Packages** | 332 | [`packages/all_explicit.txt`](../packages/all_explicit.txt) |
| **All Installed Packages** | Full System | [`packages/all_installed.txt`](../packages/all_installed.txt) |
| **Desktop Applications** | 172 | [`packages/applications_catalog.tsv`](../packages/applications_catalog.tsv) |
| **Electron & Modern Apps** | Highlighted | [`packages/electron_apps.md`](../packages/electron_apps.md) |

---

## ⚙️ Enabled Systemd User Services

The following daemons manage background window management, power, audio, and UI tools:

```ini
dusky_battery.service           # Battery monitoring & desktop threshold alerts
dusky_polkit.service            # Wayland Polkit authentication agent
hypr-minimized-dock.service     # Bottom dock bar for minimized windows
hypridle.service                # Intelligent screen idle & sleep management
hyprland-power-inhibit.service  # Sleep inhibition during media/gaming
network_meter.service           # Live network throughput calculation
pipewire-pulse.service          # PulseAudio API compatibility layer
pipewire.service                # Core PipeWire audio engine
ryoku-livewall-guardian.service # Live video wallpaper supervisor
ryoku-shell.service             # Core Quickshell / Ryoku UI desktop daemon
touchpad_gestures.service       # 1:1 Touchpad multi-touch gesture daemon
wireplumber.service             # PipeWire session manager
xdg-user-dirs.service           # Standard XDG directory management
ryoku-ai-usage.timer            # AI service telemetry & status timer
```

---

## 📁 Repository Directory Structure

```
ArchLinux/
├── README.md                          # Master project documentation
├── install.sh                         # Automated 1-click restore & setup script
├── docs/                              # Comprehensive documentation
│   ├── CUSTOMIZATIONS_AND_FEATURES.md # All tweaks, mission control, gestures, themes
│   ├── KEYBINDINGS_CHEATSHEET.md      # Full table of all shortcuts
│   ├── ERROR_DEBUG_AND_FIXES.md       # Root-cause fixes & stability patches
│   └── SYSTEM_MANIFEST.md             # This hardware & package inventory
├── dotfiles/                          # Exact configurations from ~/.config
│   ├── hypr/                          # Hyprland modules, user.lua, minmax, animations
│   ├── waybar/                        # Status bar configs & CSS styles
│   ├── wlogout/                       # Session menu layouts & icons
│   ├── rofi/ & fuzzel/                # Application launchers
│   ├── quickshell/                    # Quickshell UI hub & plugins
│   ├── ryoku/ & caelestia/ & dusky/   # Desktop shell configurations
│   ├── matugen/                       # Material You dynamic color generator
│   ├── gtk-3.0/ & gtk-4.0/            # GTK themes & CSS styling
│   ├── qt5ct/ & qt6ct/ & Kvantum/     # Qt unified theme configurations
│   ├── fish/ & kitty/ & alacritty/    # Terminals & shell environments
│   ├── starship.toml                  # Cross-shell prompt theme
│   ├── nvim/ & micro/ & yazi/         # Editors & terminal file manager
│   ├── Thunar/ & nautilus/            # GUI file managers
│   ├── cava/ & mpv/ & wireplumber/    # Audio & media tools
│   ├── systemd-user/                  # Custom systemd unit files
│   └── home-dotfiles/                 # Root home dotfiles (.zshrc, .bashrc, etc.)
├── user_scripts/                      # Complete ~/user_scripts suite (59 modules)
├── scripts/
│   ├── bin/                           # Custom utilities from ~/.local/bin
│   └── enhancements/                  # Master 43PR & Ryoku enhancement scripts
├── desktop-entries/                   # Custom application desktop launchers
├── packages/                          # Complete package lists & catalog
└── system-manifest/                   # Raw dumps (hardware, dconf, audio, binds)
```
