-- Routing between zones: which exit of your zone leads toward the dungeon,
-- or, when flying is chosen, which flight master to use when a flight path
-- is known at both ends.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local EntranceOf             = ns.EntranceOf
local MapName                = ns.MapName
local Norm                   = ns.Norm
local ResolveMapIDByName     = ns.ResolveMapIDByName

--------------------------------------------------------------------------
-- How you travel, chosen with the boxes under the map or /bnav route and
-- saved: "foot" walks zone to zone (roads, boats, zeppelins); "fly" takes a
-- flight master whenever a flight path is known at both ends, and walks
-- toward the next zone until one is.
--------------------------------------------------------------------------
local ROUTE_MODES = {
    { key = "foot", label = "By foot", words = "zone exits, boats and zeppelins" },
    { key = "fly",  label = "Flying",  words = "flight masters where a path is known at both ends" },
}
local ROUTE_BY_KEY = {}
for _, m in ipairs(ROUTE_MODES) do ROUTE_BY_KEY[m.key] = m end

local function RouteMode()
    local m = DB().travelBy
    return ROUTE_BY_KEY[m] and m or "fly"
end

-- Returns the mode's entry when the key is valid, nil otherwise.
local function SetRouteMode(key)
    local m = ROUTE_BY_KEY[key]
    if not m then return nil end
    DB().travelBy = key
    return m
end

--------------------------------------------------------------------------
-- Zone links: { "Zone A", ax, ay, "Zone B", bx, by, how = "...", faction = "..." }.
-- ax, ay is the crossing point as percent of zone A's map, bx, by the same
-- spot seen from zone B. Spots are approximate classic road crossings: the
-- arrow only has to get you over the border, the route is re-planned in the
-- next zone. faction = "Alliance" or "Horde" marks a link only that side can
-- use: capital city gates, the tram, zeppelins and the Alliance boats.
--------------------------------------------------------------------------
local A, H = "Alliance", "Horde"
local LINKS = {
    -- Eastern Kingdoms
    { "Elwynn Forest", 32, 50,  "Stormwind City", 78, 94, faction = A },
    { "Elwynn Forest", 23, 94,  "Westfall", 58, 9 },
    { "Elwynn Forest", 88, 79,  "Redridge Mountains", 9, 60 },
    { "Elwynn Forest", 55, 96,  "Duskwood", 51, 6 },
    { "Westfall", 70, 46,       "Duskwood", 8, 38 },
    { "Duskwood", 90, 46,       "Deadwind Pass", 20, 50 },
    { "Deadwind Pass", 90, 45,  "Swamp of Sorrows", 5, 50 },
    { "Swamp of Sorrows", 23, 93, "Blasted Lands", 46, 8 },
    { "Duskwood", 74, 95,       "Stranglethorn Vale", 38, 5 },
    { "Redridge Mountains", 34, 8, "Burning Steppes", 78, 90 },
    { "Burning Steppes", 30, 38, "Searing Gorge", 35, 84, how = "through Blackrock Mountain" },
    { "Searing Gorge", 38, 8,   "Loch Modan", 33, 87, how = "Stonewrought Pass gate" },
    { "Searing Gorge", 88, 45,  "Badlands", 4, 46, how = "Kargath tunnel" },
    { "Badlands", 5, 38,        "Loch Modan", 51, 88 },
    { "Dun Morogh", 90, 48,     "Loch Modan", 17, 68, how = "North Gate Pass" },
    { "Dun Morogh", 52, 36,     "Ironforge", 25, 75, faction = A },
    { "Ironforge", 76, 52,      "Stormwind City", 65, 9, how = "Deeprun Tram", faction = A },
    { "Loch Modan", 31, 9,      "Wetlands", 48, 69, how = "Dun Algaz" },
    { "Wetlands", 50, 8,        "Arathi Highlands", 45, 93, how = "Thandol Span" },
    { "Arathi Highlands", 20, 60, "Hillsbrad Foothills", 85, 50, how = "Thoradin's Wall" },
    { "Hillsbrad Foothills", 55, 12, "Alterac Mountains", 55, 85 },
    { "Hillsbrad Foothills", 14, 38, "Silverpine Forest", 60, 87 },
    { "Hillsbrad Foothills", 90, 28, "The Hinterlands", 10, 48 },
    { "Silverpine Forest", 50, 10, "Tirisfal Glades", 56, 84 },
    { "Tirisfal Glades", 63, 66, "Undercity", 63, 40, how = "Ruins of Lordaeron", faction = H },
    { "Tirisfal Glades", 85, 68, "Western Plaguelands", 26, 53, how = "the Bulwark" },
    { "Western Plaguelands", 93, 70, "Eastern Plaguelands", 8, 68, how = "Thondroril River bridge" },
    { "Western Plaguelands", 43, 86, "Alterac Mountains", 68, 25, how = "Chillwind Camp road" },
    -- Kalimdor
    { "Durotar", 46, 13,        "Orgrimmar", 50, 92, faction = H },
    { "Durotar", 33, 47,        "The Barrens", 62, 19 },
    { "The Barrens", 31, 30,    "Mulgore", 73, 47 },
    { "Mulgore", 47, 56,        "Thunder Bluff", 38, 62, how = "the elevators", faction = H },
    { "The Barrens", 43, 6,     "Ashenvale", 90, 70, how = "Mor'shan Rampart" },
    { "The Barrens", 33, 22,    "Stonetalon Mountains", 85, 92 },
    { "The Barrens", 71, 50,    "Dustwallow Marsh", 30, 28 },
    { "The Barrens", 45, 92,    "Thousand Needles", 10, 14, how = "the Great Lift" },
    { "Thousand Needles", 96, 62, "Tanaris", 50, 8 },
    { "Thousand Needles", 8, 35, "Feralas", 90, 44 },
    { "Feralas", 62, 8,         "Desolace", 55, 93 },
    { "Desolace", 64, 8,        "Stonetalon Mountains", 28, 90 },
    { "Stonetalon Mountains", 75, 40, "Ashenvale", 15, 65, how = "Talondeep Path" },
    { "Ashenvale", 22, 12,      "Darkshore", 45, 90 },
    { "Darkshore", 36, 45,      "Teldrassil", 55, 92, how = "boat from Auberdine", faction = A },
    { "Teldrassil", 55, 92,     "Darnassus", 40, 55, how = "the portal at Rut'theran", faction = A },
    { "Ashenvale", 68, 12,      "Felwood", 55, 92 },
    { "Felwood", 65, 8,         "Winterspring", 28, 48, how = "Timbermaw Hold" },
    { "Felwood", 65, 8,         "Moonglade", 28, 55, how = "Timbermaw Hold" },
    { "Ashenvale", 93, 42,      "Azshara", 10, 75 },
    { "Tanaris", 30, 48,        "Un'Goro Crater", 77, 50 },
    { "Un'Goro Crater", 30, 75, "Silithus", 80, 18 },
    -- Boats and zeppelins (between continents)
    { "Stranglethorn Vale", 27, 77, "The Barrens", 63, 38, how = "boat Booty Bay - Ratchet" },
    { "Wetlands", 5, 57,        "Dustwallow Marsh", 71, 56, how = "boat Menethil - Theramore", faction = A },
    { "Wetlands", 5, 57,        "Darkshore", 36, 45, how = "boat Menethil - Auberdine", faction = A },
    { "Durotar", 51, 12,        "Tirisfal Glades", 62, 59, how = "zeppelin Orgrimmar - Undercity", faction = H },
    { "Durotar", 51, 12,        "Stranglethorn Vale", 32, 29, how = "zeppelin Orgrimmar - Grom'gol", faction = H },
    { "Tirisfal Glades", 62, 59, "Stranglethorn Vale", 32, 29, how = "zeppelin Undercity - Grom'gol", faction = H },
}

-- Adjacency: GRAPH[zoneKey] = { { to = zoneKey, zone = "Name", x, y, how, faction }, ... }
local GRAPH = {}
local ZONE_NAME = {}
local function AddEdge(from, to, x, y, how, faction)
    local fk, tk = Norm(from), Norm(to)
    ZONE_NAME[fk] = from
    ZONE_NAME[tk] = to
    GRAPH[fk] = GRAPH[fk] or {}
    table.insert(GRAPH[fk], { to = tk, zone = to, x = x, y = y, how = how, faction = faction })
end
for _, l in ipairs(LINKS) do
    AddEdge(l[1], l[4], l[2], l[3], l.how, l.faction)
    AddEdge(l[4], l[1], l[5], l[6], l.how, l.faction)
end

-- "Alliance" or "Horde", or nil when the client will not say.
local function PlayerFaction()
    local ok, f = pcall(UnitFactionGroup, "player")
    if ok and (f == "Alliance" or f == "Horde") then return f end
    return nil
end

-- Shortest path by zone count, using only links your faction can take.
-- Returns the list of edges to walk, or nil.
local function FindPath(fromKey, toKey, faction)
    if not (GRAPH[fromKey] and GRAPH[toKey]) then return nil end
    if fromKey == toKey then return {} end
    local prev, queue, seen = {}, { fromKey }, { [fromKey] = true }
    local head = 1
    while head <= #queue do
        local cur = queue[head]
        head = head + 1
        for _, edge in ipairs(GRAPH[cur]) do
            local allowed = not edge.faction or not faction or edge.faction == faction
            if allowed and not seen[edge.to] then
                seen[edge.to] = true
                prev[edge.to] = { from = cur, edge = edge }
                if edge.to == toKey then
                    local path, k = {}, toKey
                    while prev[k] do
                        table.insert(path, 1, prev[k].edge)
                        k = prev[k].from
                    end
                    return path
                end
                queue[#queue + 1] = edge.to
            end
        end
    end
    return nil
end

--------------------------------------------------------------------------
-- Flight masters you have learned, per uiMap (modern taxi API; nil when the
-- client has none). Each: { name, x, y } with x, y as 0..1 of that map.
--------------------------------------------------------------------------
-- True when a flight master belongs to the other faction (the game lists
-- both sides; its own world map hides the enemy ones, so we do too).
local function IsEnemyNode(n, playerFaction)
    if not playerFaction then return false end
    local fac = Enum and Enum.FlightPathFaction or {}
    local horde = fac.Horde or 1
    local alliance = fac.Alliance or 2
    if n.faction == horde then return playerFaction ~= "Horde" end
    if n.faction == alliance then return playerFaction ~= "Alliance" end
    return false
end

-- Every flight master on a uiMap your faction can use: { name, x, y, known,
-- current }. known is false for one you have not discovered yet; current is
-- the one you stand at.
local function FlightNodes(mapID)
    if not (mapID and C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then return nil end
    local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
    if not ok or type(nodes) ~= "table" then return nil end
    local states = Enum and Enum.FlightPathState or {}
    local unreachable = states.Unreachable or 2
    local current = states.Current or 0
    local playerFaction = PlayerFaction()
    local list = {}
    for _, n in ipairs(nodes) do
        pcall(function()
            if n.position and type(n.name) == "string" and not IsEnemyNode(n, playerFaction) then
                local x, y = n.position.x, n.position.y
                if type(x) == "number" and type(y) == "number" then
                    list[#list + 1] = { name = n.name, x = x, y = y,
                        known = n.state ~= unreachable, current = n.state == current }
                end
            end
        end)
    end
    return list
end

-- Only the flight masters you have learned (used for routing).
local function KnownFlightNodes(mapID)
    local all = FlightNodes(mapID)
    if not all then return nil end
    local list = {}
    for _, n in ipairs(all) do
        if n.known then list[#list + 1] = n end
    end
    return list
end

local function NearestNode(list, fx, fy)
    local best, bestD = nil, nil
    for _, n in ipairs(list or {}) do
        local d = (n.x - (fx or 0.5)) ^ 2 + (n.y - (fy or 0.5)) ^ 2
        if not bestD or d < bestD then best, bestD = n, d end
    end
    return best
end

--------------------------------------------------------------------------
-- The next leg toward a dungeon. Returns a table:
--   mapID, fx, fy   where to go now (0..1 of that uiMap)
--   kind            "entrance" | "exit" | "flight" | "direct"
--   text            what to do there, in words
--   zonesLeft       zones still to cross after this leg
-- or nil when no entrance is known at all.
--------------------------------------------------------------------------
local function CurrentZoneKey(playerMapID)
    local z = Norm(GetRealZoneText())
    if z and GRAPH[z] then return z end
    local m = Norm(MapName(playerMapID))
    if m and GRAPH[m] then return m end
    return z or m
end

local function NextLeg(entry, playerMapID, px, py)
    local emap, ex, ey, where = EntranceOf(entry)
    if not ex then return nil end
    local entrance = { mapID = emap, fx = ex, fy = ey, kind = "entrance", text = "Entrance: " .. (where or "?"), zonesLeft = 0 }

    local destZone = entry.zone
    local saved = DB().entrances and DB().entrances[entry.key]
    if saved and saved.zone then destZone = saved.zone end
    local destKey = Norm(destZone)
    local curKey = CurrentZoneKey(playerMapID)
    local faction = PlayerFaction()

    -- A dungeon inside the other faction's city: no road leads there for you.
    if entry.faction and faction and entry.faction ~= faction then
        entrance.kind = "direct"
        entrance.text = "Inside " .. (destZone or "an enemy city") .. ", a " .. entry.faction .. " city; straight line shown"
        return entrance
    end
    if not (destKey and curKey) or destKey == curKey then return entrance end

    local path = FindPath(curKey, destKey, faction)
    if not path or #path == 0 then
        entrance.kind = "direct"
        entrance.text = "No road for " .. (faction or "you") .. " between " .. (ZONE_NAME[curKey] or GetRealZoneText() or "here") .. " and " .. destZone .. "; straight line shown"
        return entrance
    end

    local curMap = ResolveMapIDByName(ZONE_NAME[curKey] or "") or playerMapID

    -- Flying: a flight path learned at both ends takes you to the zone.
    local flying = RouteMode() == "fly"
    if flying then
        local here = NearestNode(KnownFlightNodes(curMap), px, py)
        local there = NearestNode(KnownFlightNodes(emap), ex, ey)
        if here and there and here.name ~= there.name then
            return { mapID = curMap, fx = here.x, fy = here.y, kind = "flight",
                text = "Flight master " .. here.name .. ": fly to " .. there.name, zonesLeft = 1 }
        end
    end

    -- On foot, or flying with no usable flight path yet: the zone exit.
    local edge = path[1]
    local how = edge.how and (" (" .. edge.how .. ")") or ""
    local noFlight = flying and ", no flight path known yet" or ""
    return { mapID = curMap, fx = edge.x / 100, fy = edge.y / 100, kind = "exit",
        text = "Exit to " .. edge.zone .. how .. noFlight, zonesLeft = #path - 1 }
end

-- shared with the other BossNav files
ns.FlightNodes = FlightNodes
ns.NextLeg = NextLeg
ns.PlayerFaction = PlayerFaction
ns.ROUTE_MODES = ROUTE_MODES
ns.RouteMode = RouteMode
ns.SetRouteMode = SetRouteMode
