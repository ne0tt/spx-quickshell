-- -----------------------------------------------------
-- Screen Shader / Blue-Light Filter
-- Pure-Lua replacement for hyprshade
-- No external tool required.
-- -----------------------------------------------------
--
-- SUPER + CTRL + Delete  –  cycle through filter strengths and off
-- -----------------------------------------------------

local HOME       = os.getenv("HOME")
local SHADER_DIR = HOME .. "/.config/hypr/shaders"

local STATE_FILE = "/tmp/hypr_shader_state"

local function apply(shader_name)
    local path = shader_name and (SHADER_DIR .. "/" .. shader_name) or ""
    hl.config({ decoration = { screen_shader = path } })
    -- Persist state so it survives config reloads
    local f = io.open(STATE_FILE, "w")
    if f then f:write(shader_name or ""); f:close() end
end

-- ============================================================
-- Keybindings
-- ============================================================

local mainMod = "SUPER"

-- SUPER + CTRL + Delete  –  cycle through filter strengths and off
local _strengths = {
    nil,
    "blue-light-filter-25.glsl",
    "blue-light-filter-50.glsl",
    "blue-light-filter-75.glsl",
    "blue-light-filter-100.glsl",
}
local _strength_idx = 1

-- Restore shader state after a config reload (e.g. triggered by matugen)
hl.on("config.reloaded", function()
    local f = io.open(STATE_FILE, "r")
    if not f then return end
    local saved = f:read("*l"); f:close()
    if saved and saved ~= "" then
        -- Find the matching index so cycling continues correctly
        for i, s in ipairs(_strengths) do
            if s == saved then _strength_idx = i; break end
        end
        hl.config({ decoration = { screen_shader = SHADER_DIR .. "/" .. saved } })
    end
end)

hl.bind(mainMod .. " + CTRL + Delete", function()
    _strength_idx = (_strength_idx % #_strengths) + 1
    local shader = _strengths[_strength_idx]
    apply(shader)
    local label = shader and shader:gsub("%.glsl$", "") or "off"
    --hl.notification.create({ text = "Shader: " .. label, timeout = 2000, icon = "ok" })
end, { description = "Cycle blue-light filter strength" })

