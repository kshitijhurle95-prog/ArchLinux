#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
#  wlogout-launch - Dynamic Scaling & Circular Icon-Only Wrapper for Hyprland
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ──────────────────────────────────────────────────────────────
# 1. Configuration & Constants
# ──────────────────────────────────────────────────────────────
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wlogout"
readonly LAYOUT_FILE="${CONFIG_DIR}/layout"
readonly ICON_DIR="${CONFIG_DIR}/icons"
TMP_CSS=""
WLOGOUT_PID=""

# Reference: 1080p @ 1.0 scale settings
readonly REF_WIDTH=1920
readonly REF_HEIGHT=1080
readonly BASE_BTN_SIZE=150
readonly BASE_COL_SPACING=28
readonly BASE_ICON_SIZE=54

# ──────────────────────────────────────────────────────────────
# 2. Strict Environment & Dependency Validation
# ──────────────────────────────────────────────────────────────
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    echo "ERROR: Not running inside a Hyprland session." >&2
    exit 1
fi

if [[ -z "${XDG_RUNTIME_DIR:-}" || ! -d "$XDG_RUNTIME_DIR" || ! -w "$XDG_RUNTIME_DIR" ]]; then
    echo "ERROR: XDG_RUNTIME_DIR is not available or writable. Session is fundamentally broken." >&2
    exit 1
fi

readonly RUNTIME_DIR="$XDG_RUNTIME_DIR"
readonly LOCK_FILE="${RUNTIME_DIR}/wlogout-launch-${HYPRLAND_INSTANCE_SIGNATURE}.lock"
readonly PID_FILE="${RUNTIME_DIR}/wlogout-launch-${HYPRLAND_INSTANCE_SIGNATURE}.pid"

for cmd in hyprctl jq wlogout flock mktemp grep awk; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: Required command '$cmd' not found in PATH." >&2
        exit 1
    fi
done

if [[ ! -f "$LAYOUT_FILE" ]]; then
    echo "ERROR: Layout file not found at $LAYOUT_FILE" >&2
    exit 1
fi

# ──────────────────────────────────────────────────────────────
# 3. Lifecycle Management (Traps & Cleanup)
# ──────────────────────────────────────────────────────────────
cleanup() {
    [[ -n "${TMP_CSS:-}" && -f "$TMP_CSS" ]] && rm -f -- "$TMP_CSS"

    if [[ -n "${WLOGOUT_PID:-}" && -f "$PID_FILE" ]]; then
        local recorded_pid="" recorded_css=""
        read -r recorded_pid recorded_css < "$PID_FILE" 2>/dev/null || true
        if [[ "$recorded_pid" == "$WLOGOUT_PID" && "$recorded_css" == "$TMP_CSS" ]]; then
            rm -f -- "$PID_FILE"
        fi
    fi
}
trap cleanup EXIT

# ──────────────────────────────────────────────────────────────
# 4. Concurrency & Toggle Logic (The Sniper Engine)
# ──────────────────────────────────────────────────────────────
exec {LOCK_FD}> "$LOCK_FILE"
flock -x "$LOCK_FD"

if [[ -f "$PID_FILE" ]]; then
    existing_pid=""
    existing_css=""
    read -r existing_pid existing_css < "$PID_FILE" 2>/dev/null || true

    if [[ "$existing_pid" =~ ^[0-9]+$ ]] && [[ -n "$existing_css" ]]; then
        if kill -0 "$existing_pid" 2>/dev/null \
           && [[ -r "/proc/${existing_pid}/comm" ]] \
           && [[ -r "/proc/${existing_pid}/cmdline" ]]; then
            
            read -r existing_comm < "/proc/${existing_pid}/comm" 2>/dev/null || existing_comm=""
            
            if [[ "$existing_comm" == "wlogout" ]] && grep -zFq -- "$existing_css" "/proc/${existing_pid}/cmdline"; then
                kill "$existing_pid" 2>/dev/null || true
                rm -f -- "$PID_FILE"
                
                flock -u "$LOCK_FD"
                exec {LOCK_FD}>&-
                exit 0
            fi
        fi
    fi
    rm -f -- "$PID_FILE"
fi

# ──────────────────────────────────────────────────────────────
# 5. Asset Generation & Geometry Calculation
# ──────────────────────────────────────────────────────────────
TMP_CSS=$(mktemp --tmpdir="$RUNTIME_DIR" --suffix=.css "wlogout-${HYPRLAND_INSTANCE_SIGNATURE}.XXXXXX")

MON_DATA=""
if MON_DATA=$(hyprctl monitors -j 2>/dev/null | jq -r '
    (first(.[] | select(.focused)) // .[0] // {width: 1920, height: 1080, scale: 1})
    | "\(.width) \(.height) \(.scale)"
') && [[ -n "$MON_DATA" ]]; then
    :
else
    MON_DATA="1920 1080 1"
fi

read -r WIDTH HEIGHT SCALE <<< "$MON_DATA"

if [[ "$SCALE" == "0" || "$SCALE" == "0.0" || -z "$SCALE" ]]; then
    SCALE=1
fi

CALC_VARS=$(awk -v w="$WIDTH" -v h="$HEIGHT" -v s="$SCALE" \
                -v rw="$REF_WIDTH" -v rh="$REF_HEIGHT" \
                -v bs="$BASE_BTN_SIZE" -v cs="$BASE_COL_SPACING" \
                -v is="$BASE_ICON_SIZE" '
BEGIN {
    eff_w = int(w / s);
    eff_h = int(h / s);
    ratio = eff_h / rh;
    if (ratio < 0.5) ratio = 0.5;
    if (ratio > 2.0) ratio = 2.0;

    btn_size = int(bs * ratio);
    col_spacing = int(cs * ratio);
    icon_size = int(is * ratio);
    hover_icon_size = int(icon_size * 1.08);

    num_buttons = 5;
    total_grid_w = (num_buttons * btn_size) + ((num_buttons - 1) * col_spacing);
    margin_l = int((eff_w - total_grid_w) / 2);
    margin_r = eff_w - total_grid_w - margin_l;

    margin_t = int((eff_h - btn_size) / 2);
    margin_b = eff_h - btn_size - margin_t;

    if (margin_l < 0) margin_l = 0;
    if (margin_r < 0) margin_r = 0;
    if (margin_t < 0) margin_t = 0;
    if (margin_b < 0) margin_b = 0;

    printf "%d %d %d %d %d %d %d %d",
        icon_size, hover_icon_size, col_spacing,
        margin_l, margin_r, margin_t, margin_b, btn_size
}')

read -r ICON_SIZE HOVER_ICON_SIZE COL_SPACING MARGIN_L MARGIN_R MARGIN_T MARGIN_B BTN_SIZE <<< "$CALC_VARS"

cat > "$TMP_CSS" << CSSEOF
* {
    background-image: none;
    box-shadow: none;
    outline: none;
    outline-style: none;
}

window {
    background-color: rgba(0, 0, 0, 0.65);
}

button {
    background-color: rgba(30, 30, 30, 0.60);
    border: 2.5px solid #FFFFFF;
    border-radius: 9999px;
    color: transparent;
    font-size: 0px;
    background-repeat: no-repeat;
    background-position: center;
    background-size: __ICON_SIZE__px;
    padding: 0;
    margin: 0;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
    transition: background-color 0.2s cubic-bezier(0.16, 1, 0.3, 1),
                box-shadow 0.2s cubic-bezier(0.16, 1, 0.3, 1),
                border-color 0.2s cubic-bezier(0.16, 1, 0.3, 1),
                background-size 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}

button:focus,
button:active,
button:hover {
    background-color: rgba(255, 255, 255, 0.25);
    border: 2.5px solid #FFFFFF;
    box-shadow: 0 0 25px rgba(255, 255, 255, 0.45);
    background-size: __HOVER_ICON_SIZE__px;
    outline: none;
    outline-style: none;
}

#shutdown {
    background-image: image(url("__ICON_DIR__/shutdown.png"), url("__ICON_DIR__/shutdown_white.png"), url("/usr/share/wlogout/icons/shutdown.png"));
}

#reboot {
    background-image: image(url("__ICON_DIR__/reboot.png"), url("__ICON_DIR__/reboot_white.png"), url("/usr/share/wlogout/icons/reboot.png"));
}

#lock {
    background-image: image(url("__ICON_DIR__/lock.png"), url("__ICON_DIR__/lock_white.png"), url("/usr/share/wlogout/icons/lock.png"));
}

#hibernate {
    background-image: image(url("__ICON_DIR__/hibernate.png"), url("__ICON_DIR__/hibernate_white.png"), url("__ICON_DIR__/suspend.png"));
}

#suspend {
    background-image: image(url("__ICON_DIR__/suspend.png"), url("__ICON_DIR__/suspend_white.png"), url("/usr/share/wlogout/icons/suspend.png"));
}

#logout {
    background-image: image(url("__ICON_DIR__/logout.png"), url("__ICON_DIR__/logout_white.png"), url("/usr/share/wlogout/icons/logout.png"));
}
CSSEOF

sed -i \
    -e "s|__ICON_SIZE__|${ICON_SIZE}|g" \
    -e "s|__HOVER_ICON_SIZE__|${HOVER_ICON_SIZE}|g" \
    -e "s|__ICON_DIR__|${ICON_DIR}|g" \
    "$TMP_CSS"

# ──────────────────────────────────────────────────────────────
# 6. Launch & Daemonize
# ──────────────────────────────────────────────────────────────
wlogout \
    --layout "$LAYOUT_FILE" \
    --css "$TMP_CSS" \
    --protocol layer-shell \
    --buttons-per-row 5 \
    --column-spacing "$COL_SPACING" \
    --row-spacing 0 \
    -L "$MARGIN_L" \
    -R "$MARGIN_R" \
    -T "$MARGIN_T" \
    -B "$MARGIN_B" \
    "$@" &
WLOGOUT_PID=$!

printf "%s %s\n" "$WLOGOUT_PID" "$TMP_CSS" > "$PID_FILE"

flock -u "$LOCK_FD"
exec {LOCK_FD}>&-

wait "$WLOGOUT_PID"
