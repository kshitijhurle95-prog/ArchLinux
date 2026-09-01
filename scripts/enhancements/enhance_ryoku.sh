#!/usr/bin/env bash
# ==============================================================================
# 🚀 RYOKU SHELL × FEATURE ENHANCEMENT SUITE (MASTER DEPLOYER)
# ==============================================================================
# Upgrades a Ryoku Shell installation with all 43PR & Dusky Linux features:
# - Core Apps: Thunar file manager (80% opacity, glass blur), Mousepad/Neovim, Chrome, Kitty
# - Lockscreen: Minimal Hyprlock (SUPER + L only)
# - App Launcher: Dark Glass Rofi (SUPER + Space & SUPER + D, Bold White text, click-to-exit)
# - Wallpaper: RyoWalls with Carousel Mode integration (SUPER + Q)
# - Logout: 5 Horizontal Circular Buttons (wlogout, SUPER + `) with 100% solid white icons
# - Window Opacity: 85% general, 80% terminal/thunar/settings, borderless (0px)
# - Font Sizing: 11px Bar, 10pt Consolas Terminal
# - 12 Fluid Animation Presets (overshot workspace slides, popin 80%)
# - Screen Capture: PrtSc (subtle dark dim area -> clipboard), Shift+PrtSc (fullscreen)
# - AI Suite: Google Lens (SUPER+G), Shazam (SUPER+M), Voice Typing (ALT+SPACE), Kokoro TTS (SUPER+SHIFT+O), OCR (SUPER+SHIFT+T)
# - Hardware & Audio: Wi-Fi TUI, Bluetooth GUI, Audio Mixer, Audio In/Out Switchers (ALT+O/I), Dusky Audio Studio (ALT+N), Mono Audio (ALT+M)
# - Control & Utilities: Screen Rotation (+90°/-90°), Magnifier Zoom, Game Mode (ALT+6), Wayclick Keyboard Sounds (SUPER+U), Keystroke OSD (SUPER+SHIFT+U)
# - Glance HUD (CTRL+ALT+SPACE), Keybindings Search (SUPER+/), Calculator (XF86Calculator/SUPER+C), Emoji Picker (SUPER+./,)
# - Color Picker (SUPER+P), Process Terminator (ALT+DELETE), btop (SUPER+SHIFT+RETURN), Blur Toggle (SUPER+;)
# ==============================================================================

set -euo pipefail

readonly USER_HOME="$HOME"
readonly CONFIG_DIR="$USER_HOME/.config"
readonly HYPR_DIR="$CONFIG_DIR/hypr"
readonly SCRIPTS_DEST="$USER_HOME/user_scripts"
readonly BACKUP_DIR="$USER_HOME/.config-backups/ryoku_enhancer_$(date +%Y%m%d_%H%M%S)"

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

if [[ "${EUID}" -eq 0 ]]; then
    log_err "Do not execute this script as root/sudo. Run as normal user."
    exit 1
fi

AUR_HELPER=""
if command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
fi

printf "${CLR_BOLD}======================================================${CLR_RESET}\n"
printf "${CLR_BOLD}   Ryoku Shell × Full Feature Enhancement Suite       ${CLR_RESET}\n"
printf "${CLR_BOLD}======================================================${CLR_RESET}\n"

# 1. SAFETY BACKUP
log_step "Creating safety backup of active configurations..."
mkdir -p "$BACKUP_DIR"
for dir in hypr quickshell mako rofi wlogout kitty thunar; do
    if [[ -d "$CONFIG_DIR/$dir" ]]; then
        cp -r "$CONFIG_DIR/$dir" "$BACKUP_DIR/$dir" 2>/dev/null || true
    fi
done
log_done "Backup created at: $BACKUP_DIR"

# 2. PACKAGE INSTALLATION
log_step "Verifying and installing system packages..."
readonly REQUIRED_PKGS=(
    thunar
    thunar-archive-plugin
    thunar-volman
    file-roller
    kitty
    mako
    rofi
    wlogout
    hyprlock
    tesseract
    tesseract-data-eng
    libqalculate
    hyprpicker
    playerctl
    pavucontrol
    blueman
    networkmanager
    wireplumber
    pipewire
    pipewire-pulse
    ffmpeg
    grim
    slurp
    wl-clipboard
    brightnessctl
    cava
    pamixer
    btop
    mousepad
)

TO_INSTALL=()
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
        TO_INSTALL+=("$pkg")
    fi
done

if [[ ${#TO_INSTALL[@]} -gt 0 ]]; then
    log_info "Installing missing packages: ${TO_INSTALL[*]}"
    sudo pacman -S --needed --noconfirm "${TO_INSTALL[@]}"
else
    log_done "All required core packages are installed."
fi

if [[ -n "$AUR_HELPER" ]]; then
    readonly AUR_PKGS=(wl-clip-persist satty songrec)
    AUR_TO_INSTALL=()
    for pkg in "${AUR_PKGS[@]}"; do
        if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
            AUR_TO_INSTALL+=("$pkg")
        fi
    done
    if [[ ${#AUR_TO_INSTALL[@]} -gt 0 ]]; then
        "$AUR_HELPER" -S --needed --noconfirm "${AUR_TO_INSTALL[@]}" || true
    fi
fi

# 3. SET DEFAULT APPLICATIONS (THUNAR & MOUSEPAD)
log_step "Setting default file manager to Thunar & text editor to Mousepad..."
xdg-mime default thunar.desktop inode/directory 2>/dev/null || true
xdg-mime default thunar.desktop application/x-directory 2>/dev/null || true
xdg-mime default org.xfce.mousepad.desktop text/plain 2>/dev/null || true

# 4. DEPLOY USER SCRIPTS
log_step "Deploying utility scripts to ~/user_scripts..."
mkdir -p "$SCRIPTS_DEST"
if [[ ! -d "$SCRIPTS_DEST/music" || ! -d "$SCRIPTS_DEST/network_manager" ]]; then
    TMP_DUSKY_CLONE=$(mktemp -d)
    git clone --depth 1 https://github.com/dusklinux/dusky.git "$TMP_DUSKY_CLONE" || true
    if [[ -d "$TMP_DUSKY_CLONE/user_scripts" ]]; then
        cp -r "$TMP_DUSKY_CLONE/user_scripts/"* "$SCRIPTS_DEST/"
    fi
    rm -rf "$TMP_DUSKY_CLONE"
fi

mkdir -p "$SCRIPTS_DEST/rofi"
mkdir -p "$SCRIPTS_DEST/hypr/monitor"
mkdir -p "$SCRIPTS_DEST/google_image_search"
mkdir -p "$SCRIPTS_DEST/images"
mkdir -p "$SCRIPTS_DEST/performance"
mkdir -p "$SCRIPTS_DEST/audio"
mkdir -p "$HYPR_DIR/scripts"

# Screen Rotation
cat << 'OUTER_EOF' > "$SCRIPTS_DEST/hypr/monitor/screen_rotate.py"
#!/usr/bin/env python3
import fcntl, json, os, subprocess, sys, tempfile

def acquire_lock():
    lock_file = os.path.join(tempfile.gettempdir(), "hypr_screen_rotate.lock")
    fd = os.open(lock_file, os.O_CREAT | os.O_RDWR)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)

def main():
    acquire_lock()
    if len(sys.argv) < 2 or sys.argv[1] not in ("+90", "-90", "0", "1", "2", "3"):
        sys.exit(1)
    arg = sys.argv[1]
    monitors = json.loads(subprocess.check_output(["hyprctl", "-j", "monitors"]))
    focused = next((m for m in monitors if m.get("focused")), monitors[0] if monitors else None)
    if not focused:
        sys.exit(1)
    name = focused["name"]
    curr_t = focused.get("transform", 0)
    new_t = (curr_t + 1) % 4 if arg == "+90" else ((curr_t - 1) % 4 if arg == "-90" else int(arg))
    subprocess.run(["hyprctl", "keyword", f"monitor", f"{name},transform,{new_t}"], check=True)
    subprocess.run(["notify-send", "-a", "Display", "-i", "display", "Screen Rotated", f"{name} transformed to {new_t}"])

if __name__ == "__main__":
    main()
OUTER_EOF
chmod +x "$SCRIPTS_DEST/hypr/monitor/screen_rotate.py"

# OCR Snip Script (Subtle Dark Dim)
cat << 'OUTER_EOF' > "$HYPR_DIR/scripts/ocr_snip.sh"
#!/usr/bin/env bash
set -euo pipefail
GEOM=$(slurp -b 00000033 -c 7aa2f7aa -s 00000000 -w 1 2>/dev/null) || exit 0
TMP=$(mktemp /tmp/ocr-XXXXXX.png)
trap 'rm -f "$TMP" "${TMP}.txt"' EXIT
grim -g "$GEOM" "$TMP"
tesseract "$TMP" "$TMP" -l eng --oem 1 -c tessedit_create_txt=1 &>/dev/null
if [[ -f "${TMP}.txt" ]]; then
    cat "${TMP}.txt" | wl-copy
    TEXT_PREVIEW=$(head -n 2 "${TMP}.txt" | tr '\n' ' ' | sed 's/^[ \t]*//;s/[ \t]*$//')
    notify-send -a "OCR" -i "edit-copy" "Text Extracted & Copied" "${TEXT_PREVIEW:-Text copied to clipboard}"
else
    notify-send -a "OCR" -u critical "OCR Error" "Could not extract text from selected region."
fi
OUTER_EOF
chmod +x "$HYPR_DIR/scripts/ocr_snip.sh"

# Google Lens Script (Subtle Dark Dim)
cat << 'OUTER_EOF' > "$SCRIPTS_DEST/google_image_search/google_image_search.sh"
#!/usr/bin/env bash
set -euo pipefail
GEOM=$(slurp -b 00000033 -c 7aa2f7aa -s 00000000 -w 1 2>/dev/null) || exit 0
TMP=$(mktemp /tmp/lens-XXXXXX.png)
trap 'rm -f "$TMP"' EXIT
grim -g "$GEOM" "$TMP"
notify-send -a "Google Lens" "Uploading..." "Uploading screenshot for visual search"
RESPONSE=$(curl -sSf -F "files[]=@${TMP}" 'https://uguu.se/upload' 2>/dev/null || true)
if [[ -n "$RESPONSE" ]]; then
    URL=$(echo "$RESPONSE" | jq -r '.files[0].url // empty')
    if [[ -n "$URL" ]]; then
        xdg-open "https://lens.google.com/uploadbyurl?url=${URL}" &
        exit 0
    fi
fi
wl-copy < "$TMP"
notify-send -a "Google Lens" "Ready" "Screenshot copied. Paste (Ctrl+V) into Google Lens."
xdg-open "https://lens.google.com/" &
OUTER_EOF
chmod +x "$SCRIPTS_DEST/google_image_search/google_image_search.sh"

# 5. CONFIGURE KITTY (80% OPACITY, SOLID TEXT & FIRST-TERMINAL FASTFETCH)
log_step "Configuring Kitty terminal..."
mkdir -p "$CONFIG_DIR/kitty"
cat << 'OUTER_EOF' > "$CONFIG_DIR/kitty/kitty.conf"
font_family Consolas
font_size 10
confirm_os_window_close 0

background #000000
foreground #ffffff
background_opacity 0.80
OUTER_EOF

# First-terminal fastfetch in shell
if [[ -f "$USER_HOME/.zshrc" ]] && ! grep -q "fastfetch_session" "$USER_HOME/.zshrc"; then
    cat << 'OUTER_EOF' >> "$USER_HOME/.zshrc"

# Run fastfetch ONLY on the very first interactive terminal of the session
if [[ -o interactive ]] && [[ ! -f "/tmp/fastfetch_session_${UID}" ]]; then
    touch "/tmp/fastfetch_session_${UID}"
    if command -v fastfetch >/dev/null 2>&1; then
        fastfetch
    fi
fi
OUTER_EOF
fi

# 6. CONFIGURE CIRCULAR WLOGOUT LOGOUT MENU (100% SOLID WHITE ICONS)
log_step "Configuring circular wlogout menu..."
mkdir -p "$CONFIG_DIR/wlogout/icons"
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
    background-color: rgba(12, 12, 12, 0.6);
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
    background-color: rgba(255, 255, 255, 0.15);
    border: 1px solid #7aa2f7;
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

# 7. CONFIGURE DARK GLASS ROFI (APP LAUNCHER)
log_step "Configuring Rofi dark glass launcher..."
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

element selected.normal,
element selected.active {
    background-color: @bg-selected;
    text-color: #FFFFFF;
}

element-text selected {
    text-color: #FFFFFF;
    font: "Iosevka Bold 12";
}
EOF

# 8. CONFIGURE HYPRLOCK
log_step "Configuring Hyprlock..."
mkdir -p "$CONFIG_DIR/hypr"
cat << 'OUTER_EOF' > "$CONFIG_DIR/hypr/hyprlock.conf"
general {
    disable_loading_bar = true
    hide_cursor = true
    grace = 0
    no_fade_in = false
}

background {
    monitor =
    path = screenshot
    blur_passes = 3
    blur_size = 6
    noise = 0.0117
    contrast = 0.8916
    brightness = 0.8172
    vibrancy = 0.1696
    vibrancy_darkness = 0.0
}

input-field {
    monitor =
    size = 280, 50
    outline_thickness = 1
    dots_size = 0.25
    dots_spacing = 0.2
    dots_center = true
    outer_color = rgba(255, 255, 255, 0.15)
    inner_color = rgba(20, 20, 20, 0.65)
    font_color = rgb(255, 255, 255)
    fade_on_empty = false
    placeholder_text = <span foreground="##ffffff88">Enter Password...</span>
    hide_input = false
    position = 0, -50
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:1000] echo "$TIME"
    color = rgba(255, 255, 255, 0.95)
    font_size = 64
    font_family = JetBrainsMono Nerd Font Bold
    position = 0, 120
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:1000] date +"%A, %B %d"
    color = rgba(255, 255, 255, 0.65)
    font_size = 18
    font_family = JetBrainsMono Nerd Font
    position = 0, 50
    halign = center
    valign = center
}
OUTER_EOF

# 9. CONFIGURE HYPRLAND VIA OFFICIAL USER.LUA OVERRIDE
log_step "Deploying master configuration to $HYPR_DIR/user.lua..."
cat << 'OUTER_EOF' > "$HYPR_DIR/user.lua"
-- ~/.config/hypr/user.lua
-- 43PR × Dusky Linux Master Enhancements for Ryoku Shell

local home = os.getenv("HOME")
local user_scripts = home .. "/user_scripts/"
local mainMod = "SUPER"

-- 1. Look and Feel & Opacity
hl.config({
    general = {
        border_size = 0,
        ["col.active_border"] = "rgba(00000000)",
        ["col.inactive_border"] = "rgba(00000000)",
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
    },
})

-- Layer Blur
hl.layer_rule({ match = { namespace = "rofi" }, blur = true, ignore_alpha = 0.15 })
hl.layer_rule({ match = { namespace = "mako" }, blur = true, ignore_alpha = 0.15 })
hl.layer_rule({ match = { namespace = "wlogout" }, blur = true, ignore_alpha = 0.15 })

-- Window Rules & 80% Opacity for Terminal, Thunar, Settings
hl.window_rule({ match = { class = ".*" }, opacity = "0.85 override" })
hl.window_rule({ match = { class = ".*", fullscreen = true }, opacity = "1.0 override" })
hl.window_rule({ match = { class = "^(kitty|foot|Alacritty)$" }, opacity = "0.80 override" })
hl.window_rule({ match = { class = "^(thunar|org.gnome.Nautilus)$" }, opacity = "0.80 override" })
hl.window_rule({ match = { class = "^(pavucontrol|nm-connection-editor|blueman-manager|blueman-services)$" }, opacity = "0.80 override" })
hl.window_rule({ match = { class = "^(dusky_tui|Terminator)$" }, opacity = "0.80 override" })

-- System & Hardware Floating Rules
hl.window_rule({ name = "float-pavucontrol", match = { class = "^(pavucontrol)$" }, float = true })
hl.window_rule({ name = "float-blue", match = { class = "^(blueman-manager)$" }, float = true })
hl.window_rule({ name = "float-satty", match = { class = "^(com.gabm.satty)$" }, float = true })
hl.window_rule({ name = "float-btop", match = { class = "^(btop)$" }, float = true })
hl.window_rule({ name = "float-terminator", match = { class = "^(Terminator)$" }, float = true })
hl.window_rule({ name = "float-music", match = { class = "^(music_recognition.py)$" }, float = true })
hl.window_rule({ name = "float-calc", match = { class = "^(org.gnome.Calculator|qalculate-gtk)$" }, float = true })
hl.window_rule({ name = "float-dusky-qp", match = { class = "^(org.dusky.quickpanal)$" }, float = true, move = "10 35", pin = true })

-- 2. Core Applications
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + T",      hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + B",      hl.dsp.exec_cmd("google-chrome-stable"))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd("thunar"))
hl.bind(mainMod .. " + SPACE",  hl.dsp.exec_cmd("pgrep -x rofi >/dev/null && pkill -x rofi || rofi -show drun"))
hl.bind(mainMod .. " + D",      hl.dsp.exec_cmd("pgrep -x rofi >/dev/null && pkill -x rofi || rofi -show drun"))

-- 3. Lock Screen, Logout Menu & Wallpaper Selector
hl.bind(mainMod .. " + L",      hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + GRAVE",  hl.dsp.exec_cmd("pgrep -x wlogout >/dev/null && pkill -x wlogout || wlogout -b 5 -c 20 -r 20 -L 550 -R 550 -T 460 -B 460"))
hl.bind(mainMod .. " + Q",      hl.dsp.exec_cmd("quickshell -n -c ryowalls || quickshell -n -c hyprquickpaper || python3 " .. user_scripts .. "images/wallpaper_selector.py"))

-- 4. Screenshots (PrtSc Subtle Dim -> Clipboard, Shift+PrtSc Fullscreen -> Clipboard)
hl.bind("Print", hl.dsp.exec_cmd([[sh -c 'TMP=$(mktemp /tmp/snip-XXXXXX.png); grim -g "$(slurp -b 00000033 -c 7aa2f7aa -s 00000000 -w 1)" "$TMP" && wl-copy < "$TMP" && notify-send -a "Screenshot" -i "$TMP" "Area Copied" "Screenshot copied to clipboard" ; rm -f "$TMP"']]))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd([[sh -c 'TMP=$(mktemp /tmp/screen-XXXXXX.png); grim "$TMP" && wl-copy < "$TMP" && notify-send -a "Screenshot" -i "$TMP" "Fullscreen Copied" "Entire screen copied to clipboard" ; rm -f "$TMP"']]))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(user_scripts .. "images/dusky_screenshot.sh --region --freeze --annotate"))

-- 5. Window Operations & Ultra-Fast Rapid Closing
hl.bind(mainMod .. " + W",          hl.dsp.window.close(), { repeating = true })
hl.bind(mainMod .. " + SHIFT + W",  hl.dsp.exec_cmd("hyprctl dispatch killactive"))
hl.bind("F11",                      hl.dsp.window.fullscreen({ mode = 0 }))
hl.bind(mainMod .. " + F",          hl.dsp.window.fullscreen({ mode = 0 }))

-- 6. AI Suite & Speech Recognition
hl.bind(mainMod .. " + G",         hl.dsp.exec_cmd(user_scripts .. "google_image_search/google_image_search.sh"))
hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd("kitty --class music_recognition.py -e python3 " .. user_scripts .. "music/music_recognition.py"))
hl.bind(mainMod .. " + ALT + M",   hl.dsp.exec_cmd("kitty --class music_recognition.py -e python3 " .. user_scripts .. "music/music_recognition.py"))
hl.bind("ALT + SPACE",             hl.dsp.exec_cmd("python3 " .. user_scripts .. "tts_stt/dusky_parakeet/dusky_trigger.py --push"))
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd("wl-copy \"$(wl-paste -p)\" && " .. user_scripts .. "tts_stt/dusky_kokoro/dusky_main.py"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/ocr_snip.sh"))

-- 7. Hardware, Displays & Audio Utilities
hl.bind("ALT + 3",                 hl.dsp.exec_cmd("pavucontrol"))
hl.bind("ALT + O",                 hl.dsp.exec_cmd(user_scripts .. "audio/dusky_in_out_source.sh --output"))
hl.bind("ALT + I",                 hl.dsp.exec_cmd(user_scripts .. "audio/dusky_in_out_source.sh --input"))
hl.bind("ALT + N",                 hl.dsp.exec_cmd(user_scripts .. "audio/dusky_in_out_source.sh --studio"))
hl.bind("ALT + M",                 hl.dsp.exec_cmd("python3 " .. user_scripts .. "audio/mono_audio_pipewire.py"))
hl.bind("CTRL + ALT + R",          hl.dsp.exec_cmd("python3 " .. user_scripts .. "hypr/monitor/screen_rotate.py +90"), { locked = true, repeating = true })
hl.bind("CTRL + ALT + SHIFT + R",  hl.dsp.exec_cmd("python3 " .. user_scripts .. "hypr/monitor/screen_rotate.py -90"), { locked = true, repeating = true })

-- 8. Wayclick Keyboard Sounds & OSD
hl.bind(mainMod .. " + U",         hl.dsp.exec_cmd(user_scripts .. "wayclick/dusky_wayclick.sh"))
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.exec_cmd(user_scripts .. "mako_osd/dusky_keys/dusky_keys.sh"))

-- 9. Panels, HUDs & Cheatsheet
hl.bind(mainMod .. " + ESCAPE",    hl.dsp.exec_cmd([[gdbus call --session --dest org.dusky.quickpanal --object-path /org/dusky/quickpanal --method org.freedesktop.Application.Activate "{}" || python3 ]] .. user_scripts .. [[dusky_system/quickpanal/dusky_quickpanal.py]]))
hl.bind("CTRL + ALT + SPACE",      hl.dsp.exec_cmd("pkill rofi; " .. user_scripts .. "rofi/dusky_glance.sh"))
hl.bind(mainMod .. " + SLASH",     hl.dsp.exec_cmd(user_scripts .. "hypr/input/rofi_keybinds/keybindings.sh"))
hl.bind(mainMod .. " + ALT + A",   hl.dsp.exec_cmd("rofi -show animations -modi \"animations:" .. user_scripts .. "rofi/hypr_anim.sh\""))

-- 10. Small Utilities (Calculator, Emoji, Color Picker, Process Killer, btop, Blur Toggle)
hl.bind("XF86Calculator",          hl.dsp.exec_cmd(user_scripts .. "rofi/calculator.sh"))
hl.bind(mainMod .. " + C",         hl.dsp.exec_cmd(user_scripts .. "rofi/calculator.sh"))
hl.bind(mainMod .. " + PERIOD",    hl.dsp.exec_cmd(user_scripts .. "rofi/emoji.sh"))
hl.bind(mainMod .. " + COMMA",     hl.dsp.exec_cmd(user_scripts .. "rofi/emoji.sh"))
hl.bind(mainMod .. " + P",         hl.dsp.exec_cmd("pkill hyprpicker || hyprpicker -a -f hex"))
hl.bind("ALT + DELETE",            hl.dsp.exec_cmd("kitty --class Terminator -e " .. user_scripts .. "performance/services_and_process_terminator.sh"))
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd("kitty --class btop -e btop"))
hl.bind("CTRL + SHIFT + ESCAPE",   hl.dsp.exec_cmd("kitty --class btop -e btop"))
hl.bind(mainMod .. " + SEMICOLON", hl.dsp.exec_cmd(user_scripts .. "hypr/hypr_blur_opacity_shadow_toggle.sh"))
hl.bind(mainMod .. " + ASTERISK",  hl.dsp.exec_cmd(user_scripts .. "hypr/hypr_blur_opacity_shadow_toggle.sh"))

-- 11. Magnifier Zoom
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

-- 12. Game Mode Passthrough (ALT + 6)
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

# 10. PERMISSIONS & COMPOSITOR RELOAD
log_step "Setting permissions and reloading Hyprland..."
find "$HYPR_DIR/scripts" -type f -exec chmod +x {} \; 2>/dev/null || true
find "$SCRIPTS_DEST" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \; 2>/dev/null || true

killall waybar 2>/dev/null || true
systemctl --user stop voxtype.service 2>/dev/null || true
systemctl --user disable voxtype.service 2>/dev/null || true

if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload || true
fi

printf "\n"
printf "${CLR_GREEN}======================================================${CLR_RESET}\n"
printf "${CLR_GREEN}   ✨ All Enhancements & Keybinds Active on Ryoku!   ${CLR_RESET}\n"
printf "${CLR_GREEN}======================================================${CLR_RESET}\n"
printf "\n"
log_info "Backup directory: $BACKUP_DIR"
