-- Saved per-dungeon progress.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local state                  = ns.state

--------------------------------------------------------------------------
-- Saved progress (per dungeon). Kill marks and visited waypoints live in
-- SavedVariables so a death (which puts you outside the instance as a spirit),
-- a relog or a crash does not lose them. Progress older than the server's
-- instance reset window is dropped.
--------------------------------------------------------------------------
local PROGRESS_MAX_AGE = 3600   -- seconds since the last change; refreshed while inside

local function LoadProgress(cfg)
    local store = DB().progress
    local rec = cfg and store[cfg.key] or nil
    if rec and (type(rec.time) ~= "number" or time() - rec.time > PROGRESS_MAX_AGE) then
        store[cfg.key] = nil
        rec = nil
    end
    if cfg and not rec then
        rec = { killed = {}, visited = {}, gold = 0, xp = 0, bossIdx = 1, time = time(), started = time() }
        store[cfg.key] = rec
    end
    if rec then
        rec.killed = rec.killed or {}
        rec.visited = rec.visited or {}
        rec.started = rec.started or time()   -- records saved before the run timer existed
        state.killed = rec.killed
        state.visited = rec.visited
        state.bossIdx = rec.bossIdx or 1
        state.gold = rec.gold or 0
        state.xp = rec.xp or 0
        state.started = rec.started
    else
        state.killed = {}
        state.visited = {}
        state.bossIdx = 1
        state.gold = 0
        state.xp = 0
        state.started = nil
    end
    return rec
end

-- Kills of your current run in a dungeon you are not in (read only; nothing
-- is created). Empty when there is no fresh record.
local function SavedKilled(cfg)
    local rec = cfg and DB().progress[cfg.key]
    if rec and type(rec.time) == "number" and time() - rec.time <= PROGRESS_MAX_AGE and rec.killed then
        return rec.killed
    end
    return {}
end

-- Call after any change to kill marks, visited waypoints or the selected boss.
local function TouchProgress()
    local cfg = state.cfg
    if not cfg or state.testMode then return end
    local rec = DB().progress[cfg.key]
    if not rec or rec.killed ~= state.killed then
        rec = { killed = state.killed, visited = state.visited, copies = rec and rec.copies }
        DB().progress[cfg.key] = rec
    end
    rec.bossIdx = state.bossIdx
    rec.gold = state.gold or 0
    rec.xp = state.xp or 0
    rec.started = state.started or rec.started or time()
    rec.time = time()
end

-- Seconds since this run of the dungeon began (first entry with no fresh
-- saved progress, or the last time the marks were cleared). Counts time
-- spent outside too, such as running back as a spirit. nil outside a dungeon.
local function RunSeconds()
    if not state.started then return nil end
    return math.max(0, time() - state.started)
end

-- Keeps the dungeon copy IDs (BossNav_InstanceReset.lua): clearing marks by
-- hand does not make a new copy of the dungeon.
local function ClearProgress(cfg)
    local old = cfg and DB().progress[cfg.key]
    local copies = old and old.copies
    state.killed = {}
    state.visited = {}
    state.gold = 0
    state.xp = 0
    state.started = time()
    if cfg then DB().progress[cfg.key] = nil end
    if cfg and not state.testMode then
        DB().progress[cfg.key] = { killed = state.killed, visited = state.visited, gold = 0, xp = 0, bossIdx = state.bossIdx, time = time(), started = state.started, copies = copies }
    end
end

--------------------------------------------------------------------------
-- Leaving the party. The server gives you a fresh instance once you are out
-- of the group, so every saved record is stale: wipe them all.
--------------------------------------------------------------------------
local function IsGrouped()
    if IsInGroup then return IsInGroup() and true or false end
    if GetNumGroupMembers then return GetNumGroupMembers() > 0 end
    if GetNumPartyMembers then return GetNumPartyMembers() > 0 end
    return false
end

-- Call on GROUP_ROSTER_UPDATE and after every loading screen. Returns true
-- when you were in a group and now are not (progress was wiped). The "was in
-- a group" flag is saved, so leaving while logged out or during a loading
-- screen is still noticed.
local function OnGroupRosterChanged()
    local db = DB()
    local was = db.inGroup
    local now = IsGrouped()
    db.inGroup = now
    if not was or now then return false end
    local store = DB().progress
    for key in pairs(store) do store[key] = nil end
    ClearProgress(state.cfg)
    return true
end

-- shared with the other BossNav files
ns.ClearProgress = ClearProgress
ns.OnGroupRosterChanged = OnGroupRosterChanged
ns.RunSeconds = RunSeconds
ns.SavedKilled = SavedKilled
ns.LoadProgress = LoadProgress
ns.TouchProgress = TouchProgress
