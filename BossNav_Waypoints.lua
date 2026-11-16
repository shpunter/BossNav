-- Boss selection, floors and waypoints.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local state                  = ns.state

--------------------------------------------------------------------------
-- Selection / floors / waypoints
--------------------------------------------------------------------------
local function SelectedBoss()
    local cfg = state.cfg
    return cfg and cfg.bosses[state.bossIdx] or nil
end

local function KilledCount(cfg)
    local n = 0
    for _, b in ipairs(cfg.bosses) do
        if state.killed[b[1]] then n = n + 1 end
    end
    return n
end

local function CurrentFloor(cfg)
    if state.floorOverride then return state.floorOverride end
    if state.autoFloor then return state.autoFloor end
    if cfg.floorBySubzone then
        local f = cfg.floorBySubzone[GetSubZoneText() or ""]
        if f then return f end
    end
    local boss = SelectedBoss()
    if boss and boss[4] then return boss[4] end
    return cfg.floors[1]
end

-- Built-in draft trail for a boss, converted once to the saved-waypoint shape.
local function DefaultWaypoints(cfg, boss)
    local draft = cfg.routes and cfg.routes[boss[1]]
    if not draft then return nil end
    if not draft.converted then
        local list = {}
        for i, d in ipairs(draft) do
            list[i] = { x = d[1], y = d[2], note = d[3], floor = boss[4] or cfg.floors[1] }
        end
        draft.converted = list
    end
    return draft.converted
end

-- Your own saved waypoints win over the draft; an empty saved list means "cleared".
local function Waypoints(cfg, boss)
    if not cfg or not boss then return nil end
    local routes = DB().routes
    local own = routes[cfg.key] and routes[cfg.key][boss[1]]
    if own then return own end
    return DefaultWaypoints(cfg, boss)
end

-- Make the boss's waypoint list editable: copies the draft into saved variables first.
local function EditableWaypoints(cfg, boss)
    local routes = DB().routes
    routes[cfg.key] = routes[cfg.key] or {}
    if not routes[cfg.key][boss[1]] then
        local copy = {}
        for i, wp in ipairs(DefaultWaypoints(cfg, boss) or {}) do
            copy[i] = { x = wp.x, y = wp.y, note = wp.note, floor = wp.floor }
        end
        routes[cfg.key][boss[1]] = copy
    end
    return routes[cfg.key][boss[1]]
end

local function WaypointKey(cfg, boss, idx)
    return cfg.key .. "|" .. boss[1] .. "|" .. idx
end

-- shared with the other BossNav files
ns.CurrentFloor = CurrentFloor
ns.EditableWaypoints = EditableWaypoints
ns.KilledCount = KilledCount
ns.SelectedBoss = SelectedBoss
ns.WaypointKey = WaypointKey
ns.Waypoints = Waypoints
