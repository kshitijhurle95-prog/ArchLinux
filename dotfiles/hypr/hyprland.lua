-- optional(mod): load a drop-in only when its file exists and has valid syntax.
-- Hyprland intercepts syntax errors inside require() into its error banner even
-- under pcall(). Pre-validating with loadfile() prevents broken/torn files from
-- triggering "Your config has errors" banners on boot, while auto-healing
-- hardware drop-ins like monitors.lua immediately.
local function optional(mod)
    local path = package.searchpath and package.searchpath(mod, package.path)
    if package.searchpath == nil or path then
        if path then
            local chunk, err = loadfile(path)
            if not chunk then
                print("ryoku: optional config module '" .. mod .. "' syntax error: " .. tostring(err))
                if mod == "monitors" then
                    os.execute("command -v ryoku-monitor >/dev/null 2>&1 && ryoku-monitor autoscale >/dev/null 2>&1")
                end
                return
            end
        end
        local ok, err = pcall(require, mod)
        if not ok then
            print("ryoku: optional config module '" .. mod .. "' failed to load: " .. tostring(err))
        end
    end
end

require("modules.env")
-- keyboard.lua is user-owned and seeded once, so an update never repairs it. a
-- hard require made a torn one fail the whole config: emergency mode, black
-- outputs, and a login loop no snapshot fixed, since ~/.config rides /home.
-- degrade to Hyprland's default layout instead; ryoku doctor reseeds the file.
optional("keyboard")
-- hardware drop-ins, written at runtime: ryoku-gpu emits gpu.lua, ryoku-monitor
-- emits monitors.lua, both rewritten on a hotplug or GPU reset. ryoku doctor
-- repairs a corrupt one, autoscale regenerates it next login.
optional("gpu")
optional("monitors")
-- hand-written overrides: ~/.config/hypr/monitors_user.lua, never shipped,
-- never touched by ryoku-monitor. loaded after the generated monitors.lua so a
-- pinned panel (fake-EDID needing a forced mode or modeline, a pinned layout)
-- wins. see monitors_user.lua.example.
optional("monitors_user")
require("modules.displays")
require("modules.input")
require("modules.misc")
require("modules.decoration")
require("modules.animations")
require("modules.binds")
require("modules.resize")
require("modules.record")
-- require("modules.ryoshot") -- Disabled in favor of 43PR screenshot capture suite
require("modules.lid")
require("modules.window_rules")
require("modules.fullscreen")
require("modules.autostart")

-- machine-state written by the hub (ryoku-hub), never shipped. after the base
-- modules so the GUI's tweaks override the defaults, before user.lua so a
-- hand-written user file still wins.
optional("settings")

-- Power Saver strips compositor blur and shadow (the heaviest present-time GPU
-- cost). After settings so the active power profile wins over the Hub's
-- decoration tweaks; before user.lua so a hand file still wins. Gated by the
-- shell-written cache, which reflects Performance's "Follow the power profile".
optional("modules.perf_saver")

optional("modules.private")

-- GhostType hotkey (the app owns it)
optional("ghosttype")

-- last word: ~/.config/hypr/user.lua. seeded once with a header explaining the
-- load order, then yours; never touched by updates.
optional("user")
