# 🛠️ System Fixes, Error Debugging & Tweaks Applied

This document details common Wayland/Hyprland edge cases, package conflicts, daemon crashes, and architectural fixes resolved in this configuration.

---

## 1. Window Close Rapid-Fire Crash / Lag Fix

- **Symptom:** Holding down window close key (`SUPER + Q` or `SUPER + W`) rapidly flooded Hyprland's socket with close dispatchers, causing window manager stutter, unresponsiveness, or socket disconnection.
- **Root Cause:** Unthrottled IPC dispatcher queuing.
- **Fix:** 
  - Implemented a debounce mechanism in `user.lua` and mapped window closing exclusively to `SUPER + W`.
  - Unbound duplicate and conflicting shortcuts to preserve compositor event loop smoothness.

---

## 2. SwayNC GPU Acceleration Freeze Fix

- **Symptom:** Sway Notification Center (SwayNC) occasionally locked up or rendered blank surfaces on integrated GPU wakeups.
- **Fix:** Created systemd service drop-in override:
  - File: `~/.config/systemd/user/swaync.service.d/gpu-fix.conf`
  - Enforces Wayland backend fallback and clean GPU context recreation upon wake.

---

## 3. Voxtype Speech-to-Text Resilience Drop-in

- **Symptom:** Voxtype service exited if audio input device disconnected or changed sample rates during session.
- **Fix:** Created systemd user unit override:
  - File: `~/.config/systemd/user/voxtype.service.d/ryoku-resilient.conf`
  - Configured `Restart=always`, `RestartSec=2s`, and `After=pipewire.service wireplumber.service` to ensure flawless recovery.

---

## 4. Nautilus Wayland Hanging Issue

- **Symptom:** Launching GNOME Nautilus directly on Hyprland sometimes hung waiting for GNOME shell DBus tracking interfaces.
- **Fix:**
  - Created a dedicated sanitized wrapper in `~/.local/bin/nautilus` setting `GDK_BACKEND=wayland,x11` and launching in detached background process.

---

## 5. Live Wallpaper Autopause Daemon

- **Symptom:** Video wallpapers powered by `mpvpaper` ran continuously in the background during full-screen gaming or intensive multitasking, consuming unnecessary GPU/CPU cycles.
- **Fix:**
  - Implemented `hypr-livewall-autopause.service` which listens to Hyprland workspace events and automatically sends `SIGSTOP` / `SIGCONT` to `mpvpaper` when a full-screen window is focused.

---

## 6. Polkit Authentication Agent Daemon

- **Symptom:** Elevated GUI prompts (e.g. GParted, Timeshift, Package Installers) failed to show authentication password dialogs in pure Wayland.
- **Fix:**
  - Configured `dusky_polkit.service` in systemd user autostart pointing to `polkit-gnome` / `hyprpolkitagent` with reliable startup hooks.

---

## 7. Clamshell Mode & Laptop Lid Handling

- **Symptom:** Closing the laptop lid while connected to an external monitor suspended the entire system instead of continuing display output.
- **Fix:**
  - Added `inhibit-lid.service` and configured `modules/lid.lua` to dynamically detect external monitor presence before triggering sleep.
