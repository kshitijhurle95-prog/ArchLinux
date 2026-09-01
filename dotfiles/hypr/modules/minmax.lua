-- modules/minmax.lua
-- Windows 11-style Minimize and Maximize for Hyprland
-- Features:
--  * Super + Down: Minimize active window (or restore if maximized)
--  * Super + Up: Maximize last minimized window onto active workspace (cross-workspace)
--  * 4-finger Swipe Down: Minimize active window directly (even if fullscreen)
--  * 4-finger Swipe Up: Maximize / restore window onto active workspace
--  * Pure 20px app icons at bottom-left corner (x=3, y=697/841)
--  * Clicking an icon maximizes that window to the active workspace
--  * App icons stacked on top of each other with no background/border/padding (0px)
--  * Exact cursor position preserved (no centering/warping)

local minimized_stack = {}
local runtime_dir = os.getenv("XDG_RUNTIME_DIR") or ("/run/user/" .. (os.getenv("UID") or "1000"))
local state_file = runtime_dir .. "/hypr_minimized.json"

-- Disable automatic cursor warping on focus or workspace change
pcall(function()
    hl.config({
        cursor = {
            no_warps = true,
            warp_on_change_workspace = 0,
        },
    })
end)

local function find_window_by_address(addr)
    if not addr then return nil end
    local wins = hl.get_windows()
    for _, w in ipairs(wins) do
        if w.address == addr then
            return w
        end
    end
    return nil
end

local function save_state()
    pcall(function()
        local wins = hl.get_windows()
        local win_map = {}
        local all_wins = {}
        for _, w in ipairs(wins) do
            if w.address then
                all_wins[w.address] = w
                if w.workspace and w.workspace.name == "special:minimized" then
                    win_map[w.address] = w
                end
            end
        end

        -- Filter minimized_stack to only existing minimized windows
        local valid_stack = {}
        local seen = {}
        for _, addr in ipairs(minimized_stack) do
            local w = all_wins[addr]
            if w and not seen[addr] then
                if win_map[addr] or (w.workspace and w.workspace.name and w.workspace.name:find("^special:minimized")) then
                    table.insert(valid_stack, addr)
                    seen[addr] = true
                end
            end
        end
        -- Add any minimized windows missing from stack
        for addr, _ in pairs(win_map) do
            if not seen[addr] then
                table.insert(valid_stack, addr)
                seen[addr] = true
            end
        end
        minimized_stack = valid_stack

        -- Serialize to JSON
        local items = {}
        for _, addr in ipairs(minimized_stack) do
            local w = win_map[addr] or all_wins[addr]
            if w then
                local title = (w.title or ""):gsub('"', '\\"'):gsub('\n', ' ')
                local class = (w.class or ""):gsub('"', '\\"')
                local initialClass = (w.initialClass or ""):gsub('"', '\\"')
                table.insert(items, string.format('{"address":"%s","class":"%s","initialClass":"%s","title":"%s"}',
                    w.address, class, initialClass, title))
            end
        end

        local json = "[" .. table.concat(items, ",") .. "]"
        local f = io.open(state_file, "w")
        if f then
            f:write(json)
            f:close()
        end
    end)
end

local function ensure_dock_running()
    pcall(function()
        hl.dispatch(hl.dsp.exec_cmd("systemctl --user reset-failed hypr-minimized-dock.service; systemctl --user start hypr-minimized-dock.service"))
    end)
end

local function is_overview_active()
    local f = io.open("/tmp/ryoku_overview_active", "r")
    if f then
        f:close()
        return true
    end
    return false
end

local function minimize(force_direct)
    if is_overview_active() then return end
    pcall(function()
        local cp = hl.get_cursor_pos()
        local win = hl.get_active_window()
        if not win or not win.address then return end

        -- Ignore if window is already inside a special workspace
        if win.workspace and win.workspace.name and win.workspace.name:find("^special:") then
            return
        end

        local active_ws = hl.get_active_workspace()
        local active_ws_id = active_ws and active_ws.id or 1

        -- If window is maximized/fullscreen:
        -- - Keyboard (force_direct = false): restore to normal first (Windows 11)
        -- - Gesture (force_direct = true): un-fullscreen and minimize directly
        if win.fullscreen and win.fullscreen ~= 0 then
            hl.dispatch(hl.dsp.window.fullscreen({ window = win }))
            if not force_direct then
                return
            end
        end

        -- Move the window silently to the special:minimized workspace
        hl.dispatch(hl.dsp.window.move({ window = win, workspace = "special:minimized", silent = true }))

        -- Ensure special workspace remains hidden so the window disappears completely
        local sp = hl.get_active_special_workspace()
        if sp and sp.name == "special:minimized" then
            hl.dispatch(hl.dsp.workspace.toggle_special("minimized"))
        end

        -- Ensure focus remains on the active regular workspace
        hl.dispatch(hl.dsp.focus({ workspace = active_ws_id }))

        -- Restore cursor position
        if cp and cp.x and cp.y then
            hl.dispatch(hl.dsp.cursor.move({ exact = true, x = cp.x, y = cp.y }))
        end

        -- Push to LIFO stack
        local new_stack = {}
        for _, addr in ipairs(minimized_stack) do
            if addr ~= win.address then
                table.insert(new_stack, addr)
            end
        end
        table.insert(new_stack, win.address)
        minimized_stack = new_stack

        ensure_dock_running()
        save_state()
    end)
end

local function restore(addr)
    pcall(function()
        local cp = hl.get_cursor_pos()
        local active_ws = hl.get_active_workspace()
        if not active_ws then return end
        local target_ws = active_ws.id

        local win = find_window_by_address(addr)
        if win and win.workspace and win.workspace.name == "special:minimized" then
            hl.dispatch(hl.dsp.window.move({ window = win, workspace = target_ws }))
            hl.dispatch(hl.dsp.focus({ window = win }))

            if cp and cp.x and cp.y then
                hl.dispatch(hl.dsp.cursor.move({ exact = true, x = cp.x, y = cp.y }))
            end

            local new_stack = {}
            for _, a in ipairs(minimized_stack) do
                if a ~= addr then
                    table.insert(new_stack, a)
                end
            end
            minimized_stack = new_stack
            save_state()
        end
    end)
end

local function maximize()
    if is_overview_active() then return end
    pcall(function()
        local active_ws = hl.get_active_workspace()
        if not active_ws then return end
        local target_ws = active_ws.id

        -- 1. Try popping the most recently minimized window from the stack
        while #minimized_stack > 0 do
            local addr = table.remove(minimized_stack)
            local win = find_window_by_address(addr)
            if win and win.workspace and win.workspace.name == "special:minimized" then
                -- Move to active workspace and focus it (cross-workspace mini-maximize)
                hl.dispatch(hl.dsp.window.move({ window = win, workspace = target_ws }))
                hl.dispatch(hl.dsp.focus({ window = win }))
                local cp = hl.get_cursor_pos()
                if cp and cp.x and cp.y then
                    hl.dispatch(hl.dsp.cursor.move({ exact = true, x = cp.x, y = cp.y }))
                end
                save_state()
                return
            end
        end

        -- 2. Fallback: Search all windows for any stranded in special:minimized (e.g. after reload)
        local wins = hl.get_windows()
        for _, win in ipairs(wins) do
            if win.workspace and win.workspace.name == "special:minimized" then
                hl.dispatch(hl.dsp.window.move({ window = win, workspace = target_ws }))
                hl.dispatch(hl.dsp.focus({ window = win }))
                local cp = hl.get_cursor_pos()
                if cp and cp.x and cp.y then
                    hl.dispatch(hl.dsp.cursor.move({ exact = true, x = cp.x, y = cp.y }))
                end
                save_state()
                return
            end
        end

        -- 3. If no window is minimized, check if current window is floating (e.g. after Super + A)
        local cur_win = hl.get_active_window()
        if cur_win and cur_win.address and cur_win.floating then
            -- Tile/maximize the floating window back into workspace layout (not fullscreen)
            hl.dispatch(hl.dsp.window.float({ action = "off", window = cur_win }))
            local cp = hl.get_cursor_pos()
            if cp and cp.x and cp.y then
                hl.dispatch(hl.dsp.cursor.move({ exact = true, x = cp.x, y = cp.y }))
            end
            save_state()
            return
        end

        -- 4. If window is already normal/maximized in layout, DO NOTHING (no fullscreen mode)
        save_state()
    end)
end

-- Keybinds
hl.unbind("SUPER + Up")
hl.unbind("SUPER + Down")

hl.bind("SUPER + Down", function() minimize(false) end)
hl.bind("SUPER + Up", maximize)

-- Touchpad Swipe Gestures
-- 4-Finger Swipe Down: Directly minimize active window (only active outside Mission Control)
hl.gesture({
    fingers = 4,
    direction = "down",
    action = {
        ["end"] = function()
            if not is_overview_active() then minimize(true) end
        end,
        ["finish"] = function()
            if not is_overview_active() then minimize(true) end
        end,
    },
})

-- 4-Finger Swipe Up: Maximize / restore window onto current workspace
hl.gesture({
    fingers = 4,
    direction = "up",
    action = {
        ["end"] = function()
            if not is_overview_active() then maximize() end
        end,
        ["finish"] = function()
            if not is_overview_active() then maximize() end
        end,
    },
})

-- 3-Finger Swipe Up: Open Mission Control
hl.gesture({
    fingers = 3,
    direction = "up",
    action = {
        ["end"] = function()
            if not is_overview_active() then
                hl.dispatch(hl.dsp.global("ryoku:overview"))
            end
        end,
        ["finish"] = function()
            if not is_overview_active() then
                hl.dispatch(hl.dsp.global("ryoku:overview"))
            end
        end,
    },
})

-- 3-Finger Swipe Down: Close Mission Control
hl.gesture({
    fingers = 3,
    direction = "down",
    action = {
        ["end"] = function()
            if is_overview_active() then
                hl.dispatch(hl.dsp.global("ryoku:overview"))
            end
        end,
        ["finish"] = function()
            if is_overview_active() then
                hl.dispatch(hl.dsp.global("ryoku:overview"))
            end
        end,
    },
})

-- Reorder workspaces and safely remap all windows within each workspace
local function reorder_workspaces(order)
    pcall(function()
        if type(order) == "string" then
            local t = {}
            for id_str in string.gmatch(order, "%d+") do
                table.insert(t, tonumber(id_str))
            end
            order = t
        end
        if not order or #order == 0 then return end

        local active_ws = hl.get_active_workspace()
        local old_active_id = active_ws and active_ws.id or 1
        local new_active_id = old_active_id

        local all_windows = hl.get_windows()

        -- Map each old workspace ID to its new workspace ID (1-based index in order)
        local ws_mapping = {}
        for new_idx, old_id in ipairs(order) do
            ws_mapping[old_id] = new_idx
            if old_id == old_active_id then
                new_active_id = new_idx
            end
        end

        -- Step 1: Move all windows on remapped workspaces to staging workspaces (5000 + old_id)
        for _, win in ipairs(all_windows) do
            if win.workspace and type(win.workspace.id) == "number" then
                local cur_ws = win.workspace.id
                if ws_mapping[cur_ws] and ws_mapping[cur_ws] ~= cur_ws then
                    local temp_ws = 5000 + cur_ws
                    hl.dispatch(hl.dsp.window.move({ window = win, workspace = temp_ws }))
                end
            end
        end

        -- Step 2: Move windows from staging to their final target workspace
        local staged_windows = hl.get_windows()
        for _, win in ipairs(staged_windows) do
            if win.workspace and type(win.workspace.id) == "number" then
                local cur_ws = win.workspace.id
                if cur_ws > 5000 then
                    local orig_old_id = cur_ws - 5000
                    local target_new_id = ws_mapping[orig_old_id]
                    if target_new_id then
                        hl.dispatch(hl.dsp.window.move({ window = win, workspace = target_new_id }))
                    end
                end
            end
        end

        -- Step 3: Switch active focus to the remapped active workspace
        if new_active_id then
            hl.dispatch(hl.dsp.focus({ workspace = new_active_id }))
        end
        save_state()
    end)
end

-- Initialize state, event hooks, and ensure dock is active
pcall(function()
    hl.on("window.move_to_workspace", save_state)
    hl.on("window.close", save_state)
    hl.on("window.destroy", save_state)
end)
save_state()
ensure_dock_running()

return {
    minimize = minimize,
    maximize = maximize,
    restore = restore,
    reorder_workspaces = reorder_workspaces,
    save_state = save_state,
    ensure_dock_running = ensure_dock_running,
}


