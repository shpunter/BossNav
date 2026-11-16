-- Kill tracking and extra bosses.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local DUNGEONS               = ns.DUNGEONS
local IsSecret               = ns.IsSecret
local NamesMatch             = ns.NamesMatch
local Print                  = ns.Print
local RefreshIfShown         = ns.RefreshIfShown
local TouchProgress          = ns.TouchProgress
local state                  = ns.state

--------------------------------------------------------------------------
-- Boss kills
--------------------------------------------------------------------------
local function SelectNextAlive()
    local cfg = state.cfg
    if not cfg then return end
    for step = 1, #cfg.bosses do
        local idx = ((state.bossIdx - 1 + step) % #cfg.bosses) + 1
        if not state.killed[cfg.bosses[idx][1]] then
            state.bossIdx = idx
            return
        end
    end
end

local function MarkKilled(name)
    local cfg = state.cfg
    if not cfg or type(name) ~= "string" then return false end
    local hit = false
    for i, b in ipairs(cfg.bosses) do
        if NamesMatch(b[1], name) and not state.killed[b[1]] then
            state.killed[b[1]] = true
            hit = true
            Print("|cff888888" .. b[1] .. " defeated.|r")
            if i == state.bossIdx then SelectNextAlive() end
        end
    end
    if hit then
        TouchProgress()
        RefreshIfShown()
        pcall(BossNav_UpdateLive, true)
    end
    return hit
end

-- A boss we remembered as dead is standing in front of us alive: the instance
-- was reset, so forget the stale mark.
local function MarkAlive(name)
    local cfg = state.cfg
    if not cfg or type(name) ~= "string" then return false end
    local hit = false
    for _, b in ipairs(cfg.bosses) do
        if NamesMatch(b[1], name) and state.killed[b[1]] then
            state.killed[b[1]] = nil
            hit = true
            Print("|cff888888" .. b[1] .. " is alive again (instance reset?). Mark cleared.|r")
        end
    end
    if hit then
        TouchProgress()
        RefreshIfShown()
        pcall(BossNav_UpdateLive, true)
    end
    return hit
end

local function CheckTargetDead()
    local ok, name, dead, player = pcall(function()
        if not UnitExists("target") then return nil end
        return UnitName("target"), UnitIsDead("target"), UnitIsPlayer("target")
    end)
    if not ok or IsSecret(name) or IsSecret(dead) or IsSecret(player) then return end
    if type(name) ~= "string" or player then return end
    if dead then
        MarkKilled(name)
    elseif dead == false then
        MarkAlive(name)
    end
end

--------------------------------------------------------------------------
-- Extra bosses: bosses the built-in list does not know. They are added
-- automatically when the game reports a boss kill (ENCOUNTER_END / BOSS_KILL)
-- for a name that is not in the list, or by hand with /bnav addboss.
-- Saved per dungeon; they start without a pin (/bnav markboss places one).
--------------------------------------------------------------------------
local function FindBoss(cfg, name)
    if not cfg or type(name) ~= "string" then return nil end
    for i, b in ipairs(cfg.bosses) do
        if NamesMatch(b[1], name) then return i, b end
    end
    return nil
end

local function AddBoss(cfg, name, x, y, floor, silent)
    if not cfg or type(name) ~= "string" or name == "" then return nil end
    if FindBoss(cfg, name) then return nil end
    local b = { name, x, y, floor }
    cfg.bosses[#cfg.bosses + 1] = b
    local db = DB()
    db.extraBosses = db.extraBosses or {}
    db.extraBosses[cfg.key] = db.extraBosses[cfg.key] or {}
    db.extraBosses[cfg.key][#db.extraBosses[cfg.key] + 1] = { name = name, x = x, y = y, floor = floor }
    if not silent then
        Print(string.format("|cff00ff00%s|r added to %s (%d bosses). No pin yet: /bnav markboss X Y places one.",
            name, cfg.name, #cfg.bosses))
    end
    RefreshIfShown()
    return b
end

local function RemoveBoss(cfg, name)
    local db = DB()
    local extra = cfg and db.extraBosses and db.extraBosses[cfg.key]
    if not extra then return false end
    local removed = false
    for i = #extra, 1, -1 do
        if NamesMatch(extra[i].name, name) or extra[i].name == name then
            table.remove(extra, i)
            removed = true
        end
    end
    if removed then
        for i = #cfg.bosses, 1, -1 do
            if NamesMatch(cfg.bosses[i][1], name) then table.remove(cfg.bosses, i) end
        end
        if state.bossIdx > #cfg.bosses then state.bossIdx = math.max(1, #cfg.bosses) end
        TouchProgress()
        RefreshIfShown()
    end
    return removed
end

-- Re-attach saved extra bosses to the dungeon lists at login.
local function ApplySavedExtraBosses()
    local saved = DB().extraBosses
    if not saved then return end
    for _, cfg in ipairs(DUNGEONS) do
        local extra = saved[cfg.key]
        if extra then
            for _, e in ipairs(extra) do
                if type(e.name) == "string" and not FindBoss(cfg, e.name) then
                    cfg.bosses[#cfg.bosses + 1] = { e.name, e.x, e.y, e.floor }
                end
            end
        end
    end
end

-- Called from the game's boss-kill events: mark the boss dead, adding it to
-- the list first if the built-in data does not know it.
local function OnBossKilled(name)
    if type(name) ~= "string" or name == "" then return end
    if MarkKilled(name) then return end
    local cfg = state.cfg
    if not cfg or state.killed[name] then return end
    if not FindBoss(cfg, name) and AddBoss(cfg, name) then
        MarkKilled(name)
    end
end

-- shared with the other BossNav files
ns.AddBoss = AddBoss
ns.ApplySavedExtraBosses = ApplySavedExtraBosses
ns.CheckTargetDead = CheckTargetDead
ns.OnBossKilled = OnBossKilled
ns.RemoveBoss = RemoveBoss
