# 🌌 Arch Linux Hyprland Master Customization & Dotfiles Suite

<div align="center">

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)](https://archlinux.org/)
[![Hyprland](https://img.shields.io/badge/Hyprland-00AAFF?style=for-the-badge&logo=wayland&logoColor=white)](https://hyprland.org/)
[![Wayland](https://img.shields.io/badge/Wayland-White?style=for-the-badge&logo=wayland&logoColor=black)](https://wayland.freedesktop.org/)
[![Lua](https://img.shields.io/badge/Lua-2C2D72?style=for-the-badge&logo=lua&logoColor=white)](https://www.lua.org/)
[![PipeWire](https://img.shields.io/badge/PipeWire-Audio-blue?style=for-the-badge)](https://pipewire.org/)

An advanced, beautifully animated, and highly customized **Arch Linux + Hyprland** environment combining the finest design patterns and utilities from **Ryoku Shell**, **43PR Dotfiles**, and **Dusky Linux**.

[✨ Features](#-key-features) • [⌨️ Keybindings](docs/KEYBINDINGS_CHEATSHEET.md) • [🎨 Customizations](docs/CUSTOMIZATIONS_AND_FEATURES.md) • [📦 App Catalog](packages/applications_catalog.tsv) • [🛠️ Debug & Fixes](docs/ERROR_DEBUG_AND_FIXES.md) • [🚀 Installation](#-installation--restore)

</div>

---

## 🌟 Key Features

| Category | Description & Highlights |
| :--- | :--- |
| **🪟 Window Management** | Dual kawase glass blur, 85% opacity, 80% terminal/file manager opacity, 0px borderless clean design. |
| **🚀 Mission Control** | Interactive Expo workspace overview with drag-and-drop window re-arrangement (`SUPER + Tab` / `F3`). |
| **📌 Maximize / Minimize Dock** | Custom background daemon (`hypr-minmax.py`) & bottom icon dock (`minimized-dock.py`) for hidden scratchpads. |
| **🖐️ Touchpad Gestures** | 1:1 finger-tracking physics for workspace navigation and 3-finger swipe up overview. |
| **🎨 Dynamic Material You Theming**| Seamless color synchronization across GTK3/4, Qt5/6, Waybar, Cava, Kitty, and Rofi via `matugen`. |
| **🤖 AI Productivity Suite** | Google Lens (`SUPER + G`), Shazam/Songrec (`SUPER + M`), Voxtype Voice Typing (`ALT + Space`), Kokoro TTS (`SUPER + SHIFT + O`), and OCR Snip (`SUPER + SHIFT + T`). |
| **⚡ Power & Battery Optimization** | Smart idle management (`hypridle`), media-playback sleep inhibition (`hyprland-power-inhibit`), and clamshell mode lid detection. |
| **📶 Wi-Fi & Network Tools** | Real-time network throughput meter in Waybar (`network_meter.service`), Wi-Fi TUI launcher, and DNS manager. |
| **🔊 Audio Routing & Effects** | Low latency PipeWire/WirePlumber with instant device toggle (`ALT + O`/`ALT + I`), mono audio switch (`ALT + M`), and Voice DSP studio (`ALT + N`). |
| **🎬 Live Video Wallpapers** | `mpvpaper` live background supervisor with auto-pause during fullscreen gaming/media to preserve battery. |
| **⌨️ Audio Feedback & HUD** | Mechanical switch sound simulation (`SUPER + U`), on-screen keystroke display (`SUPER + SHIFT + U`), and Glance HUD (`CTRL + ALT + Space`). |

---

## 📂 Repository Architecture

```
ArchLinux/
├── README.md                          # Master documentation & reference
├── install.sh                         # 1-click automated deployment & restore script
├── docs/                              # Detailed documentation guides
│   ├── CUSTOMIZATIONS_AND_FEATURES.md # In-depth technical breakdown of all tweaks
│   ├── KEYBINDINGS_CHEATSHEET.md      # Full table of all shortcuts and commands
│   ├── ERROR_DEBUG_AND_FIXES.md       # Root-cause fixes, edge-case patches & debouncing
│   └── SYSTEM_MANIFEST.md             # Complete hardware, package & service inventory
├── dotfiles/                          # Exact modular configurations from ~/.config
│   ├── hypr/                          # Hyprland modules (Lua runtime, binds, animations)
│   ├── waybar/                        # Customized Waybar status bar layouts & styles
│   ├── wlogout/                       # Centered 5-button circular session menu
│   ├── rofi/ & fuzzel/                # Dark glass application launchers
│   ├── quickshell/                    # Quickshell UI hub, RyoWalls, RyoPin, RyoShot
│   ├── ryoku/ & caelestia/ & dusky/   # Desktop shell engines
│   ├── matugen/                       # Material You dynamic color generator
│   ├── gtk-3.0/ & gtk-4.0/            # GTK custom CSS styling & dark mode overrides
│   ├── qt5ct/ & qt6ct/ & Kvantum/     # Qt unified theme configurations
│   ├── fontconfig/                    # System font fallback & rendering settings
│   ├── fish/ & kitty/ & alacritty/    # Terminals & interactive shell configurations
│   ├── starship.toml                  # Cross-shell prompt theme
│   ├── nvim/ & micro/ & yazi/         # Text editors & terminal file manager
│   ├── Thunar/ & nautilus/            # GUI file managers with blur & custom actions
│   ├── cava/ & mpv/ & wireplumber/    # Audio visualizer, media player & audio server
│   ├── systemd-user/                  # Systemd user services (gestures, dock, power)
│   └── home-dotfiles/                 # Root home dotfiles (.zshrc, .bashrc, .profile)
├── user_scripts/                      # Complete user scripts library (59 specialized modules)
├── scripts/
│   ├── bin/                           # Executable helper utilities from ~/.local/bin
│   └── enhancements/                  # Master 43PR & Ryoku feature enhancer scripts
├── desktop-entries/                   # Custom application desktop launchers
├── packages/                          # Complete package lists (Native, AUR, Flatpak, Electron)
└── system-manifest/                   # Raw dumps (hardware, dconf, audio, binds)
```

---

## ⌨️ Essential Keybindings Quick Reference

| Key Combination | Action |
| :--- | :--- |
| `SUPER + Enter` / `SUPER + T` | Open Terminal (Kitty / Alacritty) |
| `SUPER + Space` / `SUPER + D` | Open App Launcher (Rofi Dark Glass) |
| `SUPER + W` | Close Active Window (Debounced & Safe) |
| `SUPER + V` | Toggle Floating Window Mode |
| `SUPER + F` | Toggle Fullscreen |
| `SUPER + Tab` / `F3` | **Mission Control / Workspace Overview** |
| `SUPER + E` | Open File Manager (Thunar) |
| `SUPER + ALT + E` | Open Terminal File Manager (Yazi) |
| `SUPER + Q` | Open Wallpaper Selector |
| `SUPER + \`` (Backtick) | Open Session / Logout Menu (wlogout) |
| `SUPER + L` | Lock Screen (Hyprlock) |
| `SUPER + G` | AI Google Lens Screen Search |
| `SUPER + M` | AI Shazam / Music Recognition |
| `ALT + Space` | AI Voice Typing (Voxtype) |
| `SUPER + SHIFT + O` | AI Kokoro Neural Text-to-Speech |
| `SUPER + SHIFT + T` | AI OCR Screen Text Extractor |
| `PrintScreen` | Area Screenshot to Clipboard |
| `SHIFT + PrintScreen` | Fullscreen Screenshot to Clipboard |

👉 **[View the Complete Keybindings Cheatsheet](docs/KEYBINDINGS_CHEATSHEET.md)**

---

## 🚀 Installation & Restore

To deploy or restore this entire configuration on any clean Arch Linux installation:

```bash
# 1. Clone the repository
git clone git@github.com:kshitijhurle95-prog/ArchLinux.git
cd ArchLinux

# 2. Make the installer executable & run
chmod +x install.sh
./install.sh
```

The installer will:
1. Prompt to automatically install missing native and AUR packages via `yay`/`paru`.
2. Back up your existing `~/.config` files to `~/.config-backups/`.
3. Deploy all dotfiles, user scripts, helper binaries, and desktop launchers.
4. Enable and start all required `systemd` user services (touchpad gestures, minimize dock, power inhibitor, battery monitor, audio daemons).
5. Load desktop Dconf preferences.

---

## 📚 Detailed Documentation

- 🎨 **[Customizations & Features Guide](docs/CUSTOMIZATIONS_AND_FEATURES.md)**: Deep dive into animations, window rules, opacity, and hardware tweaks.
- ⌨️ **[Keybindings Cheatsheet](docs/KEYBINDINGS_CHEATSHEET.md)**: Complete list of all hotkeys, submaps, and shortcuts.
- 📦 **[Applications Catalog](packages/applications_catalog.tsv)**: Comprehensive inventory of 170+ installed tools and apps.
- ⚡ **[Electron & Modern Apps](packages/electron_apps.md)**: Overview of customized web/electron applications.
- 🛠️ **[Debugging & Fixes Guide](docs/ERROR_DEBUG_AND_FIXES.md)**: Step-by-step solutions applied for Wayland stability.
- 📋 **[System Manifest](docs/SYSTEM_MANIFEST.md)**: Hardware specifications and daemon listings.

---

<div align="center">
  Crafted with care for <b>Arch Linux + Hyprland</b>
</div>
