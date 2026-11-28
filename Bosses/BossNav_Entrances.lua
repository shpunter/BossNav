-- Dungeon entrances in the open world, and the travel list (dungeons by level).
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local DUNGEONS               = ns.DUNGEONS
local Norm                   = ns.Norm
local PartViews              = ns.PartViews
local ResolveMapIDByName     = ns.ResolveMapIDByName

--------------------------------------------------------------------------
-- Entrance of every dungeon: the zone map it sits on, plus percent across and
-- percent down that zone map. Level ranges are the game's own, from its group
-- finder (GroupFinderActivity table, WoW Forever build 1.60.1.71037, via
-- wago.tools). A dungeon the game lists in parts (BossNav_Parts.lua) has a
-- row per part here for its levels; zone and spot come from the whole
-- dungeon's row until /bnav entrance records the part's own. The coordinates are the classic
-- entrance spots and are unverified on this client: standing at a portal and
-- typing /bnav entrance records the real one, which then wins over this list.
-- raid = true sorts the entry after the dungeons of the same level.
-- A dungeon without zone/x/y shows as "no entrance" until one is recorded.
--------------------------------------------------------------------------
local ENTRANCES = {
    ["Ragefire Chasm"]            = { zone = "Orgrimmar",            x = 52.8, y = 49.0, levels = {13, 18}, faction = "Horde" },
    ["Wailing Caverns"]           = { zone = "The Barrens",          x = 46.1, y = 36.4, levels = {15, 24} },
    ["The Deadmines"]             = { zone = "Westfall",             x = 42.6, y = 71.6, levels = {17, 26} },
    ["Shadowfang Keep"]           = { zone = "Silverpine Forest",    x = 44.8, y = 67.8, levels = {20, 30} },
    ["The Stockade"]              = { zone = "Stormwind City",       x = 50.6, y = 66.4, levels = {24, 32}, faction = "Alliance" },
    ["Blackfathom Deeps"]         = { zone = "Ashenvale",            x = 14.4, y = 14.5, levels = {24, 32} },
    ["Gnomeregan"]                = { zone = "Dun Morogh",           x = 24.4, y = 39.7, levels = {29, 38} },
    ["Razorfen Kraul"]            = { zone = "The Barrens",          x = 42.2, y = 89.8, levels = {29, 38} },
    ["Scarlet Monastery"]         = { zone = "Tirisfal Glades",      x = 84.9, y = 30.9 },
    ["Scarlet Graveyard"]         = { levels = {30, 38} },
    ["Scarlet Library"]           = { levels = {33, 41} },
    ["Scarlet Armory"]            = { levels = {36, 44} },
    ["Scarlet Cathedral"]         = { levels = {38, 46} },
    ["Razorfen Downs"]            = { zone = "The Barrens",          x = 50.8, y = 92.8, levels = {37, 46} },
    ["Uldaman"]                   = { zone = "Badlands",             x = 42.4, y = 18.6, levels = {41, 51} },
    ["Zul'Farrak"]                = { zone = "Tanaris",              x = 39.0, y = 20.2, levels = {44, 54} },
    ["Maraudon"]                  = { zone = "Desolace",             x = 29.1, y = 62.5, levels = {46, 55} },
    ["The Temple of Atal'Hakkar"] = { zone = "Swamp of Sorrows",     x = 69.7, y = 53.4, levels = {50, 60} },
    ["Blackrock Depths"]          = { zone = "Searing Gorge",        x = 35.4, y = 84.4, levels = {52, 60}, via = "Blackrock Mountain" },
    ["Blackrock Spire"]           = { zone = "Searing Gorge",        x = 35.4, y = 84.4, via = "Blackrock Mountain" },
    ["Lower Blackrock Spire"]     = { levels = {55, 60} },
    ["Upper Blackrock Spire"]     = { levels = {59, 60} },
    ["Scholomance"]               = { zone = "Western Plaguelands",  x = 69.3, y = 73.2, levels = {58, 60} },
    ["Stratholme"]                = { zone = "Eastern Plaguelands",  x = 30.8, y = 14.4 },
    ["Stratholme (Main Gate)"]    = { levels = {58, 60} },
    ["Stratholme (Service Gate)"] = { levels = {58, 60} },
    ["Dire Maul"]                 = { zone = "Feralas",              x = 59.3, y = 44.5 },
    ["Dire Maul (East)"]          = { levels = {54, 60} },
    ["Dire Maul (West)"]          = { levels = {56, 60} },
    ["Dire Maul (North)"]         = { levels = {56, 60} },
    -- Raids
    ["Molten Core"]               = { zone = "Searing Gorge",        x = 35.4, y = 84.4, levels = {60, 60}, via = "Blackrock Mountain", raid = true },
    ["Onyxia's Lair"]             = { zone = "Dustwallow Marsh",     x = 52.6, y = 76.5, levels = {60, 60}, raid = true },
    ["Zul'Gurub"]                 = { zone = "Stranglethorn Vale",   x = 53.6, y = 17.5, levels = {60, 60}, raid = true },
    ["Blackwing Lair"]            = { zone = "Searing Gorge",        x = 35.4, y = 84.4, levels = {60, 60}, via = "Blackrock Mountain", raid = true },
    ["Ruins of Ahn'Qiraj"]        = { zone = "Silithus",             x = 29.0, y = 93.0, levels = {60, 60}, raid = true },
    ["Ahn'Qiraj"]                 = { zone = "Silithus",             x = 29.0, y = 93.0, levels = {60, 60}, raid = true },
    -- WoW Forever dungeons. Spots come from web guides (Nov 2026), which disagree
    -- by a few percent; /bnav entrance at the portal records the exact one.
    -- Hall of Thanes: the passage off the High Seat into Old Ironforge; the portal is at the bottom.
    ["The Hall of Thanes"]        = { zone = "Ironforge",            x = 43.5, y = 52.0, levels = {13, 20}, faction = "Alliance" },
    -- Ruins of Lordaeron: the ruined keep above the Undercity.
    ["Ruins of Lordaeron"]        = { zone = "Tirisfal Glades",      x = 63.3, y = 67.5, levels = {15, 22} },
    -- Excavation Site: hilltop southeast of Whelgar's Excavation Site.
    ["Excavation Site: Wetlands"] = { zone = "Wetlands",             x = 48.1, y = 56.5, levels = {26, 33} },
    -- City of Dalaran: sewer gate on the northwest wall by Lordamere Lake (needs the Dalaran Sewer Key).
    ["City of Dalaran"]           = { zone = "Alterac Mountains",    x = 8.0,  y = 61.2, levels = {28, 35} },
    -- Half-Pint Tavern: datamined only, not in the game; no entrance.
    ["Half-Pint Tavern"]          = { },
    -- Drowned City: underwater past the Vile Reef, a cavern with a large tablet by the water-elemental island.
    ["The Drowned City"]          = { zone = "Stranglethorn Vale",   x = 21.4, y = 27.9, levels = {35, 42} },
    -- in the game's group finder, entrance not known yet
    ["Krol'dok Stronghold"]       = { levels = {40, 47} },
    ["Alcaz Prison"]              = { levels = {48, 55} },
    ["Blackmaw Hold"]             = { levels = {55, 60} },
    ["The Shaper's Terrace"]      = { levels = {58, 60} },
}

--------------------------------------------------------------------------
-- Travel list: every dungeon BossNav knows, sorted by level, raids last.
-- A dungeon the game lists in parts gets a row per part; its cfg is then the
-- part view (BossNav_Parts.lua) and its key the part's own.
-- Entry: { key, name, cfg, zone, x, y, via, raid, levels = "18-23" }
--------------------------------------------------------------------------
local TRAVEL = {}
-- where: the zone, spot and side; lv: the row whose levels to use
local function AddRow(key, cfg, where, lv, order)
    local lo, hi = lv.levels and lv.levels[1] or nil, lv.levels and lv.levels[2] or nil
    local levels = "?"
    if lo and hi then levels = (lo == hi) and tostring(lo) or (lo .. "-" .. hi) end
    TRAVEL[#TRAVEL + 1] = {
        key = key, name = cfg.name, cfg = cfg,
        zone = where.zone, x = where.x, y = where.y, via = where.via, raid = where.raid or false, faction = where.faction,
        lo = lo or 99, hi = hi or lo or 99, minLevel = lo, maxLevel = hi, levels = levels, order = order,
    }
end
for i, cfg in ipairs(DUNGEONS) do
    local e = ENTRANCES[cfg.dataName] or {}
    local parts = PartViews(cfg)
    if parts then
        for j, view in ipairs(parts) do
            AddRow(Norm(view.name), view, e, ENTRANCES[view.name] or {}, i + j / 10)
        end
    else
        AddRow(cfg.key, cfg, e, e, i)
    end
end
-- by lowest level, then by highest level (narrower range first), raids last
table.sort(TRAVEL, function(a, b)
    if a.lo ~= b.lo then return a.lo < b.lo end
    if a.hi ~= b.hi then return a.hi < b.hi end
    if a.raid ~= b.raid then return not a.raid end
    return a.order < b.order
end)

-- The entrance recorded with /bnav entrance: the part's own, else (from
-- before the parts were split) the whole dungeon's.
local function SavedEntrance(entry)
    local saved = DB().entrances
    if not saved then return nil end
    return saved[entry.key] or (entry.cfg and saved[entry.cfg.key]) or nil
end

-- True when an entrance is known (built in or recorded); no map lookups.
local function HasEntrance(entry)
    local saved = SavedEntrance(entry)
    if saved and saved.mapID then return true end
    return entry.zone ~= nil and entry.x ~= nil
end

-- Where the entrance is: uiMapID of its zone map, x and y as 0..1 fractions of
-- that map, and a label in words. Your own recording wins over the built-in
-- spot. mapID is nil (with the label still set) when the client has no map of
-- that name, and everything is nil when no entrance is known at all.
local function EntranceOf(entry)
    local saved = SavedEntrance(entry)
    if saved and saved.mapID then
        return saved.mapID, saved.x / 100, saved.y / 100,
            string.format("%s %.1f, %.1f (recorded)", saved.zone or "map " .. saved.mapID, saved.x, saved.y)
    end
    if not (entry.zone and entry.x and entry.y) then return nil end
    local label = string.format("%s %.1f, %.1f", entry.zone, entry.x, entry.y)
    if entry.via then label = entry.via .. " via " .. label end
    return ResolveMapIDByName(entry.zone), entry.x / 100, entry.y / 100, label
end

-- Record the entrance of a dungeon at a spot on a uiMap (x, y as percent).
local function SaveEntrance(entry, mapID, x, y, zoneName)
    local db = DB()
    db.entrances = db.entrances or {}
    db.entrances[entry.key] = { mapID = mapID, x = x, y = y, zone = zoneName }
end

-- shared with the other BossNav files
ns.EntranceOf = EntranceOf
ns.SavedEntrance = SavedEntrance
ns.HasEntrance = HasEntrance
ns.SaveEntrance = SaveEntrance
ns.TRAVEL = TRAVEL
