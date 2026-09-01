-- ~/.config/hypr/user.lua
-- User custom Hyprland configuration (Clean Ryoku defaults + Fullscreen/Maximize & Tools)

local home = os.getenv("HOME")
local user_scripts = home .. "/user_scripts/"
local mainMod = "SUPER"

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. FULLSCREEN, MAXIMIZE & LIVE WALLPAPER / VISUALIZER AUTO-PAUSE (0ms RESUME)
-- ═══════════════════════════════════════════════════════════════════════════
-- F11: Fully maximize window (occupies entire screen, 100% opacity, Esc/F11 restores)
-- Shift+F11: Pure fullscreen (mode 0, 100% opacity, Esc/Shift+F11 restores)
-- Esc: Dynamically bound ONLY when active window is fullscreen/maximized
-- Live wallpaper and visualizer pause in fullscreen/maximize and resume with 0ms delay on exit

local fs_floating_map = {}
local escape_is_bound = false
local livewall_paused = false

local function pause_livewall_and_visualizer()
    if not livewall_paused then
        livewall_paused = true
        os.execute("pkill -STOP -x mpvpaper 2>/dev/null; pkill -STOP -x ryoku-livewall 2>/dev/null; pkill -STOP -x cava 2>/dev/null &")
    end
end

local function resume_livewall_and_visualizer()
    if livewall_paused then
        livewall_paused = false
        os.execute("pkill -CONT -x mpvpaper 2>/dev/null; pkill -CONT -x ryoku-livewall 2>/dev/null; pkill -CONT -x cava 2>/dev/null &")
    end
end

local function is_any_window_fullscreen_or_maximized()
    local cur = hl.get_active_window()
    if cur and cur.fullscreen and cur.fullscreen ~= 0 then
        return true
    end
    local active_ws = hl.get_active_workspace()
    local ws_id = active_ws and active_ws.id
    if ws_id and hl.get_windows then
        local wins = hl.get_windows()
        for _, w in ipairs(wins) do
            if w.workspace and w.workspace.id == ws_id and w.fullscreen and w.fullscreen ~= 0 then
                return true
            end
        end
    end
    return false
end

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
                    resume_livewall_and_visualizer()
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

local function sync_fs_state()
    sync_fs_escape_state()
    if is_any_window_fullscreen_or_maximized() then
        pause_livewall_and_visualizer()
    else
        resume_livewall_and_visualizer()
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
        resume_livewall_and_visualizer()
    else
        if win.floating then
            fs_floating_map[win.address] = true
        else
            fs_floating_map[win.address] = nil
        end
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 2, client = 0, action = "set", window = win }))
        set_fs_escape_bound(true)
        pause_livewall_and_visualizer()
    end
end

local function toggle_pure_fullscreen_window(w)
    local win = w or hl.get_active_window()
    if not win or not win.address then return end
    if win.fullscreen and win.fullscreen ~= 0 then
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set", window = win }))
        if fs_floating_map[win.address] then
            hl.dispatch(hl.dsp.window.float({ action = "on", window = win }))
            fs_floating_map[win.address] = nil
        end
        set_fs_escape_bound(false)
        resume_livewall_and_visualizer()
    else
        if win.floating then
            fs_floating_map[win.address] = true
        else
            fs_floating_map[win.address] = nil
        end
        hl.dispatch(hl.dsp.window.fullscreen({ mode = 0, window = win }))
        set_fs_escape_bound(true)
        pause_livewall_and_visualizer()
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
_G.sync_fs_state = sync_fs_state
_G.pause_livewall_and_visualizer = pause_livewall_and_visualizer
_G.resume_livewall_and_visualizer = resume_livewall_and_visualizer

-- Event listeners to keep Escape key, live wallpaper, and visualizer synchronized
hl.on("window.fullscreen",  function(_) sync_fs_state() end)
hl.on("window.active",      function(_) sync_fs_state() end)
hl.on("workspace.active",   function(_) sync_fs_state() end)
hl.on("window.close",       function(_) sync_fs_state() end)
hl.on("window.destroy",     function(_) sync_fs_state() end)

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. MISSION CONTROL & OVERVIEW (F3, CTRL+Up, SUPER+Tab)
-- ═══════════════════════════════════════════════════════════════════════════
hl.bind("F3",                       hl.dsp.global("ryoku:overview"))
hl.bind("CTRL + Up",                hl.dsp.global("ryoku:overview"))
hl.bind(mainMod .. " + Tab",        hl.dsp.global("ryoku:overview"))

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. CUSTOM USER TOOLS & SCRIPTS (Peaceful Coexistence with Ryoku Defaults)
-- ═══════════════════════════════════════════════════════════════════════════
hl.bind(mainMod .. " + G",         hl.dsp.exec_cmd(user_scripts .. "google_image_search/google_image_search.sh"))
hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd("kitty --class music_recognition.py -e python3 " .. user_scripts .. "music/music_recognition.py"))
hl.bind("ALT + SPACE",             hl.dsp.exec_cmd("python3 " .. user_scripts .. "tts_stt/dusky_parakeet/dusky_trigger.py --push"))
hl.bind("ALT + O",                 hl.dsp.exec_cmd(user_scripts .. "audio/dusky_in_out_source.sh --output"))
hl.bind("ALT + I",                 hl.dsp.exec_cmd(user_scripts .. "audio/dusky_in_out_source.sh --input"))
hl.bind("ALT + N",                 hl.dsp.exec_cmd(user_scripts .. "audio/dusky_in_out_source.sh --studio"))
hl.bind("ALT + M",                 hl.dsp.exec_cmd("python3 " .. user_scripts .. "audio/mono_audio_pipewire.py"))
hl.bind("CTRL + ALT + R",          hl.dsp.exec_cmd("python3 " .. user_scripts .. "hypr/monitor/screen_rotate.py +90"), { locked = true, repeating = true })
hl.bind("CTRL + ALT + SHIFT + R",  hl.dsp.exec_cmd("python3 " .. user_scripts .. "hypr/monitor/screen_rotate.py -90"), { locked = true, repeating = true })
hl.bind(mainMod .. " + U",         hl.dsp.exec_cmd(user_scripts .. "wayclick/dusky_wayclick.sh"))
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.exec_cmd(user_scripts .. "mako_osd/dusky_keys/dusky_keys.sh"))
