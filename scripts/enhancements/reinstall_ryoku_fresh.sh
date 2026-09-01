#!/usr/bin/env bash
# ==============================================================================
# 🧹 PURGE & CLEAN REINSTALL RYOKU SHELL FROM ZERO (NO LEFTOVERS)
# ==============================================================================
set -euo pipefail

readonly USER_HOME="$HOME"
readonly REPO_DIR="$USER_HOME/ryoku-arch"

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

printf "${CLR_BOLD}======================================================${CLR_RESET}\n"
printf "${CLR_BOLD}   Ryoku Shell: Full Clean Wipe & Zero Reinstall      ${CLR_RESET}\n"
printf "${CLR_BOLD}======================================================${CLR_RESET}\n"

# 1. TERMINATE ALL RUNNING SHELL INSTANCES & SERVICES
log_step "Terminating active Ryoku and Quickshell processes..."
systemctl --user stop ryoku-shell 2>/dev/null || true
systemctl --user stop ryoku-ai-usage.timer 2>/dev/null || true
systemctl --user stop ryoku-ai-usage.service 2>/dev/null || true
systemctl --user stop ryoku-rashin.service 2>/dev/null || true
systemctl --user stop voxtype.service 2>/dev/null || true

killall -9 ryoku-shell quickshell qs ryoku-livewall waybar 2>/dev/null || true
pkill -f "qs -c" 2>/dev/null || true
sleep 0.5
log_done "Active processes terminated."

# 2. COMPLETE PURGE OF RYOKU & DESKTOP CONFIGS
log_step "Purging all Ryoku directories, configs, caches, and state..."
rm -rf "$USER_HOME/.config/hypr" \
       "$USER_HOME/.config/quickshell" \
       "$USER_HOME/.config/ryoku" \
       "$USER_HOME/.config/matugen" \
       "$USER_HOME/.config/rofi" \
       "$USER_HOME/.config/wlogout" \
       "$USER_HOME/.config/mako" \
       "$USER_HOME/.config/gtk-3.0" \
       "$USER_HOME/.config/gtk-4.0" \
       "$USER_HOME/.config/qt6ct" \
       "$USER_HOME/.local/share/ryoku" \
       "$USER_HOME/.local/state/ryoku" \
       "$USER_HOME/.cache/ryoku" \
       "$USER_HOME/.local/lib/qt6/qml/Ryoku" \
       "$USER_HOME/.local/lib/hyprland/plugins" \
       "$USER_HOME/.local/bin/ryoku"* \
       "$USER_HOME/.local/bin/rashin" \
       "$USER_HOME/.local/bin/ryostore"* \
       "$USER_HOME/.config/systemd/user/ryoku"* 2>/dev/null || true

log_done "Complete purge finished. Zero leftover files."

# 3. VERIFY REPOSITORY SOURCE
log_step "Checking Ryoku source repository..."
if [[ ! -d "$REPO_DIR" ]]; then
    log_info "Cloning fresh ryoku-arch repository..."
    git clone --depth 1 https://github.com/neur0map/ryoku-arch.git "$REPO_DIR"
else
    log_info "Using local ryoku-arch repository at $REPO_DIR"
fi

# 4. DEPLOY FRESH STOCK RYOKU FROM ZERO
log_step "Installing clean stock Ryoku desktop files..."
mkdir -p "$USER_HOME/.config/hypr" \
         "$USER_HOME/.config/quickshell" \
         "$USER_HOME/.config/matugen" \
         "$USER_HOME/.config/ryoku" \
         "$USER_HOME/.local/bin" \
         "$USER_HOME/.local/share/applications" \
         "$USER_HOME/.local/share/icons"

cp -r "$REPO_DIR/ryoku/hyprland/"* "$USER_HOME/.config/hypr/"
cp -r "$REPO_DIR/ryoku/shell/quickshell/"* "$USER_HOME/.config/quickshell/"
cp -r "$REPO_DIR/ryoku/shell/matugen/"* "$USER_HOME/.config/matugen/"

mkdir -p "$USER_HOME/.config/quickshell/hub"
cp -r "$REPO_DIR/ryoku/hub/quickshell/"* "$USER_HOME/.config/quickshell/hub/"

for app in ryostore ryowalls ryovm ryotunes; do
    if [[ -d "$REPO_DIR/ryoku/apps/$app/quickshell" ]]; then
        mkdir -p "$USER_HOME/.config/quickshell/$app"
        cp -r "$REPO_DIR/ryoku/apps/$app/quickshell/"* "$USER_HOME/.config/quickshell/$app/"
    fi
done

# Copy core ryoku helper scripts to ~/.local/bin
cp "$REPO_DIR/ryoku/hyprland/scripts/ryoku-"* "$USER_HOME/.local/bin/" 2>/dev/null || true
chmod +x "$USER_HOME/.local/bin/ryoku-"* 2>/dev/null || true

# 5. INITIALIZE STOCK STATE
cat << 'SHELL_JSON' > "$USER_HOME/.config/ryoku/shell.json"
{
    "barStyle": "qsbar",
    "fontFamily": "JetBrainsMono Nerd Font",
    "fontScale": 1.0,
    "frameEnabled": true
}
SHELL_JSON

# 6. RELOAD COMPOSITOR & LAUNCH CLEAN SHELL
log_step "Reloading Hyprland and restarting shell..."
if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload || true
fi

nohup /usr/bin/ryoku-shell daemon >/dev/null 2>&1 &

printf "\n"
printf "${CLR_GREEN}======================================================${CLR_RESET}\n"
printf "${CLR_GREEN}   ✅ Ryoku Shell Reinstalled Cleanly from Zero!     ${CLR_RESET}\n"
printf "${CLR_GREEN}======================================================${CLR_RESET}\n"
printf "\n"
printf "${CLR_BOLD}To apply all 43PR features, opacities, apps & AI tools, run:${CLR_RESET}\n"
printf "  ${CLR_CYAN}~/enhance_ryoku.sh${CLR_RESET}\n\n"
