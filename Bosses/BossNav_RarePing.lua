-- Rare ping macro: one key targets the last rare seen and drops the game's
-- "attack" ping on it, so the whole group sees it on screen and minimap.
--
-- The game sends a ping only from a key press, never from addon code, so
-- BossNav keeps a real macro named "BNavRare" (General macros) and rewrites
-- it whenever the rare alert (BossNav_RareAlert.lua) sees a new rare:
--   /targetexact <name>
--   /ping [@target] attack
-- Before any rare is seen it only pings your target. Macros cannot be
-- changed in combat, so a rare first seen in combat goes into the macro
-- as soon as the fight ends.
--
-- /bnav raremacro makes the macro; /bnav rarekey F10 binds a key to it.
local ADDON, ns = ...
-- from the files loaded before this one
local AddCommand             = ns.AddCommand
local Print                  = ns.Print

local MACRO = "BNavRare"
local ICON  = "INV_MISC_QUESTIONMARK"
local PING  = "/ping [@target] attack"

local pending   -- name waiting for the fight to end
local current   -- name now in the macro

local function Body(name)
    if name then return "/targetexact " .. name .. "\n" .. PING end
    return PING
end

local function MacroIndex()
    local ok, idx = pcall(GetMacroIndexByName, MACRO)
    if ok and type(idx) == "number" and idx > 0 then return idx end
    return nil
end

-- write the macro text; false when there is no macro or we are in combat
local function Apply(name)
    current = name or current
    local idx = MacroIndex()
    if not idx or InCombatLockdown() then return false end
    return (pcall(EditMacro, idx, MACRO, ICON, Body(current)))
end

local waiter = CreateFrame("Frame")
waiter:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if pending then
        Apply(pending)
        pending = nil
    end
end)

-- Called by the rare alert with a readable rare name.
local function SetRarePingTarget(name)
    if type(name) ~= "string" or name == "" or name:find("\n") then return end
    if InCombatLockdown() then
        current = name
        pending = name
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        Apply(name)
    end
end

-- make the macro if it is missing; returns true when it exists
local function EnsureMacro()
    if MacroIndex() then return true end
    if InCombatLockdown() then Print("Can't make macros in combat.") return false end
    local ok, err = pcall(CreateMacro, MACRO, ICON, Body(current), nil)
    if not ok or not MacroIndex() then
        Print("Could not make the macro (" .. tostring(err or "General macros full?") .. ").")
        return false
    end
    Print("Macro " .. MACRO .. " made (Esc > Macros, General tab).")
    return true
end

-- the key bound to the macro, as the game prints it, or nil
local function BoundKey()
    local ok, key = pcall(GetBindingKey, "MACRO " .. MACRO)
    if ok and type(key) == "string" then return key end
    return nil
end

-- /bnav raremacro
AddCommand("raremacro", function()
    if EnsureMacro() then
        Apply()
        Print("It pings " .. (current or "your target") .. ". Put it on a bar, or /bnav rarekey F10 to bind a key.")
    end
end, {
    "  /bnav raremacro       make the BNavRare macro: targets the last rare seen and pings it for the group",
})

-- /bnav rarekey [KEY]
AddCommand("rarekey", function(rest)
    local key = (rest or ""):upper():gsub("%s", "")
    if key == "" then
        Print("Ping Rare key: " .. (BoundKey() or "none") ..
              (current and (", pings " .. current) or ", pings your target") .. ".")
        return
    end
    if InCombatLockdown() then Print("Can't change keys in combat.") return end
    local force = false
    if key:sub(-5) == "FORCE" and #key > 5 then
        key, force = key:sub(1, -6), true
    end
    -- never take a key that already does something, unless asked to
    local okA, action = pcall(GetBindingAction, key)
    if not force and okA and type(action) == "string" and action ~= ""
       and action ~= "MACRO " .. MACRO then
        local label = (GetBindingName and GetBindingName(action)) or action
        Print(key .. " is already used for: " .. tostring(label) ..
              ". Pick a free key, or /bnav rarekey " .. key .. " force to replace it.")
        return
    end
    if not EnsureMacro() then return end
    local ok = pcall(SetBinding, key, "MACRO " .. MACRO)
    if ok and SaveBindings then
        -- 1 = account-wide set, 2 = this character's; older clients lack the getter
        local okSet, set = pcall(function() return GetCurrentBindingsSet() end)
        pcall(SaveBindings, (okSet and set) or 1)
    end
    if ok and BoundKey() then
        Print("Ping Rare is on " .. key .. ".")
    else
        Print("Could not bind '" .. key .. "'. Try a name like F10, CTRL-R or SHIFT-5.")
    end
end, {
    "  /bnav rarekey [KEY]   bind a key to the BNavRare macro (e.g. /bnav rarekey F10);",
    "                        a key already in use is refused unless you add 'force'",
})

-- shared with the other BossNav files
ns.SetRarePingTarget = SetRarePingTarget
ns.RarePingKey = BoundKey
