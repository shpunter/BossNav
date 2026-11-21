-- Kill tracking and extra bosses.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local DUNGEONS               = ns.DUNGEONS
local IsSecret               = ns.IsSecret
local NamesMatch             = ns.NamesMatch
local PlayerFaction          = ns.PlayerFaction
local Norm                   = ns.Norm
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
    if not ok or IsSecret(dead) or IsSecret(player) then return end
    if player then return end
    -- a hidden name: recognise the boss by the creature ID in its GUID
    if IsSecret(name) or type(name) ~= "string" then
        local okId, boss = pcall(ns.IdentifyBoss, "target")
        name = okId and boss and boss[1] or nil
    end
    if type(name) ~= "string" then return end
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

-- How many letters must change to turn a into b (a swapped pair counts once).
local function SpellingDistance(a, b)
    local d = {}
    for i = 0, #a do d[i] = { [0] = i } end
    for j = 0, #b do d[0][j] = j end
    for i = 1, #a do
        for j = 1, #b do
            local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
            local v = math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
            if i > 1 and j > 1 and a:sub(i, i) == b:sub(j - 1, j - 1) and a:sub(i - 1, i - 1) == b:sub(j, j) then
                v = math.min(v, d[i - 2][j - 2] + 1)
            end
            d[i][j] = v
        end
    end
    return d[#a][#b]
end

-- A built-in boss whose name is spelled almost like `name`: the game's own
-- data has typos (Blackfathom Deeps reports "Geilhast" for Gelihast).
-- Only a single clear winner counts.
local function FindCloseBoss(cfg, name)
    if not cfg or type(name) ~= "string" then return nil end
    local want = Norm(name)
    if not want or #want < 4 then return nil end
    local limit = (#want >= 6) and 2 or 1
    local best, bestD, tie
    for _, b in ipairs(cfg.bosses) do
        local d = SpellingDistance(want, Norm(b[1]:match("^(.-)%s*%(") or b[1]))
        if d <= limit then
            if not bestD or d < bestD then best, bestD, tie = b, d, false
            elseif d == bestD then tie = true end
        end
    end
    if best and not tie then return best end
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

-- Re-attach saved extra bosses to the dungeon lists at login. An extra boss
-- that is only a misspelling of a built-in one (added by an older BossNav
-- from the game's typo) is dropped for good.
local function ApplySavedExtraBosses()
    local saved = DB().extraBosses
    if not saved then return end
    for _, cfg in ipairs(DUNGEONS) do
        local extra = saved[cfg.key]
        if extra then
            for i = #extra, 1, -1 do
                local e = extra[i]
                if type(e.name) == "string" and not FindBoss(cfg, e.name) and FindCloseBoss(cfg, e.name) then
                    table.remove(extra, i)
                end
            end
            for _, e in ipairs(extra) do
                if type(e.name) == "string" and not FindBoss(cfg, e.name) then
                    cfg.bosses[#cfg.bosses + 1] = { e.name, e.x, e.y, e.floor }
                end
            end
        end
    end
end

-- Take the other faction's bosses out of every dungeon list, so the boss
-- count and the "Killed n/m" lines are about the bosses you can fight.
-- Runs once, as soon as the game says your faction.
local factionApplied = false
local function DropOtherFactionBosses()
    if factionApplied then return end
    local faction = PlayerFaction()
    if not faction then return end
    factionApplied = true
    for _, cfg in ipairs(DUNGEONS) do
        for i = #cfg.bosses, 1, -1 do
            local side = cfg.bosses[i].faction
            if side and side ~= faction then table.remove(cfg.bosses, i) end
        end
    end
    if state.cfg and state.bossIdx > #state.cfg.bosses then state.bossIdx = math.max(1, #state.cfg.bosses) end
end

-- Called from the game's boss-kill events: mark the boss dead. When the
-- game's name is not in the list: a near spelling of a listed boss, else the
-- boss seen when the encounter started, else add it as a new extra boss.
local function OnBossKilled(name)
    if type(name) ~= "string" or name == "" then return end
    local engaged = state.encounterBosses
    state.encounterBosses = nil
    if MarkKilled(name) then return end
    local cfg = state.cfg
    if not cfg or state.killed[name] then return end
    if FindBoss(cfg, name) then return end   -- listed and already dead
    local close = FindCloseBoss(cfg, name)
    if close then
        if not state.killed[close[1]] then MarkKilled(close[1]) end
        return
    end
    if engaged then
        local hit = false
        for bossName in pairs(engaged) do
            if not state.killed[bossName] and MarkKilled(bossName) then hit = true end
        end
        if hit then return end
    end
    if AddBoss(cfg, name) then
        MarkKilled(name)
    end
end

-- shared with the other BossNav files
ns.AddBoss = AddBoss
ns.ApplySavedExtraBosses = ApplySavedExtraBosses
ns.CheckTargetDead = CheckTargetDead
ns.DropOtherFactionBosses = DropOtherFactionBosses
ns.OnBossKilled = OnBossKilled
ns.RemoveBoss = RemoveBoss
