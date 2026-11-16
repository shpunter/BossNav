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
        rec = { killed = {}, visited = {}, gold = 0, bossIdx = 1, time = time() }
        store[cfg.key] = rec
    end
    if rec then
        rec.killed = rec.killed or {}
        rec.visited = rec.visited or {}
        state.killed = rec.killed
        state.visited = rec.visited
        state.bossIdx = rec.bossIdx or 1
        state.gold = rec.gold or 0
    else
        state.killed = {}
        state.visited = {}
        state.bossIdx = 1
        state.gold = 0
    end
    return rec
end

-- Call after any change to kill marks, visited waypoints or the selected boss.
local function TouchProgress()
    local cfg = state.cfg
    if not cfg or state.testMode then return end
    local rec = DB().progress[cfg.key]
    if not rec or rec.killed ~= state.killed then
        rec = { killed = state.killed, visited = state.visited }
        DB().progress[cfg.key] = rec
    end
    rec.bossIdx = state.bossIdx
    rec.gold = state.gold or 0
    rec.time = time()
end

local function ClearProgress(cfg)
    state.killed = {}
    state.visited = {}
    state.gold = 0
    if cfg then DB().progress[cfg.key] = nil end
    if cfg and not state.testMode then
        DB().progress[cfg.key] = { killed = state.killed, visited = state.visited, gold = 0, bossIdx = state.bossIdx, time = time() }
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

-- Call on login and after every loading screen so the first roster event
-- compares against the real state instead of a stale flag.
local function SyncGroupState()
    state.inGroup = IsGrouped()
end

-- Call on GROUP_ROSTER_UPDATE. Returns true when progress was wiped.
local function OnGroupRosterChanged()
    local was = state.inGroup
    local now = IsGrouped()
    state.inGroup = now
    if not was or now then return false end
    local store = DB().progress
    for key in pairs(store) do store[key] = nil end
    ClearProgress(state.cfg)
    return true
end

-- shared with the other BossNav files
ns.ClearProgress = ClearProgress
ns.OnGroupRosterChanged = OnGroupRosterChanged
ns.SyncGroupState = SyncGroupState
ns.LoadProgress = LoadProgress
ns.TouchProgress = TouchProgress
