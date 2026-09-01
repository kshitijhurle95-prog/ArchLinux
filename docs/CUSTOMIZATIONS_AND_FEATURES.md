# 🎨 Arch Linux Customizations, Features & Tweaks Guide

This document provides a comprehensive technical breakdown of every system customization, visual tweak, feature enhancement, gesture, window management capability, power tweak, and Wi-Fi configuration present in this Arch Linux installation.

---

## 📑 Table of Contents
1. [Desktop Environment & Window Management](#1-desktop-environment--window-management)
2. [Mission Control & Workspace Overview](#2-mission-control--workspace-overview)
3. [Maximize / Minimize System & Dock](#3-maximize--minimize-system--dock)
4. [Visual Aesthetics, Themes & Opacity](#4-visual-aesthetics-themes--opacity)
5. [Animations & Transitions](#5-animations--transitions)
6. [Touchpad Gestures & Navigation](#6-touchpad-gestures--navigation)
7. [AI Suite & Intelligent Tools](#7-ai-suite--intelligent-tools)
8. [Terminal & Shell Customization](#8-terminal--shell-customization)
9. [File Managers & Associations](#9-file-managers--associations)
10. [Hardware, Audio, Wi-Fi & Power Tweaks](#10-hardware-audio-wi-fi--power-tweaks)

---

## 1. Desktop Environment & Window Management

- **Compositor:** Hyprland (Wayland) with Lua orchestration runtime (`hyprland.lua`, `user.lua`, `settings.lua`).
- **Hybrid Architecture:** Deeply integrates the best elements of **Ryoku Shell**, **43PR Dotfiles**, and **Dusky Linux**.
- **Controlled Window Lifecycle:**
  - `SUPER + W`: Debounced rapid window close protection (prevents Hyprland freeze/crashing upon holding keys).
  - `SUPER + Enter` / `SUPER + T`: Single clean terminal instance launcher.
  - `SUPER + V`: Floating window toggle with smooth centered placement.
  - `SUPER + F`: Fullscreen toggle with clean border transition.

---

## 2. Mission Control & Workspace Overview

Inspired by macOS Mission Control and modern Wayland UX:
- **Triggers:** `SUPER + Tab`, `F3`, `CTRL + Up`.
- **Live Previews:** Displays interactive live thumbnail previews of all active workspaces and windows.
- **Drag & Drop Organization:** Drag windows dynamically between workspaces on the fly.
- **Stepping Navigation:** `ALT + Tab` within the overview cycles across active workspaces smoothly.

---

## 3. Maximize / Minimize System & Dock

Hyprland natively lacks a traditional minimize/dock system. This setup implements a custom background daemon and dock:
- **Minimize Handler (`hypr-minmax.py` & `modules/minmax.lua`):**
  - Moves minimized windows to a hidden dedicated workspace scratchpad.
  - Preserves exact window state, geometry, and application references.
- **Minimized Dock (`minimized-dock.py` & `hypr-minimized-dock.service`):**
  - Persistent, stylish bottom pill dock displaying minimized app icons.
  - Clicking an icon restores the window to its active workspace instantly with a popin animation.

---

## 4. Visual Aesthetics, Themes & Opacity

- **Dynamic Material You Colors:** Powered by `matugen`. Generates cohesive accent palettes automatically across GTK, Qt, Waybar, Cava, Kitty, and Rofi based on the current wallpaper.
- **Window Opacities:**
  - **General Windows:** 85% opacity with dual kawase glass blur.
  - **Terminal / Thunar / Settings:** 80% opacity with backdrop blur.
  - **Text & Icons:** 100% solid opacity for crystal-clear readability.
  - **Borders:** Borderless (0px) clean minimalist aesthetic with active accent border highlights when configured.
- **Theming Layers:**
  - **GTK 3/4:** Managed with custom CSS overrides (`~/.config/gtk-3.0/gtk.css`, `~/.config/gtk-4.0/gtk.css`) and `nwg-look`.
  - **Qt 5 / Qt 6:** Uniform look via `qt5ct`, `qt6ct`, and `Kvantum`.

---

## 5. Animations & Transitions

Includes **12 Fluid Animation Presets**:
- **Workspace Switching:** Overshot horizontal slide with bezier curves `(0.16, 1, 0.3, 1)`.
- **Window Opening / Closing:** Popin 80% with fast decel curves.
- **Fade Transitions:** Smooth crossfade on transparency and layer surfaces.
- **Live Wallpaper Engine:** `mpvpaper` and `ryoku-livewall` with `hypr-livewall-autopause.service` (automatically pauses video playback when windows are focused or in fullscreen to preserve CPU/battery).

---

## 6. Touchpad Gestures & Navigation

- **1:1 Smooth Swipe:** 3-finger horizontal swipe moves between workspaces with real-time finger-tracking physics.
- **Overview Gesture:** 3-finger swipe up summons Mission Control / Workspace Overview.
- **Gesture Daemon:** Managed via `touchpad_gestures.service` and `ryoku-cmd-touchpad`.

---

## 7. AI Suite & Intelligent Tools

Seamless keyboard shortcuts invoking smart utility layers:
- **Google Lens Visual Search (`SUPER + G`):** Snips an on-screen area and opens reverse image search / text search directly in your browser.
- **Shazam / Music Recognition (`SUPER + M`):** Listens to system/mic audio via `ryoku-cmd-songrec` and identifies the playing song with desktop notification.
- **Voice Typing (`ALT + SPACE`):** Speech-to-text powered by `voxtype` daemon with dynamic mic wave animation.
- **Kokoro Neural TTS (`SUPER + SHIFT + O`):** High-quality local neural text-to-speech reading selected clipboard text aloud.
- **OCR Snip (`SUPER + SHIFT + T`):** Extracts text from any screen region and copies it to clipboard formatted.
- **Wayclick Mechanical Sounds (`SUPER + U`):** Simulates mechanical switch acoustic feedback for keystrokes.

---

## 8. Terminal & Shell Customization

- **Default Interactive Shell:** `fish` / `zsh` with `starship` cross-shell prompt (`~/.config/starship.toml`).
- **Terminals:** `kitty`, `alacritty`, `ghostty`, `foot`.
- **Multiplexers:** `tmux` and `zellij` with custom keymaps.
- **CLI Tools & Navigation:** `fzf`, `zoxide`, `yazi`, `eza`, `bat`, `ripgrep`, `fastfetch` (with custom banner & specs display).

---

## 9. File Managers & Associations

- **Thunar:** Pre-configured with custom actions, 80% opacity, and glass blur.
- **Nautilus (GNOME Files):** Integrated with custom wrapper script to prevent Wayland startup hanging.
- **Yazi:** Blazing fast terminal file manager on `SUPER + ALT + E`.
- **MIME Associations:** Configured in `mimeapps.list` ensuring media, documents, and code open in designated tools.

---

## 10. Hardware, Audio, Wi-Fi & Power Tweaks

- **Power Optimization:**
  - `hypridle.service` and `hypridle.conf` with intelligent screen dimming and lock triggers.
  - `hyprland-power-inhibit.service`: Prevents sleep during audio/video playback or full-screen gaming.
  - `inhibit-lid.service`: Configured for clamshell mode (external monitor operation when laptop lid is closed).
  - `dusky_battery.service`: Monitors battery health, charging thresholds, and issues desktop alerts.
- **Audio Architecture:**
  - Low-latency `pipewire` + `wireplumber` with `pipewire-pulse`.
  - Audio output switcher (`ALT + O`) and microphone input switcher (`ALT + I`).
  - Mono audio toggle (`ALT + M`) and Voice DSP Studio (`ALT + N`).
- **Wi-Fi & Network Meter:**
  - `network_meter.service`: Real-time network speed monitor displayed in Waybar.
  - Wi-Fi TUI & Manager: Instant access to `nmtui` and DNS switcher.
