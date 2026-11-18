-- Tank aggro alert: a mob that was attacking you turns to someone else.
--
-- The threat window (BossNav_Threat.lua) hands its mob list here every
-- refresh. In tank mode, when a mob that was on you is now on another group
-- member (two refreshes in a row, so a mob briefly targeting a spell target
-- does not count), a raid-warning line and a sound say who took it:
--   "LOST AGGRO: Deviate Lasher -> Healername"
-- /bnav threat alert turns it off and on.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local IsSecret               = ns.IsSecret
local UnitNameClass          = ns.UnitNameClass

local wasMine = {}   -- nameplate unit -> true while the mob is on you
local losing  = {}   -- nameplate unit -> refreshes it has been off you

local function IsMe(unit)
    local ok, me = pcall(UnitIsUnit, unit, "player")
    return ok and not IsSecret(me) and me == true
end

-- true: on you, false: on someone else, nil: not known
local function OnMe(t)
    if (t.myStatus or 0) >= 2 then return true end
    if t.holder then return IsMe(t.holder) end
    if t.myStatus then return false end
    return nil
end

local function MobName(unit)
    local ok, name = pcall(UnitName, unit)
    if ok and not IsSecret(name) and type(name) == "string" then return name end
    return "a mob"
end

local function Alert(t)
    local who = "someone"
    if t.holder then
        local name = UnitNameClass(t.holder)
        if name then who = name end
    end
    local msg = "LOST AGGRO: " .. MobName(t.unit) .. " -> " .. who
    pcall(function()
        if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo then
            RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
        else
            UIErrorsFrame:AddMessage(msg, 1.0, 0.3, 1.0)
        end
    end)
    pcall(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
end

-- mobs: the threat window's list; tank: tank mode on
local function CheckAggroLoss(mobs, tank)
    if not tank or DB().aggroAlert == false then
        wipe(wasMine)
        wipe(losing)
        return
    end
    local seen = {}
    for _, t in ipairs(mobs or {}) do
        local unit = t.unit
        seen[unit] = true
        local on = OnMe(t)
        if on == true then
            wasMine[unit] = true
            losing[unit] = nil
        elseif on == false and wasMine[unit] then
            losing[unit] = (losing[unit] or 0) + 1
            if losing[unit] >= 2 then
                wasMine[unit] = nil
                losing[unit] = nil
                Alert(t)
            end
        end
    end
    -- mobs that died or went out of view: forget them quietly
    for unit in pairs(wasMine) do if not seen[unit] then wasMine[unit] = nil end end
    for unit in pairs(losing) do if not seen[unit] then losing[unit] = nil end end
end

-- /bnav threat alert
local function ToggleAggroAlert()
    DB().aggroAlert = (DB().aggroAlert == false)
    return DB().aggroAlert
end

-- shared with the other BossNav files
ns.CheckAggroLoss = CheckAggroLoss
ns.ToggleAggroAlert = ToggleAggroAlert
