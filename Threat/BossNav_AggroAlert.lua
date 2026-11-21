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
local lastWho = {}   -- nameplate unit -> last readable name of who took it

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

local function PlainName(unit)
    local ok, name = pcall(UnitName, unit)
    if ok and not IsSecret(name) and type(name) == "string" and name ~= "" then return name end
    return nil
end

-- Best guess at who has the mob now: the group member on top of its threat
-- list, else the mob's target, else the group member with the most threat
-- after you; nil when the client hides all of them
local function WhoHasIt(t)
    if t.holder and not IsMe(t.holder) then
        local name = UnitNameClass(t.holder)
        if name then return name end
    end
    local target = t.unit .. "target"
    if not IsMe(target) then
        local name = PlainName(target)
        if name then return name end
    end
    if t.nextUnit then
        local name = UnitNameClass(t.nextUnit)
        if name then return name end
    end
    return nil
end

local function ShowWarning(msg)
    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo then
        RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
    else
        UIErrorsFrame:AddMessage(msg, 1.0, 0.3, 1.0)
    end
end

local function Alert(t, who)
    local head = "LOST AGGRO: " .. MobName(t.unit) .. " -> "
    local shown = false
    if who then
        shown = pcall(ShowWarning, head .. who)
    else
        -- the addon cannot read the name, but the screen may still show it:
        -- hand the hidden name of the mob's target straight to the warning
        local ok, name = pcall(UnitName, t.unit .. "target")
        if ok and (IsSecret(name) or type(name) == "string") then
            shown = pcall(function() ShowWarning(head .. name) end)
        end
    end
    if not shown then pcall(ShowWarning, head .. "someone") end
    pcall(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
end

-- mobs: the threat window's list; tank: tank mode on
local function CheckAggroLoss(mobs, tank)
    if not tank or DB().aggroAlert == false then
        wipe(wasMine)
        wipe(losing)
        wipe(lastWho)
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
            lastWho[unit] = nil
        elseif on == false and wasMine[unit] then
            losing[unit] = (losing[unit] or 0) + 1
            -- keep the last name we could read, in case the client hides it next time
            lastWho[unit] = WhoHasIt(t) or lastWho[unit]
            if losing[unit] >= 2 then
                local who = lastWho[unit]
                wasMine[unit] = nil
                losing[unit] = nil
                lastWho[unit] = nil
                Alert(t, who)
            end
        end
    end
    -- mobs that died or went out of view: forget them quietly
    for unit in pairs(wasMine) do if not seen[unit] then wasMine[unit] = nil end end
    for unit in pairs(losing) do if not seen[unit] then losing[unit] = nil end end
    for unit in pairs(lastWho) do if not seen[unit] then lastWho[unit] = nil end end
end

-- /bnav threat alert
local function ToggleAggroAlert()
    DB().aggroAlert = (DB().aggroAlert == false)
    return DB().aggroAlert
end

-- shared with the other BossNav files
ns.CheckAggroLoss = CheckAggroLoss
ns.ToggleAggroAlert = ToggleAggroAlert
