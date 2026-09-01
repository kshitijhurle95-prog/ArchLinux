-- ~/.config/hypr/user.lua
-- 43PR × Dusky Linux Master Enhancements for Ryoku Shell
-- All features from 43PR/dotfiles + dusklinux/dusky ported to Ryoku

local home = os.getenv("HOME")
local user_scripts = home .. "/user_scripts/"
local mainMod = "SUPER"

-- ═══════════════════════════════════════════════════════════════════════════
-- 0. DISABLE RYOKU DEFAULTS (Capture, Launcher, File Manager, Brand)
--    These unbinds remove Ryoku's built-in modules so 43PR versions replace them.
-- ═══════════════════════════════════════════════════════════════════════════

-- Unbind Ryoku's built-in capture (ryoshot)
hl.unbind(mainMod .. " + SHIFT + S")
hl.unbind("Print")
hl.unbind("SHIFT + Print")

-- Unbind Ryoku's built-in launcher (ryoku:launcher)
hl.unbind(mainMod .. " + Space")

-- Unbind Ryoku's built-in file manager (ryoku-app files)
hl.unbind(mainMod .. " + E")

-- Unbind Ryoku's built-in lock (ryoku-shell lock)
hl.unbind(mainMod .. " + L")

-- Unbind Ryoku's built-in terminal (ryoku-app terminal)
hl.unbind(mainMod .. " + Return")

-- Unbind Ryoku's built-in browser (ryoku-app browser)
hl.unbind(mainMod .. " + B")

-- Unbind Ryoku's built-in clipboard (ryoku:clipboard)
hl.unbind(mainMod .. " + V")

-- Unbind Ryoku's built-in wallpaper (ryoku:wallpaper-menu)
hl.unbind(mainMod .. " + W")

-- Unbind Ryoku's built-in close window (SUPER+Q) - windows close only with SUPER+W
hl.unbind(mainMod .. " + Q")

-- Unbind Ryoku's built-in random wallpaper (SUPER+SHIFT+W)
hl.unbind(mainMod .. " + SHIFT + W")

-- Unbind Ryoku's built-in session/logout
hl.unbind(mainMod .. " + Escape")

-- Unbind Ryoku's visualizer from SUPER+M (conflicts with Music Recognition)
hl.unbind(mainMod .. " + M")
hl.unbind(mainMod .. " + SHIFT + M")

-- Unbind Ryoku's built-in color picker (conflicts with SUPER+P)
hl.unbind(mainMod .. " + SHIFT + C")

-- Unbind Ryoku's settings (SUPER+comma conflicts with Emoji Picker)
hl.unbind(mainMod .. " + comma")

-- Unbind Ryoku's built-in stash sidebar (SUPER+S)
hl.unbind(mainMod .. " + S")

-- Unbind Ryoku's voice (SUPER+GRAVE conflicts with wlogout)
hl.unbind(mainMod .. " + grave")

-- Bind Ryoku's overview (Mission Control) to SUPER+Tab, F3, and CTRL+Up
hl.bind(mainMod .. " + Tab", hl.dsp.global("ryoku:overview"))
hl.bind("F3", hl.dsp.global("ryoku:overview"))
hl.bind("CTRL + Up", hl.dsp.global("ryoku:overview"))

-- Unbind Ryoku's scratchpad binds (SUPER+H/J conflict with window focus)
hl.unbind(mainMod .. " + H")
hl.unbind(mainMod .. " + J")

-- Set monitor scale to 1 (43PR default — no fractional scaling)
local monitors = hl.get_monitors and hl.get_monitors() or {}
if #monitors > 0 then
    for _, mon in ipairs(monitors) do
        if mon.name and mon.name ~= "" then
            hl.monitor({ output = mon.name, mode = "preferred", position = "auto", scale = 1 })
        end
    end
else
    hl.monitor({ output = "eDP-1", mode = "1920x1080@144", position = "auto", scale = 1 })
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. WINDOW STYLING, FONTS & COMPOSITOR OPACITY
-- ═══════════════════════════════════════════════════════════════════════════

-- Environment variables
hl.env("XCURSOR_SIZE", "18")
hl.env("HYPRCURSOR_SIZE", "18")

-- Core look & feel
hl.config({
    general = {
        border_size = 0,
        ["col.active_border"] = "rgba(00000000)",
        ["col.inactive_border"] = "rgba(00000000)",
        gaps_in = 3,
        gaps_out = 5,
        resize_on_border = true,
    },
    decoration = {
        rounding = 8,
        active_opacity = 0.85,
        inactive_opacity = 0.85,
        fullscreen_opacity = 1.0,
        dim_special = 0.3,
        shadow = {
            enabled = true,
            range = 15,
            render_power = 2,
            color = 0x66000000,
        },
        blur = {
            enabled = true,
            size = 3,
            passes = 2,
            brightness = 1.08,
            contrast = 1.05,
            vibrancy = 0.35,
            vibrancy_darkness = 0.05,
            noise = 0.015,
            new_optimizations = true,
            ignore_opacity = true,
            popups = true,
            special = true,
        },
    },
    input = {
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
            tap_button_map = "lrm",
        },
    },
    gestures = {
        workspace_swipe_distance = 200,
        workspace_swipe_invert = false,
        workspace_swipe_cancel_ratio = 0.2,
        workspace_swipe_create_new = true,
        workspace_swipe_direction_lock = true,
        workspace_swipe_min_speed_to_force = 10,
        workspace_swipe_touch = true,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
    },
})

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. FLUID ANIMATIONS (Clean & Smooth — No Bounce Effect)
-- ═══════════════════════════════════════════════════════════════════════════

-- Smooth curves without overshoot/bounce
hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("smoothLinear", { type = "bezier", points = { {0.25, 1.0}, {0.5, 1.0} } })

-- Animations: Crisp & smooth
hl.animation({ leaf = "global",              enabled = true, speed = 4, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",             enabled = true, speed = 4, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "windowsOut",          enabled = true, speed = 3, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "fade",                enabled = true, speed = 4, bezier = "smoothLinear" })
hl.animation({ leaf = "workspaces",          enabled = true, speed = 5, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 4, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slide" })

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. LAYER BLUR RULES
-- ═══════════════════════════════════════════════════════════════════════════

hl.layer_rule({ match = { namespace = "rofi" },    blur = true, ignore_alpha = 0.15 })
hl.layer_rule({ match = { namespace = "mako" },    blur = true, ignore_alpha = 0.15 })
hl.layer_rule({ match = { namespace = "wlogout" }, blur = true, ignore_alpha = 0.15 })

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. WINDOW RULES & OPACITY OVERRIDES
-- ═══════════════════════════════════════════════════════════════════════════

-- Global 85% active / 85% inactive
hl.window_rule({ match = { class = ".*" }, opacity = "0.85 override 0.85 override" })
hl.window_rule({ match = { class = ".*", fullscreen = true }, opacity = "1.0 override 1.0 override" })

-- Terminals: 1.0 window surface with native 85% background transparency so text is 100% solid
hl.window_rule({ match = { class = "^(kitty|foot|Alacritty|ghostty|com.mitchellh.ghostty|dusky_tui|Terminator)$" }, opacity = "1.0 override 1.0 override" })

-- File managers: 85%
hl.window_rule({ match = { class = "^(thunar|org.gnome.Nautilus|org.kde.dolphin|nemo)$" }, opacity = "0.85 override 0.85 override" })

-- Text Editors: 85%
hl.window_rule({ match = { class = "^(xed|gedit|dev.zed.Zed|VSCodium|Code|code-oss|mousepad)$" }, opacity = "0.85 override 0.85 override" })

-- Calculators: 85%
hl.window_rule({ match = { class = "^(org.gnome.Calculator|qalculate-gtk|kcalc)$" }, opacity = "0.85 override 0.85 override" })

-- Hardware/Settings apps: 85% opacity with blur
hl.window_rule({ match = { class = "^(pavucontrol|nm-connection-editor|blueman-manager|blueman-services|org.gnome.Settings|systemsettings)$" }, opacity = "0.85 override 0.85 override" })
hl.window_rule({ match = { title = "^(Ryoku Settings)$" }, opacity = "0.85 override 0.85 override" })
hl.window_rule({ match = { class = "^(org.quickshell)$", title = "^(Ryoku Settings)$" }, opacity = "0.85 override 0.85 override" })
hl.window_rule({ match = { class = "^(dusky_tui|Terminator)$" }, opacity = "0.85 override 0.85 override" })

-- Web Browsers: 85% opacity
hl.window_rule({ match = { class = "^(google-chrome|google-chrome-stable|chromium|Chromium|firefox|Firefox|Brave-browser|zen-browser|zen|floorp|Thorium-browser)$" }, opacity = "0.85 override 0.85 override" })

-- Media Players, Image Viewers & Games: strictly 100% solid/opaque
hl.window_rule({ match = { class = "^(mpv|vlc|eog|imv|feh|loupe|celluloid|totem|com.gabm.satty|looking-glass-client|steam|steam_app_.*|gamescope)$" }, opacity = "1.0 override 1.0 override", opaque = true })

-- Floating rules for system/hardware utilities
hl.window_rule({ name = "float-ryoku-settings", match = { title = "^(Ryoku Settings)$" }, float = true, size = { 1360, 880 }, center = true })
hl.window_rule({ name = "float-pavucontrol", match = { class = "^(pavucontrol)$" }, float = true })
hl.window_rule({ name = "float-blue", match = { class = "^(blueman-manager)$" }, float = true })
hl.window_rule({ name = "float-satty", match = { class = "^(com.gabm.satty)$" }, float = true })
hl.window_rule({ name = "float-btop", match = { class = "^(btop)$" }, float = true })
hl.window_rule({ name = "float-terminator", match = { class = "^(Terminator)$" }, float = true })
hl.window_rule({ name = "float-music", match = { class = "^(music_recognition.py)$" }, float = true })
hl.window_rule({ name = "float-calc", match = { class = "^(org.gnome.Calculator|qalculate-gtk)$" }, float = true })

-- Suppress maximize events
hl.window_rule({ name = "suppress-maximize-events", match = { class = ".*" }, suppress_event = "maximize" })

-- Picture-in-Picture
hl.window_rule({
    match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float = true,
    keep_aspect_ratio = true,
    pin = true,
})

-- Float common modals
hl.window_rule({ match = { title = "^(Open|Authentication Required|Add Folder to Workspace|Choose Files|Save As|Confirm to replace files|File Operation Progress)$" }, float = true })
hl.window_rule({ match = { initial_title = "^(Open File)$" }, float = true })
hl.window_rule({ match = { class = "^([Xx]dg-desktop-portal-gtk)$" }, float = true })
hl.window_rule({ match = { title = "^(File Upload|Choose wallpaper|Library)(.*)$" }, float = true })

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. CORE APPLICATION LAUNCHERS
-- ═══════════════════════════════════════════════════════════════════════════

-- Terminal (Kitty)
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + T",      hl.dsp.exec_cmd("kitty"))

-- Web Browser (Google Chrome)
hl.bind(mainMod .. " + B",      hl.dsp.exec_cmd("google-chrome-stable"))

-- File Manager (Thunar)
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd("thunar"))

-- App Launcher (Rofi Dark Glass)
hl.bind(mainMod .. " + space",  hl.dsp.exec_cmd("pgrep -x rofi >/dev/null && pkill -x rofi || rofi -show drun"))
hl.bind(mainMod .. " + D",      hl.dsp.exec_cmd("pgrep -x rofi >/dev/null && pkill -x rofi || rofi -show drun"))

-- Quick Settings / Control Center (Ryoku Default on SUPER+ESC)
hl.bind(mainMod .. " + Escape", hl.dsp.global("ryoku:quicksettings"))

-- Ryoku Settings / Configuration (SUPER+I)
hl.bind(mainMod .. " + I",      hl.dsp.exec_cmd("ryoku-shell hub open"))

-- System Activity Monitor (btop)
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd("kitty --class btop -e btop"))

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. LOCKSCREEN, LOGOUT MENU & WALLPAPER SELECTOR
-- ═══════════════════════════════════════════════════════════════════════════

-- Lock Screen (Default Ryoku Lockscreen)
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("ryoku-shell lock"))

-- Logout Menu (wlogout circular)
hl.bind(mainMod .. " + grave", hl.dsp.exec_cmd("pgrep -x wlogout >/dev/null && pkill -x wlogout || wlogout -b 5 -c 20 -r 20 -L 550 -R 550 -T 460 -B 460"))

-- Wallpaper & Theme Selector (Wallpaper, Live Wallpapers & Theme Palettes on SUPER+Q ONLY)
hl.bind(mainMod .. " + Q", hl.dsp.global("ryoku:wallpaper-menu"))

-- Autostart 4-Finger Touchpad Gesture Daemon
hl.exec_cmd("pkill -f gesture_daemon.py; python3 " .. user_scripts .. "hypr/input/gesture_daemon.py &")

-- ═══════════════════════════════════════════════════════════════════════════
-- 7. SCREENSHOTS & SCREEN CAPTURE SUITE (43PR Defaults)
-- ═══════════════════════════════════════════════════════════════════════════

-- PrtSc: Snip Area → Clipboard (subtle dark tint slurp)
hl.bind("Print", hl.dsp.exec_cmd([[sh -c 'TMP=$(mktemp /tmp/snip-XXXXXX.png); grim -g "$(slurp -b 00000033 -c 7aa2f7aa -s 00000000 -w 1)" "$TMP" && wl-copy < "$TMP" && notify-send -a "Screenshot" -i "$TMP" "Area Copied" "Screenshot copied to clipboard" ; rm -f "$TMP"']]))

-- Shift+PrtSc: Fullscreen → Clipboard
hl.bind("SHIFT + Print", hl.dsp.exec_cmd([[sh -c 'TMP=$(mktemp /tmp/screen-XXXXXX.png); grim "$TMP" && wl-copy < "$TMP" && notify-send -a "Screenshot" -i "$TMP" "Fullscreen Copied" "Entire screen copied to clipboard" ; rm -f "$TMP"']]))

-- SUPER+SHIFT+S: Annotated Screenshot (Satty freeze-frame editor)
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(user_scripts .. "images/dusky_screenshot.sh --region --freeze --annotate"))

-- SUPER+SHIFT+T: OCR Text Snip (Tesseract → Clipboard)
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd([[sh -c 'GEOM=$(slurp -b 00000033 -c 7aa2f7aa -s 00000000 -w 1 2>/dev/null) || exit 0; TMP=$(mktemp /tmp/ocr-XXXXXX.png); trap "rm -f $TMP" EXIT; grim -g "$GEOM" "$TMP"; TEXT=$(tesseract "$TMP" - 2>/dev/null); if [ -n "$TEXT" ]; then printf "%s" "$TEXT" | wl-copy; notify-send -a "OCR" "Text Extracted" "$TEXT"; else notify-send -a "OCR" "No Text Found" "Could not extract text from selection"; fi']]))

-- SUPER+G: Google Lens Visual Search (snip → reverse image search)
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd(user_scripts .. "google_image_search/google_image_search.sh"))

-- ═══════════════════════════════════════════════════════════════════════════
-- 8. WINDOW OPERATIONS, FLOAT, CLOSE & MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════

-- Close window (ONLY SUPER + W)
hl.bind(mainMod .. " + W",          hl.dsp.window.close(), { repeating = true })

-- ── Fullscreen & Maximize Management ──────────────────────────────────────
-- F11: Fully maximize (occupies entire screen, 100% opacity, Esc/F11 restores to normal)
-- Shift+F11: Pure fullscreen (mode 0, 100% opacity, Esc/Shift+F11 restores to normal)
-- Esc: Dynamically bound ONLY when active window is fullscreen/maximized
local fs_floating_map = {}
local escape_is_bound = false

local function set_fs_escape_bound(bound)
    if bound and not escape_is_bound then
        local ok = pcall(function()
            hl.bind("Escape", function()
                local cur = hl.get_active_window()
                if cur and cur.fullscreen and cur.fullscreen ~= 0 then
                    hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set", window = cur }))
                    if fs_floating_map[cur.address] then
                        hl.dispatch(hl.dsp.window.float({ action = "on", window = cur }))
                        fs_floating_map[cur.address] = nil
                    end
                    set_fs_escape_bound(false)
                else
                    set_fs_escape_bound(false)
                end
            end)
        end)
        if ok then escape_is_bound = true end
    elseif not bound and escape_is_bound then
        local ok = pcall(function()
            hl.unbind("Escape")
        end)
        if ok then escape_is_bound = false end
    end
end

local function sync_fs_escape_state()
    local cur = hl.get_active_window()
    if cur and cur.fullscreen and cur.fullscreen ~= 0 then
        set_fs_escape_bound(true)
    else
        set_fs_escape_bound(false)
    end
end

local function toggle_maximize_window(w)
    local win = w or hl.get_active_window()
    if not win or not win.address then return end
    if win.fullscreen and win.fullscreen ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set", window = win }))
        if fs_floating_map[win.address] then
            hl.dispatch(hl.dsp.window.float({ action = "on", window = win }))
            fs_floating_map[win.address] = nil
        end
        set_fs_escape_bound(false)
    else
        if win.floating then
            fs_floating_map[win.address] = true
        else
            fs_floating_map[win.address] = nil
        end
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 2, client = 0, action = "set", window = win }))
        set_fs_escape_bound(true)
    end
end

local function toggle_pure_fullscreen_window(w)
    local win = w or hl.get_active_window()
    if not win or not win.address then return end
    if win.fullscreen and win.fullscreen == 2 and win.fullscreenClient and win.fullscreenClient ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set", window = win }))
        if fs_floating_map[win.address] then
            hl.dispatch(hl.dsp.window.float({ action = "on", window = win }))
            fs_floating_map[win.address] = nil
        end
        set_fs_escape_bound(false)
    else
        if win.floating then
            fs_floating_map[win.address] = true
        else
            fs_floating_map[win.address] = nil
        end
        hl.dispatch(hl.dsp.window.fullscreen({ mode = 0, window = win }))
        set_fs_escape_bound(true)
    end
end

-- Keybindings for Maximize & Fullscreen
hl.bind("F11",                      toggle_maximize_window)
hl.bind("SHIFT + F11",              toggle_pure_fullscreen_window)
hl.bind(mainMod .. " + F",          toggle_maximize_window)

-- Expose globally for scripting / verification
_G.toggle_maximize_window = toggle_maximize_window
_G.toggle_pure_fullscreen_window = toggle_pure_fullscreen_window
_G.set_fs_escape_bound = set_fs_escape_bound
_G.sync_fs_escape_state = sync_fs_escape_state

-- Event listeners to keep Escape key synchronized
hl.on("window.fullscreen",  function(_) sync_fs_escape_state() end)
hl.on("window.active",      function(_) sync_fs_escape_state() end)
hl.on("workspace.active",   function(_) sync_fs_escape_state() end)
hl.on("window.close",       function(_) sync_fs_escape_state() end)
hl.on("window.destroy",     function(_) sync_fs_escape_state() end)

-- Smart Float & Center (SUPER+A): Floats active window, resizes to 70% centered
hl.bind(mainMod .. " + A", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    local w = hl.get_active_window()
    if w ~= nil and w.floating then
        local mon = hl.get_active_monitor()
        if mon ~= nil then
            local target_w = math.floor(mon.width * 0.70)
            local target_h = math.floor(mon.height * 0.70)
            hl.dispatch(hl.dsp.window.resize({ x = target_w, y = target_h, relative = false }))
            local target_x = mon.x + math.floor((mon.width - target_w) / 2)
            local target_y = mon.y + math.floor((mon.height - target_h) / 2)
            hl.dispatch(hl.dsp.window.move({ x = target_x, y = target_y, relative = false }))
        end
    end
end)

-- Focus windows (HJKL vim-style)
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))

-- Swap / Move windows within layout (SUPER+SHIFT+HJKL)
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "right" }))

-- Resize windows (SUPER+CTRL+HJKL, repeating)
hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.resize({ x = -40, y = 0 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.resize({ x = 40, y = 0 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.resize({ x = 0, y = -40 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.resize({ x = 0, y = 40 }), { repeating = true })

-- Mouse drag move/resize
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ═══════════════════════════════════════════════════════════════════════════
-- 9. WORKSPACE NAVIGATION & WINDOW SWAPPING
-- ═══════════════════════════════════════════════════════════════════════════

-- Normal Workspace Change (Linear, no loop: SUPER + Left/Right)
hl.bind(mainMod .. " + Right", hl.dsp.exec_cmd("python3 " .. user_scripts .. "hypr/workspace_nav.py next_normal"))
hl.bind(mainMod .. " + Left",  hl.dsp.exec_cmd("python3 " .. user_scripts .. "hypr/workspace_nav.py prev_normal"))

-- Circular Loop Workspace Change (SUPER + SHIFT + Left/Right)
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.exec_cmd("python3 " .. user_scripts .. "hypr/workspace_nav.py next_loop"))
hl.bind(mainMod .. " + SHIFT + Left",  hl.dsp.exec_cmd("python3 " .. user_scripts .. "hypr/workspace_nav.py prev_loop"))

-- Clockwise / Anti-Clockwise Window Swapping (SUPER + ALT + Left/Right)
hl.bind(mainMod .. " + ALT + Right", hl.dsp.exec_cmd("python3 " .. user_scripts .. "hypr/window_rotator.py clockwise"))
hl.bind(mainMod .. " + ALT + Left",  hl.dsp.exec_cmd("python3 " .. user_scripts .. "hypr/window_rotator.py anticlockwise"))

-- Persistent default 3 workspaces (1, 2, 3)
hl.workspace_rule({ workspace = "1", persistent = true })
hl.workspace_rule({ workspace = "2", persistent = true })
hl.workspace_rule({ workspace = "3", persistent = true })

-- Direct Workspace Numeric Binds (1-10)
for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 10. AI SUITE & SPEECH RECOGNITION
-- ═══════════════════════════════════════════════════════════════════════════

-- Music Recognition / Shazam (SUPER+M)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("kitty --class music_recognition.py -e python3 " .. user_scripts .. "music/music_recognition.py"))

-- Push-to-Talk Voice Typing / STT (ALT+space)
hl.bind("ALT + space", hl.dsp.exec_cmd("python3 " .. user_scripts .. "tts_stt/dusky_parakeet/dusky_trigger.py toggle"))

-- Kokoro Neural TTS Read Aloud (SUPER+SHIFT+O)
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd([[sh -c 'TEXT=$(wl-paste -p 2>/dev/null || wl-paste 2>/dev/null); if [ -n "$TEXT" ]; then python3 ]] .. user_scripts .. [[tts_stt/dusky_kokoro/dusky_main.py --text "$TEXT"; else notify-send -a "Kokoro TTS" "No Text" "Highlight text first, then press SUPER+SHIFT+O"; fi']]))

-- ═══════════════════════════════════════════════════════════════════════════
-- 11. QUICK SYSTEM TUI UTILITIES & HARDWARE SUITE
-- ═══════════════════════════════════════════════════════════════════════════

-- Audio Stream Mixer / Pavucontrol (ALT+3)
hl.bind("ALT + 3", hl.dsp.exec_cmd("pavucontrol"))

-- Audio Output Quick Switcher (ALT+O)
hl.bind("ALT + O", hl.dsp.exec_cmd(user_scripts .. "audio/dusky_in_out_source.sh output"))

-- Microphone Input Quick Switcher (ALT+I)
hl.bind("ALT + I", hl.dsp.exec_cmd(user_scripts .. "audio/dusky_in_out_source.sh input"))

-- Dusky Audio Studio / Voice DSP (ALT+N)
hl.bind("ALT + N", hl.dsp.exec_cmd("python3 " .. user_scripts .. "audio/dusky_audio_studio/dusky_audio_studio.py"))

-- Mono Audio PipeWire Toggle (ALT+M)
hl.bind("ALT + M", hl.dsp.exec_cmd("python3 " .. user_scripts .. "audio/mono_audio_pipewire.py toggle"))

-- Screen Rotation +90° (CTRL+ALT+R)
hl.bind("CTRL + ALT + R", hl.dsp.exec_cmd("python3 " .. user_scripts .. "hypr/monitor/screen_rotate.py +90"))

-- Screen Rotation -90° (CTRL+ALT+SHIFT+R)
hl.bind("CTRL + ALT + SHIFT + R", hl.dsp.exec_cmd("python3 " .. user_scripts .. "hypr/monitor/screen_rotate.py -90"))

-- Magnifier Zoom (SUPER+Mouse Wheel, SUPER + = / - / 0)
local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    local newval = zoomvalue + value
    if newval > 3.0 then
        hl.config({ cursor = { zoom_factor = 3.0 } })
    elseif newval < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = newval } })
    end
end
hl.bind(mainMod .. " + mouse_up",   function() zoomfunction(0.5)  end, { repeating = true })
hl.bind(mainMod .. " + mouse_down", function() zoomfunction(-0.5) end, { repeating = true })
hl.bind(mainMod .. " + equal",      function() zoomfunction(0.3)  end, { repeating = true })
hl.bind(mainMod .. " + minus",      function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + 0",          function() hl.config({ cursor = { zoom_factor = 1.0 } }) end)

-- Gaming Mode Passthrough (ALT+6)
hl.bind("ALT + 6", hl.dsp.exec_cmd([[sh -c '
    STATE_FILE="/tmp/hypr_gamemode_state"
    if [ -f "$STATE_FILE" ]; then
        rm -f "$STATE_FILE"
        hyprctl keyword input:kb_options ""
        hyprctl keyword general:border_size 0
        hyprctl keyword decoration:rounding 8
        notify-send -a "Gaming Mode" "🎮 Gaming Mode OFF" "Compositor keybinds restored"
    else
        touch "$STATE_FILE"
        hyprctl keyword general:border_size 2
        hyprctl keyword decoration:rounding 0
        notify-send -a "Gaming Mode" "🎮 Gaming Mode ON" "All compositor keybinds disabled for gaming"
    fi
']]))

-- Wayclick Keyboard Sounds (SUPER+U)
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd(user_scripts .. "wayclick/dusky_wayclick.sh"))

-- Keystroke Visualizer OSD (SUPER+SHIFT+U)
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.exec_cmd([[sh -c 'if pgrep -f showmethekey >/dev/null 2>&1; then pkill -f showmethekey; notify-send -a "Keys" "Keystroke OSD OFF"; else showmethekey-gtk & notify-send -a "Keys" "Keystroke OSD ON"; fi']]))

-- Services & Process Terminator (ALT+DELETE)
hl.bind("ALT + Delete", hl.dsp.exec_cmd("kitty --class dusky_tui -e bash " .. user_scripts .. "performance/services_and_process_terminator.sh"))

-- ═══════════════════════════════════════════════════════════════════════════
-- 12. EMOJI, CALCULATOR, COLOR PICKER & KEYBINDING SEARCH
-- ═══════════════════════════════════════════════════════════════════════════

-- Emoji Picker (SUPER + , and SUPER + .)
hl.bind(mainMod .. " + comma",  hl.dsp.exec_cmd(user_scripts .. "rofi/emoji.sh"))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd(user_scripts .. "rofi/emoji.sh"))

-- Calculator (SUPER+C or XF86Calculator)
hl.bind(mainMod .. " + C",    hl.dsp.exec_cmd(user_scripts .. "rofi/calculator.sh"))
hl.bind("XF86Calculator",     hl.dsp.exec_cmd(user_scripts .. "rofi/calculator.sh"))

-- Color Picker (SUPER+P)
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd([[sh -c 'COLOR=$(hyprpicker -a -f hex 2>/dev/null); if [ -n "$COLOR" ]; then notify-send -a "Color Picker" "🎨 $COLOR" "Copied to clipboard"; fi']]))

-- Interactive Keybinding Search (SUPER + /)
hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd("kitty --class dusky_tui -e python3 " .. user_scripts .. "hypr/input/keybinds_cheatsheet.py"))

-- Dusky Glance HUD (CTRL+ALT+space)
hl.bind("CTRL + ALT + space", hl.dsp.exec_cmd(user_scripts .. "rofi/dusky_glance.sh"))

-- ═══════════════════════════════════════════════════════════════════════════
-- 13. CLIPBOARD MANAGER
-- ═══════════════════════════════════════════════════════════════════════════

hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("pgrep -x rofi >/dev/null && pkill -x rofi || cliphist list | rofi -dmenu -p '' | cliphist decode | wl-copy"))

-- ═══════════════════════════════════════════════════════════════════════════
-- 14. MEDIA & VOLUME KEYS
-- ═══════════════════════════════════════════════════════════════════════════

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })

-- ═══════════════════════════════════════════════════════════════════════════
-- 15. EXIT HYPRLAND
-- ═══════════════════════════════════════════════════════════════════════════

hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())

-- ═══════════════════════════════════════════════════════════════════════════
-- Done. All 43PR × Dusky features are active.
-- ═══════════════════════════════════════════════════════════════════════════

-- Minimized Window Dock & Controls
package.loaded["modules.minmax"] = nil
require("modules.minmax")

-- ── Power Button: Short press -> Suspend (Sleep), 5s Hold -> Poweroff (Shutdown) ──
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("/home/kshitij/.config/hypr/scripts/ryoku-power-button press"), { locked = true })
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("/home/kshitij/.config/hypr/scripts/ryoku-power-button release"), { locked = true, release = true })

-- ── Automatically ensure newly opened windows appear on top & focused ──
hl.on("window.open", function(w)
    pcall(function()
        if not w or not w.workspace then return end
        local active_ws = hl.get_active_workspace()
        local current_ws_id = active_ws and active_ws.id or w.workspace.id

        if w.workspace.id ~= current_ws_id then
            hl.dispatch(hl.dsp.window.move({ window = w, workspace = current_ws_id }))
        end

        local wins = hl.get_windows()
        for _, other in ipairs(wins) do
            if other.workspace and other.workspace.id == current_ws_id and other.fullscreen and other.fullscreen ~= 0 and other.address ~= w.address then
                hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set", window = other }))
            end
        end
        hl.dispatch(hl.dsp.focus({ window = w }))
        if w.floating and hl.dsp.window.alterzorder then
            pcall(function() hl.dispatch(hl.dsp.window.alterzorder({ action = "top", window = w })) end)
        end
    end)
end)

-- ── Double-clicking top header works exactly like Super + A ─────────────
local function toggle_super_a(w)
    if not w then return end
    pcall(function()
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set", window = w }))
        if not w.floating then
            hl.dispatch(hl.dsp.window.float({ action = "on", window = w }))
            local mon = hl.get_active_monitor()
            if mon ~= nil then
                local target_w = math.floor(mon.width * 0.70)
                local target_h = math.floor(mon.height * 0.70)
                hl.dispatch(hl.dsp.window.resize({ x = target_w, y = target_h, relative = false, window = w }))
                local target_x = mon.x + math.floor((mon.width - target_w) / 2)
                local target_y = mon.y + math.floor((mon.height - target_h) / 2)
                hl.dispatch(hl.dsp.window.move({ x = target_x, y = target_y, relative = false, window = w }))
            else
                hl.dispatch(hl.dsp.window.resize({ x = 1344, y = 756, exact = true, window = w }))
                hl.dispatch(hl.dsp.window.center({ window = w }))
            end
        else
            hl.dispatch(hl.dsp.window.float({ action = "off", window = w }))
        end
    end)
end

-- ── Handle direct mouse clicks: bring background window to top & handle header double-click ──
local last_header_click_time = 0
local last_header_click_pos = { x = 0, y = 0 }
local HEADER_DOUBLE_CLICK_TIME = 0.40 -- 400ms threshold
local HEADER_DOUBLE_CLICK_DIST = 15   -- 15px max movement
local HEADER_BAR_HEIGHT = 48          -- top header bar height in px

local function get_target_window_under_cursor(cp)
    if not cp then return nil end
    local active_ws = hl.get_active_workspace()
    local ws_id = active_ws and active_ws.id
    local wins = hl.get_windows()
    local cur_active = hl.get_active_window()

    -- 1. Check floating windows first
    if cur_active and cur_active.workspace and cur_active.workspace.id == ws_id and cur_active.floating and cur_active.at and cur_active.size then
        if cp.x >= cur_active.at.x and cp.x <= (cur_active.at.x + cur_active.size.x) and
           cp.y >= cur_active.at.y and cp.y <= (cur_active.at.y + cur_active.size.y) then
            return cur_active
        end
    end

    for _, w in ipairs(wins) do
        if w.workspace and w.workspace.id == ws_id and w.floating and w.at and w.size then
            if cp.x >= w.at.x and cp.x <= (w.at.x + w.size.x) and cp.y >= w.at.y and cp.y <= (w.at.y + w.size.y) then
                return w
            end
        end
    end

    -- 2. Check tiled windows next
    if cur_active and cur_active.workspace and cur_active.workspace.id == ws_id and not cur_active.floating and cur_active.at and cur_active.size then
        if cp.x >= cur_active.at.x and cp.x <= (cur_active.at.x + cur_active.size.x) and
           cp.y >= cur_active.at.y and cp.y <= (cur_active.at.y + cur_active.size.y) then
            return cur_active
        end
    end

    for _, w in ipairs(wins) do
        if w.workspace and w.workspace.id == ws_id and not w.floating and w.at and w.size then
            if cp.x >= w.at.x and cp.x <= (w.at.x + w.size.x) and cp.y >= w.at.y and cp.y <= (w.at.y + w.size.y) then
                return w
            end
        end
    end

    return cur_active
end

local function on_window_click()
    local now = os.clock()
    local cp = hl.get_cursor_pos()
    if not cp then return end

    local dt = now - last_header_click_time
    local dx = math.abs(cp.x - last_header_click_pos.x)
    local dy = math.abs(cp.y - last_header_click_pos.y)

    last_header_click_time = now
    last_header_click_pos = { x = cp.x, y = cp.y }

    local w = get_target_window_under_cursor(cp)
    if w and w.address then
        hl.dispatch(hl.dsp.focus({ window = w }))
        if w.floating and hl.dsp.window.alterzorder then
            pcall(function() hl.dispatch(hl.dsp.window.alterzorder({ action = "top", window = w })) end)
        end
    end

    if dt <= HEADER_DOUBLE_CLICK_TIME and dx <= HEADER_DOUBLE_CLICK_DIST and dy <= HEADER_DOUBLE_CLICK_DIST then
        last_header_click_time = 0
        if w and w.at and w.size then
            local wx = w.at.x
            local wy = w.at.y
            local ww = w.size.x
            if cp.x >= wx and cp.x <= (wx + ww) and cp.y >= wy and cp.y <= (wy + HEADER_BAR_HEIGHT) then
                toggle_super_a(w)
            end
        end
    end
end

hl.bind("mouse:272", on_window_click, { non_consuming = true })

