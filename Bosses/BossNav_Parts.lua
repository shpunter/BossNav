-- Dungeons the game's group finder lists in parts: the Scarlet Monastery
-- wings, Lower / Upper Blackrock Spire, Dire Maul East / West / North and the
-- two Stratholme gates. Inside, each is one map to the game, so BossNav keeps
-- one dungeon (cfg) for it. Outside, every part is its own row in the dungeon
-- list, shown through a "part view": the part's name, floors and bosses;
-- everything else (key, map art, saved kills, quests) is the whole dungeon's.
--
-- A part is the floors it covers; a boss belongs to the part of its floor.
local ADDON, ns = ...
-- from the files loaded before this one
local ZONE_INDEX             = ns.ZONE_INDEX
local Norm                   = ns.Norm

-- the game's names (GroupFinderActivity ShortName), floors as in BossNav_Data.lua
local PARTS = {
    ["Scarlet Monastery"] = {
        { title = "Scarlet Graveyard", floors = {1} },
        { title = "Scarlet Library",   floors = {2} },
        { title = "Scarlet Armory",    floors = {3} },
        { title = "Scarlet Cathedral", floors = {4} },
    },
    ["Blackrock Spire"] = {
        { title = "Lower Blackrock Spire", floors = {1, 3, 6} },
        { title = "Upper Blackrock Spire", floors = {2, 7} },
    },
    ["Stratholme"] = {
        { title = "Stratholme (Main Gate)",    floors = {1} },
        { title = "Stratholme (Service Gate)", floors = {2} },
    },
    ["Dire Maul"] = {
        { title = "Dire Maul (East)",  floors = {5, 6} },
        { title = "Dire Maul (West)",  floors = {2, 3, 4} },
        { title = "Dire Maul (North)", floors = {1} },
    },
}

local function PartView(cfg, part)
    local inPart = {}
    for _, f in ipairs(part.floors) do inPart[f] = true end
    local view = { name = part.title, floors = part.floors, parent = cfg, part = part }
    if cfg.floorNames then
        view.floorNames = {}
        for i, f in ipairs(cfg.floors) do
            if inPart[f] then view.floorNames[#view.floorNames + 1] = cfg.floorNames[i] end
        end
    end
    return setmetatable(view, { __index = function(_, k)
        if k == "bosses" then
            -- read fresh each time: the whole list changes after load
            -- (saved extra bosses added, the other faction's bosses dropped)
            local list = {}
            for _, b in ipairs(cfg.bosses) do
                if inPart[b[4] or cfg.floors[1]] then list[#list + 1] = b end
            end
            return list
        end
        return cfg[k]
    end })
end

-- The part views of a dungeon, or nil when the game lists it whole.
local views = {}
local function PartViews(cfg)
    local parts = PARTS[cfg.dataName]
    if not parts then return nil end
    if not views[cfg] then
        views[cfg] = {}
        for i, part in ipairs(parts) do views[cfg][i] = PartView(cfg, part) end
    end
    return views[cfg]
end

-- the part names also find the dungeon (/bnav go, zone names)
for name in pairs(PARTS) do
    local cfg = ZONE_INDEX[Norm(name)]
    if cfg then
        for _, part in ipairs(PARTS[name]) do
            if not ZONE_INDEX[Norm(part.title)] then ZONE_INDEX[Norm(part.title)] = cfg end
        end
    end
end

-- shared with the other BossNav files
ns.PartViews = PartViews
