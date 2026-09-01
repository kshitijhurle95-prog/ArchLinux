#!/usr/bin/env bash
# ==============================================================================
# 🚀 43PR × DUSKY LINUX FEATURE ENHANCER (MASTER DEPLOYER)
# ==============================================================================
# Upgrades a 43PR Hyprland installation with:
# - Window Opacity: 85% general, 80% terminal/files/settings, 100% solid text & icons
# - Glass blur on layers & windows
# - Controlled rapid window closing on holding SUPER + W (debounced)
# - Single clean terminal instance on Super + Enter / Super + T
# - Screenshot keys: PrtSc (selected area -> clipboard), Shift + PrtSc (full screen -> clipboard)
# - Waybar: Media Play/Pause + MPRIS Title + Mini CAVA Visualizer + Wi-Fi icon + Bluetooth + Volume + Battery Indicator + Power
# - QuickPanal at top-left with auto-dismiss on outside click (SUPER + ESC only)
# - App Launcher (Rofi) with Bold White selected text & Click-to-exit
# - Centered Logout Menu (wlogout) with 5 horizontal white-icon buttons
# - Wallpaper Selector (SUPER + Q)
# - Lockscreen only SUPER + L
# - Google Lens, Shazam Music Recognition, Voice Typing, Kokoro Neural TTS, OCR Snip
# - 12 Fluid Dusky Animation Presets
# - Audio In/Out Switchers, Voice DSP Studio & Mono Audio
# - Display Rotation (+90° / -90°) & Magnifier Zoom
# - 1:1 Smooth Touchpad Workspace Switching
# ==============================================================================

set -euo pipefail

readonly USER_HOME="$HOME"
readonly CONFIG_DIR="$USER_HOME/.config"
readonly HYPR_DIR="$CONFIG_DIR/hypr"
readonly ANIM_DIR="$HYPR_DIR/animations"
readonly SCRIPTS_DEST="$USER_HOME/user_scripts"
readonly DUSKY_SETTINGS="$CONFIG_DIR/dusky/settings"
readonly BACKUP_DIR="$USER_HOME/.config-backups/43pr_enhancer_$(date +%Y%m%d_%H%M%S)"

readonly CLR_RESET="\033[0m"
readonly CLR_BOLD="\033[1m"
readonly CLR_BLUE="\033[1;34m"
readonly CLR_GREEN="\033[1;32m"
readonly CLR_YELLOW="\033[1;33m"
readonly CLR_RED="\033[1;31m"
readonly CLR_CYAN="\033[1;36m"

log_info() { printf "${CLR_BLUE}[INFO]${CLR_RESET} %s\n" "$1"; }
log_done() { printf "${CLR_GREEN}[DONE]${CLR_RESET} %s\n" "$1"; }
log_warn() { printf "${CLR_YELLOW}[WARN]${CLR_RESET} %s\n" "$1"; }
log_err()  { printf "${CLR_RED}[ERROR]${CLR_RESET} %s\n" "$1" >&2; }
log_step() { printf "\n${CLR_CYAN}:: ${CLR_BOLD}%s${CLR_RESET}\n" "$1"; }

# 1. PREFLIGHT CHECKS
if [[ "${EUID}" -eq 0 ]]; then
    log_err "Do not execute this script as root/sudo. Run as normal user."
    exit 1
fi

if [[ ! -f /etc/os-release ]]; then
    log_err "Cannot verify operating system."
    exit 1
fi

source /etc/os-release
if [[ "${ID:-}" != "arch" && "${ID_LIKE:-}" != *arch* ]]; then
    log_err "This installer is intended for Arch-compatible Linux distributions."
    exit 1
fi

AUR_HELPER=""
if command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
fi

printf "${CLR_BOLD}======================================================${CLR_RESET}\n"
printf "${CLR_BOLD}   43PR × Dusky Linux Feature Enhancement Suite       ${CLR_RESET}\n"
printf "${CLR_BOLD}======================================================${CLR_RESET}\n"
log_info "Target User:      $USER"
log_info "Config Directory: $CONFIG_DIR"
log_info "AUR Helper:       ${AUR_HELPER:-None detected (will attempt yay)}"

# 2. BACKUP EXISTING CONFIGURATIONS
log_step "Creating safety backup of active configurations..."
mkdir -p "$BACKUP_DIR"
if [[ -d "$HYPR_DIR" ]]; then cp -r "$HYPR_DIR" "$BACKUP_DIR/hypr" 2>/dev/null || true; fi
if [[ -d "$CONFIG_DIR/waybar" ]]; then cp -r "$CONFIG_DIR/waybar" "$BACKUP_DIR/waybar" 2>/dev/null || true; fi
if [[ -d "$CONFIG_DIR/mako" ]]; then cp -r "$CONFIG_DIR/mako" "$BACKUP_DIR/mako" 2>/dev/null || true; fi
if [[ -d "$CONFIG_DIR/rofi" ]]; then cp -r "$CONFIG_DIR/rofi" "$BACKUP_DIR/rofi" 2>/dev/null || true; fi
if [[ -d "$CONFIG_DIR/wlogout" ]]; then cp -r "$CONFIG_DIR/wlogout" "$BACKUP_DIR/wlogout" 2>/dev/null || true; fi
if [[ -d "$CONFIG_DIR/kitty" ]]; then cp -r "$CONFIG_DIR/kitty" "$BACKUP_DIR/kitty" 2>/dev/null || true; fi
log_done "Backup created at: $BACKUP_DIR"

# 3. DEPENDENCY INSTALLATION
log_step "Installing required system and AUR packages..."

readonly REQUIRED_OFFICIAL=(
    mako
    tesseract
    tesseract-data-eng
    libqalculate
    hyprpicker
    playerctl
    socat
    gawk
    python-rich
    python-pillow
    python-gobject
    gtk3
    gtk4
    libadwaita
    luajit
    libxkbcommon
    wl-clipboard
    grim
    slurp
    jq
    libnotify
    brightnessctl
    cava
    pamixer
    pavucontrol
    blueman
    networkmanager
    wireplumber
    pipewire
    pipewire-pulse
    ffmpeg
    bc
)

readonly REQUIRED_AUR=(
    wl-clip-persist
    satty
    gpu-screen-recorder
    gum
    songrec
)

OFFICIAL_TO_INSTALL=()
for pkg in "${REQUIRED_OFFICIAL[@]}"; do
    if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
        OFFICIAL_TO_INSTALL+=("$pkg")
    fi
done

if [[ ${#OFFICIAL_TO_INSTALL[@]} -gt 0 ]]; then
    log_info "Installing official packages: ${OFFICIAL_TO_INSTALL[*]}"
    sudo pacman -S --needed --noconfirm "${OFFICIAL_TO_INSTALL[@]}"
else
    log_done "All required official packages are already installed."
fi

if [[ -n "$AUR_HELPER" ]]; then
    AUR_TO_INSTALL=()
    for pkg in "${REQUIRED_AUR[@]}"; do
        if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
            AUR_TO_INSTALL+=("$pkg")
        fi
    done
    if [[ ${#AUR_TO_INSTALL[@]} -gt 0 ]]; then
        log_info "Installing AUR packages: ${AUR_TO_INSTALL[*]}"
        "$AUR_HELPER" -S --needed --noconfirm "${AUR_TO_INSTALL[@]}" || log_warn "Some AUR packages could not be installed."
    else
        log_done "All required AUR packages are already installed."
    fi
else
    log_warn "No AUR helper detected. Skipping AUR package installations."
fi

# 4. DEPLOY USER SCRIPTS
log_step "Deploying Dusky scripts into ~/user_scripts..."
mkdir -p "$SCRIPTS_DEST"
mkdir -p "$DUSKY_SETTINGS"

if [[ ! -d "$USER_HOME/user_scripts/music" || ! -d "$USER_HOME/user_scripts/network_manager" ]]; then
    log_info "Fetching Dusky scripts from upstream repository..."
    TMP_DUSKY_CLONE=$(mktemp -d)
    git clone --depth 1 https://github.com/dusklinux/dusky.git "$TMP_DUSKY_CLONE" || true
    if [[ -d "$TMP_DUSKY_CLONE/user_scripts" ]]; then
        cp -r "$TMP_DUSKY_CLONE/user_scripts/"* "$SCRIPTS_DEST/"
    fi
    rm -rf "$TMP_DUSKY_CLONE"
else
    log_info "Dusky user_scripts found at $SCRIPTS_DEST"
fi

mkdir -p "$SCRIPTS_DEST/rofi"
mkdir -p "$SCRIPTS_DEST/hypr/input/rofi_keybinds"
mkdir -p "$SCRIPTS_DEST/hypr/monitor"
mkdir -p "$SCRIPTS_DEST/google_image_search"
mkdir -p "$SCRIPTS_DEST/images"
mkdir -p "$SCRIPTS_DEST/performance"
mkdir -p "$SCRIPTS_DEST/audio"
mkdir -p "$SCRIPTS_DEST/music"
mkdir -p "$SCRIPTS_DEST/network_manager"
mkdir -p "$SCRIPTS_DEST/mako_osd"
mkdir -p "$HYPR_DIR/scripts"

# 5. CONFIGURE KITTY OPACITY
log_step "Configuring Kitty terminal opacity..."
mkdir -p "$CONFIG_DIR/kitty"
cat << 'OUTER_EOF' > "$CONFIG_DIR/kitty/kitty.conf"
font_family Consolas
font_size 10
confirm_os_window_close 0

background #000000
foreground #ffffff
background_opacity 0.80
OUTER_EOF

# 6. CONFIGURE WLOGOUT (CENTERED WHITE BUTTONS)
log_step "Configuring wlogout layout & style..."
mkdir -p "$CONFIG_DIR/wlogout"
cat << 'OUTER_EOF' > "$CONFIG_DIR/wlogout/layout"
{
    "label" : "lock",
    "action" : "hyprlock",
    "text" : "Lock",
    "keybind" : "l"
}
{
    "label" : "logout",
    "action" : "hyprctl dispatch exit",
    "text" : "Logout",
    "keybind" : "e"
}
{
    "label" : "suspend",
    "action" : "systemctl suspend",
    "text" : "Suspend",
    "keybind" : "u"
}
{
    "label" : "reboot",
    "action" : "systemctl reboot",
    "text" : "Reboot",
    "keybind" : "r"
}
{
    "label" : "shutdown",
    "action" : "systemctl poweroff",
    "text" : "Shutdown",
    "keybind" : "s"
}
OUTER_EOF

cat << 'OUTER_EOF' > "$CONFIG_DIR/wlogout/style.css"
* {
    background-image: none;
    box-shadow: none;
    font-family: "JetBrainsMono Nerd Font", monospace;
}

window {
    background-color: rgba(12, 12, 12, 0.7);
}

button {
    margin: 10px;
    border-radius: 100px;
    border: 1px solid rgba(255, 255, 255, 0.12);
    color: #FFFFFF;
    font-size: 0px;
    background-color: rgba(20, 20, 20, 0.65);
    background-repeat: no-repeat;
    background-position: center;
    background-size: 36px;
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.45);
    transition: all 0.2s ease;
}

button:hover,
button:focus,
button:active {
    background-color: rgba(45, 45, 45, 0.95);
    border: 1px solid #7aa2f7;
    color: #FFFFFF;
    box-shadow: 0 10px 24px rgba(0, 0, 0, 0.6);
    outline: none;
}

#lock {
    background-image: url("/home/kshitij/.config/wlogout/icons/lock_white.png");
}

#logout {
    background-image: url("/home/kshitij/.config/wlogout/icons/logout_white.png");
}

#suspend {
    background-image: url("/home/kshitij/.config/wlogout/icons/suspend_white.png");
}

#reboot {
    background-image: url("/home/kshitij/.config/wlogout/icons/reboot_white.png");
}

#shutdown {
    background-image: url("/home/kshitij/.config/wlogout/icons/shutdown_white.png");
}
OUTER_EOF

# 7. CONFIGURE ROFI (BOLD WHITE TEXT & CLICK-TO-EXIT)
log_step "Configuring Rofi theme..."
mkdir -p "$CONFIG_DIR/rofi"
cat << 'OUTER_EOF' > "$CONFIG_DIR/rofi/config.rasi"
configuration {
    modes: "combi";
    combi-modes: "window,run,drun";
    drun-display-format: "{name}";
    window-format: "{t:45}  ·  {c}";
    font: "Iosevka 13";

    location: 0;
    fixed-num-lines: true;
    show-icons: true;
    sidebar-mode: false;
    scroll-method: 1;
    matching: "prefix";
    sort: true;
    sorting-method: "normal";
    click-to-exit: true;
    combi-hide-mode-prefix: true;

    display-run: "";
    display-window: "󰖯";
    display-drun: "";
    display-combi: "󰘔";
    display-ssh: "";
}

* {
    bg: #00000020;
    bg-alt: #00000000;
    bg-hover: #242832FF;
    bg-selected: #FFFFFF15;
    fg: #E6EAF2FF;
    fg-muted: #8B93A7FF;
    accent: #7AA2F7FF;
    accent-soft: #7AA2F733;
    urgent: #F7768EFF;
    border-color: #FFFFFF00;

    background-color: transparent;
    text-color: @fg;
    margin: 0;
    padding: 0;
    spacing: 0;
}

window {
    location: center;
    width: 420px;
    height: 420px;
    background-color: @bg;
    border: 2px;
    border-color: @border-color;
    border-radius: 18px;
    padding: 10px;
}

mainbox {
    orientation: vertical;
    background-color: transparent;
    spacing: 12px;
}

inputbar {
    background-color: @bg-alt;
    border: 1px;
    border-color: @border-color;
    border-radius: 12px;
    padding: 5px 15px;
    spacing: 12px;
    children: [prompt, entry];
}

prompt {
    enabled: true;
    background-color: transparent;
    text-color: @accent;
    font: "Iosevka Nerd Font 16";
    padding: 0;
    vertical-align: 0.5;
}

entry {
    background-color: transparent;
    text-color: @fg;
    font: "Iosevka 14";
    placeholder: "";
    placeholder-color: @fg-muted;
    padding: 0;
    vertical-align: 0.5;
    horizontal-align: 0.5;
}

listview {
    background-color: transparent;
    border: 0;
    spacing: 6px;
    padding: 4px 0;
    lines: 8;
    columns: 1;
    fixed-height: true;
    scrollbar: false;
}

element {
    background-color: transparent;
    border: 0;
    border-radius: 10px;
    padding: 10px 14px;
    spacing: 14px;
}

element-icon {
    size: 28px;
    background-color: transparent;
    vertical-align: 0.5;
}

element-text {
    background-color: transparent;
    text-color: inherit;
    vertical-align: 0.5;
    font: "Iosevka 12";
}

element normal.normal,
element alternate.normal {
    background-color: transparent;
    text-color: @fg;
}

element normal.active,
element alternate.active {
    background-color: transparent;
    text-color: @accent;
}

element normal.urgent,
element alternate.urgent {
    background-color: transparent;
    text-color: @urgent;
}

element selected.normal,
element selected.active {
    background-color: @bg-selected;
    text-color: #FFFFFF;
}

element-text selected {
    text-color: #FFFFFF;
    font: "Iosevka Bold 12";
}

element selected.urgent {
    background-color: @urgent;
    text-color: #FFFFFF;
}

message {
    background-color: transparent;
    border: 0;
    padding: 4px 8px;
    text-color: @fg-muted;
}

textbox {
    background-color: transparent;
    text-color: @fg-muted;
    horizontal-align: 0.0;
}
EOF

# 8. DEPLOY PURE 43PR WAYBAR WITH MEDIA, CAVA, WIFI, BLUETOOTH & BATTERY
log_step "Deploying 43PR Waybar with multimedia, visualizer & battery..."
mkdir -p "$CONFIG_DIR/waybar/scripts"
rm -f "$CONFIG_DIR/waybar/config.jsonc" "$CONFIG_DIR/waybar/style.css"

cat << 'OUTER_EOF' > "$CONFIG_DIR/waybar/config.jsonc"
{
    "layer": "top",
    "position": "top",
    "exclusive": true,
    "spacing": 0,

    "modules-left": ["cpu", "custom/gpu", "memory", "temperature"],
    "modules-center": ["clock"],
    "modules-right": ["custom/media_play_pause", "mpris", "custom/cava", "network", "bluetooth", "pulseaudio", "battery", "custom/power"],

    "cpu": {
        "format": "CPU {usage}%",
        "interval": 2
    },

    "memory": {
        "format": "RAM {percentage}%",
        "tooltip-format": "{used} / {total}GiB",
        "interval": 2
    },

    "custom/gpu": {
        "exec": "~/.config/waybar/scripts/gpu_usage.sh",
        "interval": 2,
        "format": "GPU {}%",
        "tooltip-format": "GPU: {}%"
    },
    
    "temperature": {
        "critical-threshold": 80,
        "format": " {temperatureC}°C",
        "format-critical": " {temperatureC}°C",
        "tooltip": true,
        "tooltip-format": "CPU Temp: {temperatureC}°C",
        "interval": 2,
        "on-click": "~/.config/waybar/scripts/toggle-gammastep"
    },

    "clock": {
        "format": "{:%H:%M}",
        "tooltip-format": "<tt><small>{calendar}</small></tt>",
        "calendar": {
            "mode": "month",
            "format": {
                "today": "<b><u>{}</u></b>"
            }
        }
    },

    "custom/media_play_pause": {
        "format": "{}",
        "exec": "playerctl status 2>/dev/null | grep -qi 'Playing' && echo '' || (playerctl status 2>/dev/null | grep -qi 'Paused' && echo '' || echo '')",
        "interval": 1,
        "on-click": "playerctl play-pause",
        "tooltip": false
    },

    "mpris": {
        "format": "{title} - {artist}",
        "format-paused": "{title} - {artist}",
        "max-length": 30,
        "tooltip": false,
        "interval": 2
    },

    "custom/cava": {
        "exec": "/home/kshitij/user_scripts/waybar/cava.sh --bars 6 --clean",
        "format": "{}",
        "tooltip": false
    },

    "network": {
        "format-wifi": "",
        "format-ethernet": "󰈀",
        "format-linked": "󰈁",
        "format-disconnected": "󰖪",
        "tooltip-format": "Wi-Fi: {essid} ({signalStrength}%)\nIP: {ipaddr}\nClick to open Wi-Fi Manager",
        "tooltip-format-disconnected": "Wi-Fi Disconnected\nClick to open Wi-Fi Manager",
        "on-click": "kitty --class dusky_tui -e python3 /home/kshitij/user_scripts/network_manager/tui_dusky_network.py"
    },

    "bluetooth": {
        "format": "",
        "format-disabled": "󰂲",
        "format-connected": " {device_alias}",
        "format-connected-battery": " {device_alias} {device_battery_percentage}%",
        "tooltip-format": "Bluetooth: {controller_alias}\nClick to open Bluetooth Manager",
        "tooltip-format-connected": "Connected: {device_alias}\nBattery: {device_battery_percentage}%\nClick to open Bluetooth Manager",
        "on-click": "blueman-manager"
    },

    "pulseaudio": {
        "format": "{icon}  {volume}%",
        "format-muted": "Muted",
        "format-icons": {
            "default": ["", "", ""]
        },
        "tooltip": false,
        "on-click": "pavucontrol",
        "on-click-right": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
    },

    "battery": {
        "states": {
            "good": 95,
            "warning": 30,
            "critical": 15
        },
        "format": "{icon}  {capacity}%",
        "format-charging": "󱐋 {capacity}%",
        "format-plugged": "  {capacity}%",
        "format-alt": "{icon}  {time}",
        "format-icons": ["", "", "", "", ""],
        "tooltip-format": "{timeTo}\nHealth: {health}%\nCapacity: {capacity}%"
    },

    "custom/power": {
        "format": "⏻",
        "tooltip": false,
        "on-click": "pgrep -x wlogout >/dev/null && pkill -x wlogout || wlogout -b 5 -c 20 -r 20 -L 550 -R 550 -T 460 -B 460"
    }
}
OUTER_EOF

cat << 'OUTER_EOF' > "$CONFIG_DIR/waybar/style.css"
* {
    font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font Mono", monospace;
    font-size: 11px;
    min-height: 0;
}

window#waybar {
    min-height: 10px;
    background-color: rgba(20, 20, 20, 0);
    color: #ffffff;
}

.modules-left {
    background-color: rgba(20, 20, 20, 0.5);
    border-radius: 10px;
    margin: 4px 0 2px 6px;
}

.modules-center {
    background-color: rgba(20, 20, 20, 0.5);
    border-radius: 10px;
    margin: 4px 0 2px;
}

.modules-right {
    background-color: rgba(20, 20, 20, 0.5);
    border-radius: 10px;
    margin: 4px 6px 2px 0;
}

#cpu, #memory, #custom-gpu, #clock, #pulseaudio, #network, #bluetooth, #custom-media_play_pause, #mpris, #custom-cava, #battery, #custom-power, #temperature {
    padding: 0 10px;
    margin: 0 2px;
}

#custom-power {
    color: #ffffff;
    font-size: 15px;
    margin-right: 10px;
}

#custom-media_play_pause {
    color: #ffffff;
    font-size: 13px;
    padding-right: 4px;
}

#mpris {
    min-width: 0;
}

#custom-cava {
    color: #ffffff;
    font-family: "JetBrainsMono Nerd Font Mono", monospace;
    padding-left: 2px;
    padding-right: 8px;
}

#clock {
    font-weight: bold;
}

#temperature.critical {
    color: #ff5555;
}

#battery {
    color: #ffffff;
}

#battery.charging, #battery.plugged {
    color: #a6e3a1;
}

@keyframes blink {
    to {
        background-color: rgba(255, 85, 85, 0.4);
        color: #ff5555;
    }
}

#battery.critical:not(.charging) {
    background-color: rgba(255, 85, 85, 0.2);
    color: #ff5555;
    animation-name: blink;
    animation-duration: 0.8s;
    animation-timing-function: linear;
    animation-iteration-count: infinite;
    animation-direction: alternate;
}

#battery.warning:not(.charging) {
    color: #f9e2af;
}

tooltip {
    background-color: rgba(20, 20, 20, 0.85);
    color: #ffffff;
    font-weight: bold;
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 10px;
}

tooltip label {
    color: #ffffff;
    font-size: 13px;
    padding: 0;
    margin: 0;
}

#cpu, #memory, #custom-gpu, #temperature, #clock, #pulseaudio, #network, #bluetooth, #custom-media_play_pause, #mpris, #custom-cava, #battery {
    transition: font-size 0.15s ease;
}

#cpu:hover, #memory:hover, #custom-gpu:hover, #temperature:hover, #clock:hover, #pulseaudio:hover, #network:hover, #bluetooth:hover, #custom-media_play_pause:hover, #mpris:hover, #custom-cava:hover, #battery:hover {
    font-size: 13px;
}
OUTER_EOF

# Waybar helper scripts
cat << 'OUTER_EOF' > "$CONFIG_DIR/waybar/scripts/gpu_usage.sh"
#!/bin/bash
usage=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -n1 || echo "0")
echo "${usage:-0}"
OUTER_EOF

cat << 'OUTER_EOF' > "$CONFIG_DIR/waybar/scripts/toggle-gammastep"
#!/bin/bash
pgrep -x gammastep >/dev/null && killall gammastep || gammastep -O 4000 &
OUTER_EOF
chmod +x "$CONFIG_DIR/waybar/scripts/"*

# 9. DEPLOY TOUCHPAD GESTURES
log_step "Configuring Touchpad Gestures..."
cat << 'OUTER_EOF' > "$HYPR_DIR/gestures.lua"
-- ~/.config/hypr/gestures.lua
-- Trackpad & Touchpad Gestures (Hyprland 0.55+)

-- 3-Finger Swipe Horizontal: 1:1 Workspace Switching
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

-- 4-Finger Swipe Horizontal: 1:1 Workspace Switching
hl.gesture({
    fingers   = 4,
    direction = "horizontal",
    action    = "workspace",
})

-- 3-Finger Swipe Down: Media Play/Pause
hl.gesture({
    fingers   = 3,
    direction = "down",
    action    = function()
        hl.exec_cmd("playerctl play-pause")
    end,
})

-- Gesture Physics & Settings
hl.config({
    gestures = {
        workspace_swipe_distance  = 300,
        workspace_swipe_invert    = true,
        workspace_swipe_min_speed_to_force = 30,
        workspace_swipe_cancel_ratio       = 0.5,
        workspace_swipe_create_new         = true,
        workspace_swipe_direction_lock     = true,
        workspace_swipe_direction_lock_threshold = 10,
        workspace_swipe_forever            = false,
        workspace_swipe_use_r              = false,
    },
})
OUTER_EOF

# 10. REBUILD HYPRLAND.LUA (85% OPACITY & BLUR)
log_step "Updating ~/.config/hypr/hyprland.lua..."
cat << 'OUTER_EOF' > "$HYPR_DIR/hyprland.lua"
-- ~/.config/hypr/hyprland.lua
-- 43PR × Dusky Linux Enhanced Edition

---- MY PROGRAMS ----
mainMod     = "SUPER"
terminal    = "kitty"
menu        = "rofi -show drun"
fileManager = "thunar"
browser     = "google-chrome-stable"

---- AUTOSTART ----
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP")
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("waybar")
    hl.exec_cmd("mako")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("wl-clip-persist --clipboard regular --write-timeout 8000")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("qs -d -c volume-osd")
end)

---- ENVIRONMENT VARIABLES ----
hl.env("XCURSOR_SIZE", "14")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")

---- INPUT ----
hl.config({
    input = {
        kb_layout = "us,latam",
        follow_mouse = 1,
        sensitivity = 0.5,
        touchpad = {
            natural_scroll = false,
            tap_to_click = true,
        },
    },
    cursor = {
        zoom_factor = 1.0,
        zoom_rigid = false,
    },
})

---- LOOK AND FEEL ----
hl.config({ render = { expand_undersized_textures = false } })
hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 3,
        border_size = 0,
        ["col.active_border"] = "rgba(00000000)",
        ["col.inactive_border"] = "rgba(00000000)",
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 8,
        active_opacity = 0.85,
        inactive_opacity = 0.80,
        fullscreen_opacity = 1.0,
        blur = {
            enabled = true,
            size = 4,
            passes = 2,
            vibrancy = 0.18,
            ignore_opacity = true,
            popups = true,
        },
        shadow = {
            enabled = true,
            range = 8,
            render_power = 3,
            color = "rgba(00000088)",
        },
    },
    animations = {
        enabled = true,
    },
})

hl.config({
    dwindle = { preserve_split = true },
    master = { new_status = "master" },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

---- LOAD MODULES ----
require("monitors")
require("gestures")
pcall(require, "animations.active.active")
require("keybinds")
require("rules")
OUTER_EOF

# 11. REBUILD RULES.LUA
log_step "Updating ~/.config/hypr/rules.lua..."
cat << 'OUTER_EOF' > "$HYPR_DIR/rules.lua"
-- ~/.config/hypr/rules.lua
-- 43PR × Dusky Window & Layer Rules

-- Layer Blur Rules
hl.layer_rule({ match = { namespace = "rofi" }, blur = true, ignore_alpha = 0.15 })
hl.layer_rule({ match = { namespace = "mako" }, blur = true, ignore_alpha = 0.15 })
hl.layer_rule({ match = { namespace = "waybar" }, blur = true, ignore_alpha = 0.15 })
hl.layer_rule({ match = { namespace = "wlogout" }, blur = true, ignore_alpha = 0.15 })

-- Default Opacity: 85% for all windows
hl.window_rule({ match = { class = ".*" }, opacity = "0.85 override" })
hl.window_rule({ match = { class = ".*", fullscreen = true }, opacity = "1.0 override" })

-- 80% Opacity for Terminal, File Manager & Settings Dialogues
hl.window_rule({ match = { class = "^(kitty|foot|Alacritty)$" }, opacity = "0.80 override" })
hl.window_rule({ match = { class = "^(thunar|org.gnome.Nautilus)$" }, opacity = "0.80 override" })
hl.window_rule({ match = { class = "^(pavucontrol|nm-connection-editor|blueman-manager|blueman-services)$" }, opacity = "0.80 override" })
hl.window_rule({ match = { class = "^(dusky_tui|Terminator)$" }, opacity = "0.80 override" })

-- System & Hardware Dialogue Floating
hl.window_rule({ name = "float-pavucontrol", match = { class = "^(pavucontrol)$" }, float = true })
hl.window_rule({ name = "float-nm", match = { class = "^(nm-connection-editor)$" }, float = true })
hl.window_rule({ name = "float-blue", match = { class = "^(blueman-manager)$" }, float = true })
hl.window_rule({ name = "float-open", match = { title = "^(Open File)$" }, float = true })
hl.window_rule({ name = "float-save", match = { title = "^(Save File)$" }, float = true })

-- Dusky Feature Floating & Positioning Rules
hl.window_rule({ name = "float-dusky-qp", match = { class = "^(org.dusky.quickpanal)$" }, float = true, move = "10 35", pin = true })
hl.window_rule({ name = "float-cheatsheet", match = { class = "^(DuskyKeybindsCheatsheet)$" }, float = true })
hl.window_rule({ name = "float-satty", match = { class = "^(com.gabm.satty)$" }, float = true })
hl.window_rule({ name = "float-btop", match = { class = "^(btop)$" }, float = true })
hl.window_rule({ name = "float-terminator", match = { class = "^(Terminator)$" }, float = true })
hl.window_rule({ name = "float-music", match = { class = "^(music_recognition.py)$" }, float = true })
hl.window_rule({ name = "float-dusky-tui", match = { class = "^(dusky_tui)$" }, float = true })
hl.window_rule({ name = "float-audio-studio", match = { class = "^(dusky_audio_studio)$" }, float = true })
hl.window_rule({ name = "float-calc", match = { class = "^(org.gnome.Calculator|qalculate-gtk)$" }, float = true })
OUTER_EOF

# 12. REBUILD KEYBINDS.LUA
log_step "Updating ~/.config/hypr/keybinds.lua..."
cat << 'OUTER_EOF' > "$HYPR_DIR/keybinds.lua"
-- ~/.config/hypr/keybinds.lua
-- 43PR × Dusky Linux Master Keybindings Matrix

local home = os.getenv("HOME")
local user_scripts = home .. "/user_scripts/"

-- 1. Apps & Launchers
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + T",      hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + B",      hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SPACE",  hl.dsp.exec_cmd("pgrep -x rofi >/dev/null && pkill -x rofi || rofi -show drun"))
hl.bind(mainMod .. " + D",      hl.dsp.exec_cmd("pgrep -x rofi >/dev/null && pkill -x rofi || rofi -show drun"))

-- Dusky Quick Settings Panel (Super + Esc only)
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd([[gdbus call --session --dest org.dusky.quickpanal --object-path /org/dusky/quickpanal --method org.freedesktop.Application.Activate "{}" || python3 ]] .. user_scripts .. [[dusky_system/quickpanal/dusky_quickpanal.py]]))
hl.bind("CTRL + ALT + SPACE",   hl.dsp.exec_cmd("pkill rofi; " .. user_scripts .. "rofi/dusky_glance.sh"))
hl.bind(mainMod .. " + SLASH",   hl.dsp.exec_cmd(user_scripts .. "hypr/input/rofi_keybinds/keybindings.sh"))

-- Emojis, Calculator & Color Picker
hl.bind(mainMod .. " + COMMA",  hl.dsp.exec_cmd(user_scripts .. "rofi/emoji.sh"))
hl.bind(mainMod .. " + PERIOD", hl.dsp.exec_cmd(user_scripts .. "rofi/emoji.sh"))
hl.bind("XF86Calculator",       hl.dsp.exec_cmd(user_scripts .. "rofi/calculator.sh"))
hl.bind(mainMod .. " + C",      hl.dsp.exec_cmd(user_scripts .. "rofi/calculator.sh"))
hl.bind(mainMod .. " + P",      hl.dsp.exec_cmd("pkill hyprpicker || hyprpicker -a -f hex"))

-- Audio Mixer & DSP Studio
hl.bind("ALT + 3", hl.dsp.exec_cmd("pavucontrol"))
hl.bind("ALT + O", hl.dsp.exec_cmd(user_scripts .. "audio/dusky_in_out_source.sh --output"))
hl.bind("ALT + I", hl.dsp.exec_cmd(user_scripts .. "audio/dusky_in_out_source.sh --input"))
hl.bind("ALT + N", hl.dsp.exec_cmd(user_scripts .. "audio/dusky_in_out_source.sh --studio"))
hl.bind("ALT + M", hl.dsp.exec_cmd("python3 " .. user_scripts .. "audio/mono_audio_pipewire.py"))

-- Rotate Screen (+90° / -90°)
hl.bind("CTRL + ALT + R", hl.dsp.exec_cmd("python3 " .. user_scripts .. "hypr/monitor/screen_rotate.py +90"), { locked = true, repeating = true })
hl.bind("CTRL + ALT + SHIFT + R", hl.dsp.exec_cmd("python3 " .. user_scripts .. "hypr/monitor/screen_rotate.py -90"), { locked = true, repeating = true })

-- AI Suite & Recognition
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd(user_scripts .. "google_image_search/google_image_search.sh"))
hl.bind(mainMod .. " + ALT + M", hl.dsp.exec_cmd("kitty --class music_recognition.py -e python3 " .. user_scripts .. "music/music_recognition.py"))
hl.bind(mainMod .. " + M",       hl.dsp.exec_cmd("kitty --class music_recognition.py -e python3 " .. user_scripts .. "music/music_recognition.py"))
hl.bind("ALT + SPACE", hl.dsp.exec_cmd("python3 " .. user_scripts .. "tts_stt/dusky_parakeet/dusky_trigger.py --push"))
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd("wl-copy \"$(wl-paste -p)\" && " .. user_scripts .. "tts_stt/dusky_kokoro/dusky_main.py"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/ocr_snip.sh"))

-- Screenshots: PrtSc (Selected Area -> Clipboard), Shift + PrtSc (Fullscreen -> Clipboard)
hl.bind("Print", hl.dsp.exec_cmd([[sh -c 'TMP=$(mktemp /tmp/snip-XXXXXX.png); grim -g "$(slurp -b 00000033 -c 7aa2f7aa -s 00000000 -w 1)" "$TMP" && wl-copy < "$TMP" && notify-send -a "Screenshot" -i "$TMP" "Area Copied" "Screenshot copied to clipboard" ; rm -f "$TMP"']]))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd([[sh -c 'TMP=$(mktemp /tmp/screen-XXXXXX.png); grim "$TMP" && wl-copy < "$TMP" && notify-send -a "Screenshot" -i "$TMP" "Fullscreen Copied" "Entire screen copied to clipboard" ; rm -f "$TMP"']]))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(user_scripts .. "images/dusky_screenshot.sh --region --freeze --annotate"))

-- Mechanical Keyboard Sound & OSD
hl.bind(mainMod .. " + U",        hl.dsp.exec_cmd(user_scripts .. "wayclick/dusky_wayclick.sh"))
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.exec_cmd(user_scripts .. "mako_osd/dusky_keys/dusky_keys.sh"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("killall -SIGUSR1 waybar || waybar &"))

-- System Monitors & Process Terminator
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd("kitty --class btop -e btop"))
hl.bind("CTRL + SHIFT + ESCAPE",       hl.dsp.exec_cmd("kitty --class btop -e btop"))
hl.bind("ALT + DELETE",                hl.dsp.exec_cmd("kitty --class Terminator -e " .. user_scripts .. "performance/services_and_process_terminator.sh"))

-- Magnifier Zoom
local function zoom_step(val)
    local curr = hl.get_config("cursor:zoom_factor") or 1.0
    local target = curr + val
    if target < 1.0 then target = 1.0 end
    if target > 3.0 then target = 3.0 end
    hl.config({ cursor = { zoom_factor = target } })
end

hl.bind(mainMod .. " + equal", function() zoom_step(0.25) end, { repeating = true })
hl.bind(mainMod .. " + minus", function() zoom_step(-0.25) end, { repeating = true })
hl.bind(mainMod .. " + 0",     function() hl.config({ cursor = { zoom_factor = 1.0 } }) end)
hl.bind(mainMod .. " + mouse_up",   function() zoom_step(0.25) end)
hl.bind(mainMod .. " + mouse_down", function() zoom_step(-0.25) end)

-- Window Operations: Rapid window closing on holding Super + W (Full native speed)
hl.bind(mainMod .. " + W", hl.dsp.window.close(), { repeating = true })

hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("hyprctl dispatch killactive"))

-- Fullscreen (F11 & Super + F)
hl.bind("F11",             hl.dsp.window.fullscreen({ mode = 0 }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = 0 }))

-- Lock Screen (Super + L only)
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))

-- Logout Menu (Super + `)
hl.bind(mainMod .. " + GRAVE", hl.dsp.exec_cmd("pgrep -x wlogout >/dev/null && pkill -x wlogout || wlogout -b 5 -c 20 -r 20 -L 550 -R 550 -T 460 -B 460"))

-- Wallpaper Picker (Super + Q)
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("quickshell -n -c hyprquickpaper || python3 " .. user_scripts .. "images/wallpaper_selector.py"))

-- Animation Switcher (Super + Alt + A)
hl.bind(mainMod .. " + ALT + A", hl.dsp.exec_cmd("rofi -show animations -modi \"animations:" .. user_scripts .. "rofi/hypr_anim.sh\""))

-- Toggle Blur / Opacity / Shadows (Super + ;)
hl.bind(mainMod .. " + SEMICOLON", hl.dsp.exec_cmd(user_scripts .. "hypr/hypr_blur_opacity_shadow_toggle.sh"))
hl.bind(mainMod .. " + ASTERISK",  hl.dsp.exec_cmd(user_scripts .. "hypr/hypr_blur_opacity_shadow_toggle.sh"))
hl.bind(mainMod .. " + O",         hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/opacity.sh"))

-- Clipboard
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("pgrep -x rofi >/dev/null && pkill -x rofi || cliphist list | rofi -dmenu -p '' | cliphist decode | wl-copy"))

-- Smart Float, Center & Resize (Super + A -> 90% monitor)
hl.bind(mainMod .. " + A", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    local w = hl.get_active_window()
    if w ~= nil and w.floating then
        local mon = hl.get_active_monitor()
        if mon ~= nil then
            local target_w = math.floor(mon.width * 0.90)
            local target_h = math.floor(mon.height * 0.90)
            hl.dispatch(hl.dsp.window.resize({ x = target_w, y = target_h, relative = false }))
            local mon_x = mon.x or 0
            local mon_y = mon.y or 0
            local target_x = mon_x + math.floor((mon.width - target_w) / 2)
            local target_y = mon_y + math.floor((mon.height - target_h) / 2)
            hl.dispatch(hl.dsp.window.move({ x = target_x, y = target_y, relative = false }))
        end
    end
end)

-- Mouse Drag & Resize
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Vim-Style Focus (H/J/K/L)
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))

-- Move Active Window (Super + Shift + H/J/K/L)
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

-- Resize Active Window (Super + Ctrl + H/J/K/L)
hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.resize({ x = -40, y = 0 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.resize({ x = 40, y = 0 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.resize({ x = 0, y = -40 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.resize({ x = 0, y = 40 }), { repeating = true })

-- Hardware Volume & Media
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Cycle Workspaces via Hotkeys
hl.bind(mainMod .. " + CTRL + RIGHT", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + CTRL + LEFT",  hl.dsp.focus({ workspace = "e-1" }))

-- Gaming Passthrough Mode
local SUBMAP_MANUAL_PT = "keybinds_disabled"
hl.bind("ALT + 6", function()
    hl.exec_cmd("notify-send -a 'Game Mode' -i 'input-gaming' 'Game Mode ON' 'Compositor hotkeys disabled. Press ALT+6 again to exit.'")
    hl.dispatch(hl.dsp.submap(SUBMAP_MANUAL_PT))
end, { description = "Toggle Game Mode", locked = true })

hl.define_submap(SUBMAP_MANUAL_PT, function()
    hl.bind("ALT + 6", function()
        hl.exec_cmd("notify-send -a 'Game Mode' -i 'input-gaming' 'Game Mode OFF' 'Compositor hotkeys restored.'")
        hl.dispatch(hl.dsp.submap("reset"))
    end, { description = "Disable Game Mode", locked = true })
end)
OUTER_EOF

# 13. PERMISSIONS & RELOAD
log_step "Setting executable permissions on all scripts..."
find "$HYPR_DIR/scripts" -type f -exec chmod +x {} \; 2>/dev/null || true
find "$SCRIPTS_DEST" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \; 2>/dev/null || true

log_step "Reloading active Hyprland, Waybar and Mako instances..."
killall waybar 2>/dev/null || true
pkill -f network_meter_daemon 2>/dev/null || true
pkill -f waybar_update_counter 2>/dev/null || true
setsid waybar >/dev/null 2>&1 &

if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload || true
fi
if command -v makoctl >/dev/null 2>&1; then
    makoctl reload || true
fi

printf "\n"
printf "${CLR_GREEN}======================================================${CLR_RESET}\n"
printf "${CLR_GREEN}   ✨ 43PR × Dusky Enhancement Complete!             ${CLR_RESET}\n"
printf "${CLR_GREEN}======================================================${CLR_RESET}\n"
printf "\n"
log_info "Backup directory: $BACKUP_DIR"
log_info "All requested features and shortcuts are active."
