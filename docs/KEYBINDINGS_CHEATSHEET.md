# ⌨️ Keybindings Master Reference & Cheatsheet

This cheatsheet lists all active keybindings configured in this Arch Linux Hyprland installation (`SUPER` = Windows / Mod Key).

---

## 🪟 Window Management & Navigation

| Key Combination | Action | Details |
| :--- | :--- | :--- |
| `SUPER + W` | Close Window | Debounced safe close (rapid close without crash) |
| `SUPER + V` | Toggle Floating | Centered floating window mode |
| `SUPER + F` | Fullscreen | Toggle true fullscreen state |
| `SUPER + R` | Resize Mode | Enter interactive resize submap (`hjkl` / arrows, `Esc` to exit) |
| `SUPER + Left / Right / Up / Down` | Focus Window | Move focus in specified direction |
| `SUPER + SHIFT + Left / Right / Up / Down` | Move Window | Move window position within layout |
| `SUPER + CTRL + Left / Right` | Quick Resize | Resize window narrower / wider |
| `SUPER + CTRL + Up / Down` | Quick Resize | Resize window shorter / taller |
| `SUPER + 1 .. 0` | Switch Workspace | Jump directly to workspace 1–10 |
| `SUPER + SHIFT + 1 .. 0` | Move to Workspace | Move active window to workspace 1–10 |

---

## 🚀 Applications & Launchers

| Key Combination | Action | Application / Target |
| :--- | :--- | :--- |
| `SUPER + Enter` / `SUPER + T` | Terminal | Kitty / Default Terminal (single clean instance) |
| `SUPER + Space` / `SUPER + D` | App Launcher | Rofi Dark Glass Menu with bold white text & click-exit |
| `SUPER + E` | File Manager | Thunar (with glass blur & custom actions) |
| `SUPER + ALT + E` | Terminal File Manager | Yazi |
| `SUPER + B` | Web Browser | Google Chrome / Zen Browser |
| `SUPER + N` | Text Editor | Neovim / Mousepad |
| `SUPER + O` | Note Taking | Obsidian |
| `SUPER + SHIFT + Return` | Task Manager | btop system resource monitor |

---

## 🌟 Mission Control, Overview & System Surfaces

| Key Combination | Action | Description |
| :--- | :--- | :--- |
| `SUPER + Tab` / `F3` / `CTRL + Up` | **Mission Control** | Expo live workspace overview with drag-and-drop windows |
| `SUPER + Q` | Wallpaper Selector | Rofi / RyoWalls wallpaper carousel picker |
| `SUPER + \`` (Backtick) | Session / Logout Menu | Centered wlogout 5 horizontal circular white buttons |
| `SUPER + L` | Lock Screen | Minimal Hyprlock security screen |
| `SUPER + Escape` | QuickPanal / Quick Settings | Control Center (Wi-Fi, Bluetooth, Audio, Presets) |
| `CTRL + ALT + Space` | Glance HUD | Instant clock, calendar, weather, and system status overlay |
| `SUPER + /` | Keybindings Helper | Interactive searchable keybinds cheatsheet |

---

## 🤖 AI Suite, Productivity & Media Tools

| Key Combination | Action | Description |
| :--- | :--- | :--- |
| `SUPER + G` | Google Lens | Region snip $\rightarrow$ browser visual search & translation |
| `SUPER + M` | Shazam / Songrec | Ambient / system music recognition with desktop alert |
| `ALT + Space` | Voice Typing | Instant speech-to-text with microphone wave indicator |
| `SUPER + SHIFT + O` | Kokoro TTS | Local neural text-to-speech reading clipboard text |
| `SUPER + SHIFT + T` | OCR Snip | Region snip $\rightarrow$ formatted text extracted to clipboard |
| `SUPER + P` | Color Picker | Hyprpicker eyedropper copying HEX code to clipboard |
| `SUPER + .` / `SUPER + ,` | Emoji Picker | Rofi emoji selection menu |
| `SUPER + C` / `XF86Calculator` | Calculator | Rofi inline mathematical evaluator |
| `ALT + Delete` | Process Terminator | Click-to-kill rogue windows |

---

## 📸 Screenshots & Screen Recording

| Key Combination | Action | Destination |
| :--- | :--- | :--- |
| `PrintScreen` | Area Screenshot | Selected region copied directly to clipboard |
| `SHIFT + PrintScreen` | Full Screenshot | Entire display copied directly to clipboard |
| `SUPER + PrtSc` | Swappy Editor | Screenshot opened in Swappy for instant annotations |
| `SUPER + ALT + R` | Screen Recorder | Ryoku / Dusky screen recording toggle |

---

## 🔊 Audio, Display, Scaling & Hardware

| Key Combination | Action | Function |
| :--- | :--- | :--- |
| `ALT + O` | Audio Output Switcher | Cycle headphones $\leftrightarrow$ speakers $\leftrightarrow$ HDMI |
| `ALT + I` | Audio Input Switcher | Cycle internal mic $\leftrightarrow$ USB headset mic |
| `ALT + M` | Mono Audio Toggle | Toggle stereo $\leftrightarrow$ mono audio channel mix |
| `ALT + N` | Voice DSP Studio | Noise suppression & mic enhancer controls |
| `SUPER + U` | Wayclick Sounds | Toggle mechanical keyboard acoustic feedback |
| `SUPER + SHIFT + U` | Keystroke OSD | Toggle on-screen live keypress display |
| `SUPER + ;` | Blur Toggle | Instantly toggle window blur (useful for saving battery) |
| `SUPER + =` / `SUPER + -` | Magnifier Zoom | Zoom into display for fine inspection |
| `ALT + 6` | Game Mode | Temporarily disables animations, blur, and rounding for max FPS |
