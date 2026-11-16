-- Dungeon entrances in the open world, and the travel list (dungeons by level).
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local DUNGEONS               = ns.DUNGEONS
local ResolveMapIDByName     = ns.ResolveMapIDByName

--------------------------------------------------------------------------
-- Entrance of every dungeon: the zone map it sits on, plus percent across and
-- percent down that zone map. Level ranges follow the Forever Atlas data
-- (AtlasLootClassic_DungeonsAndRaids). The coordinates are the classic
-- entrance spots and are unverified on this client: standing at a portal and
-- typing /bnav entrance records the real one, which then wins over this list.
-- raid = true sorts the entry after the dungeons of the same level.
-- A dungeon without zone/x/y shows as "no entrance" until one is recorded.
--------------------------------------------------------------------------
local ENTRANCES = {
    ["Ragefire Chasm"]            = { zone = "Orgrimmar",            x = 52.8, y = 49.0, levels = {13, 18} },
    ["Wailing Caverns"]           = { zone = "The Barrens",          x = 46.1, y = 36.4, levels = {15, 25} },
    ["The Deadmines"]             = { zone = "Westfall",             x = 42.6, y = 71.6, levels = {18, 23} },
    ["Shadowfang Keep"]           = { zone = "Silverpine Forest",    x = 44.8, y = 67.8, levels = {22, 30} },
    ["The Stockade"]              = { zone = "Stormwind City",       x = 50.6, y = 66.4, levels = {22, 30} },
    ["Blackfathom Deeps"]         = { zone = "Ashenvale",            x = 14.4, y = 14.5, levels = {24, 32} },
    ["Gnomeregan"]                = { zone = "Dun Morogh",           x = 24.4, y = 39.7, levels = {29, 38} },
    ["Razorfen Kraul"]            = { zone = "The Barrens",          x = 42.2, y = 89.8, levels = {30, 40} },
    ["Scarlet Monastery"]         = { zone = "Tirisfal Glades",      x = 84.9, y = 30.9, levels = {28, 45} },
    ["Razorfen Downs"]            = { zone = "The Barrens",          x = 48.9, y = 94.4, levels = {40, 50} },
    ["Uldaman"]                   = { zone = "Badlands",             x = 42.4, y = 18.6, levels = {42, 52} },
    ["Zul'Farrak"]                = { zone = "Tanaris",              x = 39.0, y = 20.2, levels = {44, 54} },
    ["Maraudon"]                  = { zone = "Desolace",             x = 29.1, y = 62.5, levels = {46, 55} },
    ["The Temple of Atal'Hakkar"] = { zone = "Swamp of Sorrows",     x = 69.7, y = 53.4, levels = {50, 60} },
    ["Blackrock Depths"]          = { zone = "Searing Gorge",        x = 35.4, y = 84.4, levels = {52, 60}, via = "Blackrock Mountain" },
    ["Blackrock Spire"]           = { zone = "Searing Gorge",        x = 35.4, y = 84.4, levels = {55, 60}, via = "Blackrock Mountain" },
    ["Scholomance"]               = { zone = "Western Plaguelands",  x = 69.3, y = 73.2, levels = {58, 60} },
    ["Stratholme"]                = { zone = "Eastern Plaguelands",  x = 30.8, y = 14.4, levels = {58, 60} },
    ["Dire Maul"]                 = { zone = "Feralas",              x = 59.3, y = 44.5, levels = {58, 60} },
    -- Raids
    ["Molten Core"]               = { zone = "Searing Gorge",        x = 35.4, y = 84.4, levels = {60, 60}, via = "Blackrock Mountain", raid = true },
    ["Onyxia's Lair"]             = { zone = "Dustwallow Marsh",     x = 52.6, y = 76.5, levels = {60, 60}, raid = true },
    ["Zul'Gurub"]                 = { zone = "Stranglethorn Vale",   x = 53.6, y = 17.5, levels = {60, 60}, raid = true },
    ["Blackwing Lair"]            = { zone = "Searing Gorge",        x = 35.4, y = 84.4, levels = {60, 60}, via = "Blackrock Mountain", raid = true },
    ["Ruins of Ahn'Qiraj"]        = { zone = "Silithus",             x = 29.0, y = 93.0, levels = {60, 60}, raid = true },
    ["Ahn'Qiraj"]                 = { zone = "Silithus",             x = 29.0, y = 93.0, levels = {60, 60}, raid = true },
    -- WoW Forever dungeons: no public entrance coordinates yet; /bnav entrance records them.
    ["The Hall of Thanes"]        = { levels = {13, 18} },
    ["Ruins of Lordaeron"]        = { levels = {15, 20} },
    ["Excavation Site: Wetlands"] = { levels = {24, 29} },
    ["City of Dalaran"]           = { levels = {28, 33} },
    ["Half-Pint Tavern"]          = { },
}

--------------------------------------------------------------------------
-- Travel list: every dungeon BossNav knows, sorted by level, raids last.
-- Entry: { key, name, cfg, zone, x, y, via, raid, levels = "18-23" }
--------------------------------------------------------------------------
local TRAVEL = {}
for i, cfg in ipairs(DUNGEONS) do
    local e = ENTRANCES[cfg.name] or {}
    local lo, hi = e.levels and e.levels[1] or nil, e.levels and e.levels[2] or nil
    local levels = "?"
    if lo and hi then levels = (lo == hi) and tostring(lo) or (lo .. "-" .. hi) end
    TRAVEL[#TRAVEL + 1] = {
        key = cfg.key, name = cfg.name, cfg = cfg,
        zone = e.zone, x = e.x, y = e.y, via = e.via, raid = e.raid or false,
        lo = lo or 99, minLevel = lo, levels = levels, order = i,
    }
end
table.sort(TRAVEL, function(a, b)
    if a.lo ~= b.lo then return a.lo < b.lo end
    if a.raid ~= b.raid then return not a.raid end
    return a.order < b.order
end)

local function SavedEntrance(entry)
    local saved = DB().entrances
    return saved and saved[entry.key] or nil
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
ns.HasEntrance = HasEntrance
ns.SaveEntrance = SaveEntrance
ns.TRAVEL = TRAVEL
