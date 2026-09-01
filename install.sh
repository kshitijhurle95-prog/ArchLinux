#!/usr/bin/env bash
# ==============================================================================
# 🚀 ARCH LINUX AUTOMATED RESTORE & DEPLOYMENT SCRIPT
# ==============================================================================
# Automatically restores dotfiles, user scripts, binary helpers, systemd user
# units, and package dependencies for this custom Hyprland environment.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly USER_HOME="$HOME"
readonly CONFIG_DIR="$USER_HOME/.config"
readonly BIN_DIR="$USER_HOME/.local/bin"
readonly BACKUP_DIR="$USER_HOME/.config-backups/restore_$(date +%Y%m%d_%H%M%S)"

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
log_step() { printf "\n${CLR_CYAN}${CLR_BOLD}===> %s${CLR_RESET}\n" "$1"; }

printf "${CLR_CYAN}${CLR_BOLD}"
cat << "BANNER"
    _             _     _     _                  
   / \   _ __ ___| |__ | |   (_)_ __  _   ___  __
  / _ \ | '__/ __| '_ \| |   | | '_ \| | | \ \/ /
 / ___ \| | | (__| | | | |___| | | | | |_| |>  < 
/_/   \_\_|  \___|_| |_|_____|_|_| |_|\__,_/_/\_\
     Master Dotfiles & Customization Suite
BANNER
printf "${CLR_RESET}\n"

# 1. Package Installation Option
log_step "1. Package Dependencies Installation"
read -p "Do you want to install all missing Pacman and AUR packages? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
        log_warn "Neither 'yay' nor 'paru' was found. Installing base native packages with pacman..."
        sudo pacman -Syu --needed - < "$SCRIPT_DIR/packages/pacman_native_explicit.txt"
    else
        AUR_HELPER="yay"
        command -v paru &>/dev/null && AUR_HELPER="paru"
        log_info "Installing packages using $AUR_HELPER..."
        $AUR_HELPER -Syu --needed - < "$SCRIPT_DIR/packages/all_explicit.txt"
    fi
    log_done "Packages installed."
else
    log_info "Skipping package installation."
fi

# 2. Backup Existing Configurations
log_step "2. Backing up Existing Configurations"
mkdir -p "$BACKUP_DIR"
for item in hypr waybar wlogout mako rofi quickshell ryoku matugen gtk-3.0 gtk-4.0 kitty fish nvim Thunar; do
    if [ -d "$CONFIG_DIR/$item" ]; then
        cp -r "$CONFIG_DIR/$item" "$BACKUP_DIR/"
    fi
done
log_done "Existing configs safely backed up to $BACKUP_DIR"

# 3. Deploy Dotfiles
log_step "3. Deploying Dotfiles to ~/.config"
mkdir -p "$CONFIG_DIR"
rsync -av --exclude=".git" "$SCRIPT_DIR/dotfiles/" "$CONFIG_DIR/"

# Deploy home dotfiles
if [ -d "$SCRIPT_DIR/dotfiles/home-dotfiles" ]; then
    cp -rf "$SCRIPT_DIR/dotfiles/home-dotfiles/".* "$USER_HOME/" 2>/dev/null || true
fi
log_done "Dotfiles deployed."

# 4. Deploy User Scripts & Binaries
log_step "4. Deploying User Scripts and Helper Binaries"
mkdir -p "$USER_HOME/user_scripts"
rsync -av --exclude=".git" "$SCRIPT_DIR/user_scripts/" "$USER_HOME/user_scripts/"
find "$USER_HOME/user_scripts" -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
find "$USER_HOME/user_scripts" -type f -name "*.py" -exec chmod +x {} + 2>/dev/null || true

mkdir -p "$BIN_DIR"
if [ -d "$SCRIPT_DIR/scripts/bin" ]; then
    cp -rf "$SCRIPT_DIR/scripts/bin/"* "$BIN_DIR/"
    chmod +x "$BIN_DIR/"* 2>/dev/null || true
fi
log_done "Scripts and binary utilities deployed to $BIN_DIR and ~/user_scripts."

# 5. Deploy Desktop Entries
log_step "5. Deploying Custom Desktop Entries"
mkdir -p "$USER_HOME/.local/share/applications"
if [ -d "$SCRIPT_DIR/desktop-entries/local_share" ]; then
    cp -rf "$SCRIPT_DIR/desktop-entries/local_share/"* "$USER_HOME/.local/share/applications/" 2>/dev/null || true
    update-desktop-database "$USER_HOME/.local/share/applications" 2>/dev/null || true
fi
log_done "Desktop entries registered."

# 6. Enable Systemd User Services
log_step "6. Activating Systemd User Units"
systemctl --user daemon-reload

SERVICES=(
    "dusky_polkit.service"
    "dusky_battery.service"
    "hypridle.service"
    "hyprland-power-inhibit.service"
    "network_meter.service"
    "hypr-minimized-dock.service"
    "touchpad_gestures.service"
    "ryoku-shell.service"
    "pipewire.service"
    "pipewire-pulse.service"
    "wireplumber.service"
)

for s in "${SERVICES[@]}"; do
    if systemctl --user list-unit-files "$s" &>/dev/null; then
        systemctl --user enable "$s" 2>/dev/null || true
        systemctl --user restart "$s" 2>/dev/null || true
        log_info "Activated user service: $s"
    fi
done
log_done "All user services enabled and active."

# 7. Apply GTK / Dconf Settings
log_step "7. Applying Dconf Settings"
if [ -f "$SCRIPT_DIR/system-manifest/dconf_settings_dump.ini" ] && command -v dconf &>/dev/null; then
    dconf load / < "$SCRIPT_DIR/system-manifest/dconf_settings_dump.ini" 2>/dev/null || true
    log_done "Dconf preferences loaded."
fi

printf "\n${CLR_GREEN}${CLR_BOLD}🎉 All configurations, dotfiles, scripts, and services successfully restored!${CLR_RESET}\n"
printf "${CLR_CYAN}Please log out and log back into Hyprland to experience your complete setup.${CLR_RESET}\n\n"
