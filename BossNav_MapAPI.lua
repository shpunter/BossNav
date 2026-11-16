-- Guarded access to the client's map API.
local ADDON, ns = ...
-- from the files loaded before this one
local Norm                   = ns.Norm
local state                  = ns.state

--------------------------------------------------------------------------
-- C_Map access (all guarded; this client may hide or restrict any of it)
--------------------------------------------------------------------------
-- Find a uiMapID by its display name. The client's map list is scanned once
-- (lowest ID wins for a repeated name, which is the zone map) and kept.
local mapNameIndex = nil
local function ResolveMapIDByName(name)
    if not (name and C_Map and C_Map.GetMapInfo) then return nil end
    local key = Norm(name)
    if not key or key == "" then return nil end
    if not mapNameIndex then
        mapNameIndex = {}
        for id = 1, 6000 do
            local ok, info = pcall(C_Map.GetMapInfo, id)
            if ok and info and info.name then
                local k = Norm(info.name)
                if k and k ~= "" and not mapNameIndex[k] then mapNameIndex[k] = id end
            end
        end
    end
    return mapNameIndex[key]
end

local function PlayerMapID()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
    if ok and type(id) == "number" then return id end
    -- The client gave no map for the player; try the dungeon's own map by name.
    if state and state.cfg and state.inInstance then
        for _, z in ipairs(state.cfg.zones) do
            local byName = ResolveMapIDByName(z)
            if byName then return byName end
        end
    end
    return nil
end

local function PlayerPos(mapID)
    if not (mapID and C_Map and C_Map.GetPlayerMapPosition) then return nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or not pos or not pos.GetXY then return nil end
    local ok2, x, y = pcall(pos.GetXY, pos)
    if not ok2 or type(x) ~= "number" or type(y) ~= "number" then return nil end
    if x <= 0 or y <= 0 or x >= 1 or y >= 1 then return nil end
    return x, y
end

local function PlayerFacing()
    if not GetPlayerFacing then return nil end
    local ok, f = pcall(GetPlayerFacing)
    if ok and type(f) == "number" then return f end
    return nil
end

local function MapWorldSize(mapID)
    if not (mapID and C_Map and C_Map.GetMapWorldSize) then return nil end
    local ok, w, h = pcall(C_Map.GetMapWorldSize, mapID)
    if ok and type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then return w, h end
    return nil
end

local function MapName(mapID)
    if not (mapID and C_Map and C_Map.GetMapInfo) then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    if ok and info and info.name then return info.name end
    return nil
end

-- Which of the dungeon's floors the player's uiMap corresponds to, using the
-- client's map group (multi-floor maps are grouped by height index).
local function FloorFromMapGroup(cfg, mapID)
    if not (cfg and mapID and C_Map and C_Map.GetMapGroupID and C_Map.GetMapGroupMembersInfo) then return nil end
    local ok, groupID = pcall(C_Map.GetMapGroupID, mapID)
    if not ok or not groupID then return nil end
    local ok2, members = pcall(C_Map.GetMapGroupMembersInfo, groupID)
    if not ok2 or type(members) ~= "table" or #members == 0 then return nil end
    table.sort(members, function(a, b) return (a.relativeHeightIndex or 0) < (b.relativeHeightIndex or 0) end)
    for idx, m in ipairs(members) do
        if m.mapID == mapID then return cfg.floors[idx] end
    end
    return nil
end

-- shared with the other BossNav files
ns.FloorFromMapGroup = FloorFromMapGroup
ns.MapName = MapName
ns.MapWorldSize = MapWorldSize
ns.PlayerFacing = PlayerFacing
ns.PlayerMapID = PlayerMapID
ns.PlayerPos = PlayerPos
ns.ResolveMapIDByName = ResolveMapIDByName
