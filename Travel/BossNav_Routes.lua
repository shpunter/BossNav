-- Routing between zones: which exit of your zone leads toward the dungeon,
-- or, when flying is chosen, which flight master to use when a flight path
-- is known at both ends.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local EntranceOf             = ns.EntranceOf
local MapName                = ns.MapName
local MapWorldSize           = ns.MapWorldSize
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
    -- Riverglades (WoW Forever). Guides give no coordinates for the land
    -- roads, so these spots are estimates: walking a border once saves the
    -- exact spot (BossNav_Crossings.lua), which then replaces them.
    { "Redridge Mountains", 45, 8, "Riverglades", 6, 55, how = "right fork at the signpost before the Burning Steppes gate" },
    { "Badlands", 45, 95,       "Riverglades", 40, 5, how = "road south from the Badlands" },
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
    { "Tanaris", 68.6, 23.0,    "Riverglades", 80.6, 54.6, how = "boat Steamwheedle Port - Powderfuse Port" },
    { "Wetlands", 5, 57,        "Dustwallow Marsh", 71, 56, how = "boat Menethil - Theramore", faction = A },
    { "Wetlands", 5, 57,        "Darkshore", 36, 45, how = "boat Menethil - Auberdine", faction = A },
    { "Durotar", 51, 12,        "Tirisfal Glades", 62, 59, how = "zeppelin Orgrimmar - Undercity", faction = H },
    { "Durotar", 51, 12,        "Stranglethorn Vale", 32, 29, how = "zeppelin Orgrimmar - Grom'gol", faction = H },
    { "Tirisfal Glades", 62, 59, "Stranglethorn Vale", 32, 29, how = "zeppelin Undercity - Grom'gol", faction = H },
}

-- Adjacency: GRAPH[zoneKey] = { { to = zoneKey, zone = "Name", x, y, tx, ty, how, faction }, ... }
-- x, y is the crossing in this zone, tx, ty where it lands you in the next.
local GRAPH = {}
local ZONE_NAME = {}
local function AddEdge(from, to, x, y, tx, ty, how, faction)
    local fk, tk = Norm(from), Norm(to)
    ZONE_NAME[fk] = from
    ZONE_NAME[tk] = to
    GRAPH[fk] = GRAPH[fk] or {}
    table.insert(GRAPH[fk], { to = tk, zone = to, x = x, y = y, tx = tx, ty = ty, how = how, faction = faction })
end
for _, l in ipairs(LINKS) do
    AddEdge(l[1], l[4], l[2], l[3], l[5], l[6], l.how, l.faction)
    AddEdge(l[4], l[1], l[5], l[6], l[2], l[3], l.how, l.faction)
end

-- A link you ride (boat, zeppelin, tram, portal) rather than walk over.
local function IsRide(edge)
    local how = edge.how or ""
    return how:find("^boat") or how:find("^zeppelin") or how:find("Tram") or how:find("portal")
end

-- The crossings out of a zone. Spots you walked over yourself
-- (BossNav_Crossings.lua saves them in DB().crossings) replace the built-in
-- guesses for that pair of zones and add borders the list above lacks.
local function EdgesFrom(key)
    local learned = DB().crossings and DB().crossings[key]
    if not learned then return GRAPH[key] or {} end
    local list = {}
    for _, e in ipairs(GRAPH[key] or {}) do
        if not learned[e.to] or IsRide(e) then list[#list + 1] = e end
    end
    for toKey, spots in pairs(learned) do
        for _, c in ipairs(spots) do
            list[#list + 1] = { to = toKey, zone = ZONE_NAME[toKey] or c.zone,
                x = c.x, y = c.y, tx = c.tx, ty = c.ty }
        end
    end
    return list
end

-- True for a zone the router knows (so a crossing into it is worth saving).
local function IsRouteZone(key)
    return key ~= nil and GRAPH[key] ~= nil
end

-- "Alliance" or "Horde", or nil when the client will not say.
local function PlayerFaction()
    local ok, f = pcall(UnitFactionGroup, "player")
    if ok and (f == "Alliance" or f == "Horde") then return f end
    return nil
end

-- Size of a zone in yards (cached). A zone the client will not measure
-- counts as an average classic zone, so it still gets a fair cost.
local DEFAULT_W, DEFAULT_H = 3500, 2330
local SIZE = {}
local function ZoneSize(key)
    local s = SIZE[key]
    if not s then
        local w, h = MapWorldSize(ResolveMapIDByName(ZONE_NAME[key] or ""))
        s = { w or DEFAULT_W, h or DEFAULT_H }
        SIZE[key] = s
    end
    return s[1], s[2]
end

-- Yards between two spots (percent of the zone's map) inside one zone.
local function Yards(key, x1, y1, x2, y2)
    local w, h = ZoneSize(key)
    local dx, dy = (x2 - x1) / 100 * w, (y2 - y1) / 100 * h
    return math.sqrt(dx * dx + dy * dy)
end

-- Extra cost of a crossing, in yards of running: waiting for and riding a
-- boat or zeppelin takes minutes, the tram about one.
local function CrossingCost(edge)
    local how = edge.how or ""
    if how:find("^boat") or how:find("^zeppelin") then return 1500 end
    if how:find("Tram") then return 500 end
    return 0
end

-- Shortest path by distance, using only links your faction can take: from
-- your spot (sx, sy percent of your zone) through the crossings to the goal
-- spot (gx, gy percent of the goal zone). Returns the list of edges to walk,
-- or nil when no road leads there.
local function FindPath(fromKey, sx, sy, toKey, gx, gy, faction)
    if not (GRAPH[fromKey] and GRAPH[toKey]) then return nil end
    if fromKey == toKey then return {} end
    -- a node is where you stand in a zone: the start, or a crossing's far side
    local nodes = { { zone = fromKey, x = sx, y = sy, cost = 0 } }
    local best, done = nil, {}
    while true do
        local cur, ci = nil, nil
        for i, n in ipairs(nodes) do
            if not done[i] and (not cur or n.cost < cur.cost) then cur, ci = n, i end
        end
        if not cur or (best and cur.cost >= best.cost) then break end
        done[ci] = true
        if cur.zone == toKey then
            local total = cur.cost + Yards(toKey, cur.x, cur.y, gx, gy)
            if not best or total < best.cost then best = { cost = total, node = cur } end
        end
        for _, edge in ipairs(EdgesFrom(cur.zone)) do
            local allowed = not edge.faction or not faction or edge.faction == faction
            if allowed then
                local cost = cur.cost + Yards(cur.zone, cur.x, cur.y, edge.x, edge.y) + CrossingCost(edge)
                -- the same landing spot reached again: keep the cheaper way
                local found = nil
                for i, n in ipairs(nodes) do
                    if n.zone == edge.to and n.x == edge.tx and n.y == edge.ty then found = i break end
                end
                if not found then
                    nodes[#nodes + 1] = { zone = edge.to, x = edge.tx, y = edge.ty, cost = cost, prev = cur, edge = edge }
                elseif not done[found] and cost < nodes[found].cost then
                    local n = nodes[found]
                    n.cost, n.prev, n.edge = cost, cur, edge
                end
            end
        end
    end
    if not best then return nil end
    local path, n = {}, best.node
    while n.edge do
        table.insert(path, 1, n.edge)
        n = n.prev
    end
    return path
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
    local saved = ns.SavedEntrance(entry)
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

    -- your spot on the zone's own map (you may be standing on a city or
    -- area map inside it); the zone's middle when the client will not say
    local curMap = ResolveMapIDByName(ZONE_NAME[curKey] or "") or playerMapID
    if curMap ~= playerMapID and C_Map and C_Map.GetPlayerMapPosition then
        local ok, pos = pcall(C_Map.GetPlayerMapPosition, curMap, "player")
        local zx, zy
        if ok and pos then pcall(function() zx, zy = pos:GetXY() end) end
        if type(zx) == "number" and type(zy) == "number" then px, py = zx, zy end
    end
    local sx, sy = (px or 0.5) * 100, (py or 0.5) * 100
    local path = FindPath(curKey, sx, sy, destKey, ex * 100, ey * 100, faction)
    if not path or #path == 0 then
        entrance.kind = "direct"
        entrance.text = "No road for " .. (faction or "you") .. " between " .. (ZONE_NAME[curKey] or GetRealZoneText() or "here") .. " and " .. destZone .. "; straight line shown"
        return entrance
    end

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
ns.IsRouteZone = IsRouteZone
ns.NextLeg = NextLeg
ns.PlayerFaction = PlayerFaction
ns.ROUTE_MODES = ROUTE_MODES
ns.RouteMode = RouteMode
ns.SetRouteMode = SetRouteMode
