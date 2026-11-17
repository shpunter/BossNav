--------------------------------------------------------------------------
-- BossNav - keyboard-friendly dungeon boss navigator for WoW Forever (16001)
--
--  * Map window with the real dungeon map (native C_Map art when the client
--    exposes it, otherwise the classic tiled map textures, otherwise the map
--    map images bundled in BossNav/Images) and a skull pin for every boss.
--  * Your live position and facing drawn on the map while inside an instance,
--    plus a small top-of-screen HUD arrow pointing at the selected boss.
--  * Killed bosses tracked from ENCOUNTER_END / BOSS_KILL and your target.
--    Every unit read is guarded against "secret values". The combat log is
--    deliberately not read: this client blocks that for addons.
--  * Kill marks and visited waypoints are saved per dungeon, so dying (which
--    drops you outside as a spirit), relogging or crashing keeps your
--    progress. Marks expire after an hour away, clear with /bnav reset, are
--    wiped when you leave the party (the next instance is fresh), and are
--    dropped automatically when a marked boss is seen alive again.
--  * Your own numbered waypoints per boss, recorded in-game with /bnav mark.
--  * A skull raid mark placed on a boss as soon as you target it, its
--    nameplate appears, or the encounter starts (/bnav skull toggles it).
--  * A small portrait next to each boss (creature display IDs from the Forever
--    Atlas data, rendered by the client); a skull where none is known.
--  * A loot roll tracker: who chose Need / Greed / Pass on each group-loot
--    item of blue quality or better, what they rolled and who won, read from
--    the game's own loot chat lines. /bnav loot shows the last five items.
--  * A profession tracker: how many times each group member mined, gathered
--    herbs, skinned, fished, disenchanted or crafted, counted from the spell
--    casts the game reports for group units. /bnav prof opens the Profs tab.
--  * Travel mode outside every dungeon: the window shows your zone map and a
--    dungeon selector (the Forever Atlas dungeon list by level), and the HUD
--    arrow, distance and minimap pin lead to the chosen dungeon's entrance.
--    Outside, the client does report your position, so this is fully live.
--    /bnav go picks a dungeon; /bnav entrance records a portal at your feet.
--    The dungeon list is coloured against your level: red above you, grey
--    once outgrown, green while in range.
--  * A Quests tab: every quest of a dungeon for your faction, with the quest
--    giver, the zone and map coordinates where to take it, the turn-in NPC
--    and what to do first. /bnav quest opens it. The givers of that dungeon's
--    quests are also marked on the game's world map (/bnav quest map toggles).
--  * Entrance marks on the game's world map: hover one to see its name
--    (green/red by level), level range and where it is; click one to pick
--    it. /bnav worldmap toggles them.
--  * Flight masters on the game's world map: known ones solid, the one you
--    stand at yellow, undiscovered ones faded. /bnav flights toggles them.
--  * Zone-to-zone routing: when the dungeon is in another zone the arrow
--    leads to the exit of your zone toward it (road crossings, boats and
--    zeppelins from a built-in zone link table). Two boxes under the map,
--    "By foot" and "Flying" (one always ticked; /bnav route foot|fly),
--    choose whether a flight master is used when you have learned a flight
--    path at both ends. Each zone crossing re-plans the route.
--
-- Boss pin coordinates follow the Forever Atlas (AtlasLootClassic) dungeon
-- map data shipped with this client. Bosses listed without coordinates are
-- shown in the boss list but have no pin yet; /bnav markboss records one.
-- A boss the game reports killed that is missing from the list is added to
-- it automatically (saved per dungeon); /bnav addboss and delboss edit that.
--
-- Files (loaded in the order listed in BossNav.toc; each file shares with
-- the others only through the addon namespace table `ns`):
--   BossNav_Core.lua       constants, helpers, shared state
--   BossNav_Data.lua       dungeon list, boss pins, trails, portrait IDs
--   BossNav_QuestData.lua  quests per dungeon: giver, place, faction, level
--   BossNav_Progress.lua   saved per-dungeon progress
--   BossNav_Gold.lua       gold earned in the current dungeon
--   BossNav_MapAPI.lua     guarded access to the client's map API
--   BossNav_Entrances.lua  dungeon entrances in the open world, travel list by level
--   BossNav_Routes.lua     zone-to-zone routing: which exit or flight master leads toward a dungeon
--   BossNav_Window.lua     map window frames, sidebar rows, pins
--   BossNav_Tabs.lua       Bosses / Loot / Profs tab buttons and tab switching
--   BossNav_MapArt.lua     map art renderers
--   BossNav_Waypoints.lua  boss selection, floors, waypoints
--   BossNav_Render.lua     drawing the whole map window
--   BossNav_HUD.lua        top-of-screen direction HUD
--   BossNav_Minimap.lua    minimap boss icons
--   BossNav_Live.lua       periodic live update
--   BossNav_Travel.lua     travel mode: arrow, distance and minimap pin to a dungeon entrance
--   BossNav_RouteToggle.lua the "By foot" / "Flying" boxes under the map and /bnav route
--   BossNav_TravelPanel.lua the window outside a dungeon: zone map, entrance pin, dungeon selector
--   BossNav_WorldMap.lua   dungeon entrance marks on the game's world map
--   BossNav_Kills.lua      kill tracking and extra bosses
--   BossNav_Marker.lua     skull raid mark on a boss as soon as it is seen
--   BossNav_Roster.lua     group roster: names, classes, class colours, group chat channel
--   BossNav_Loot.lua       loot roll tracker (Need / Greed / Pass, rolls, winner)
--   BossNav_LootPanel.lua  the Loot tab: item list and roll panel in the window
--   BossNav_Profs.lua      profession tracker (mines, herbs, skins, fish, crafts per member)
--   BossNav_ProfsPanel.lua the Profs tab: member list and profession table in the window
--   BossNav_QuestStatus.lua whether you already did a quest or have it in your log
--   BossNav_QuestsPanel.lua the Quests tab: a dungeon's quests and where to take them
--   BossNav_QuestMapPins.lua quest givers of the selected dungeon on the game's world map
--   BossNav_Zone.lua       zone changes
--   BossNav_Commands.lua   keybind actions, slash commands, help
--   BossNav_Events.lua     event wiring
--------------------------------------------------------------------------

-- Constants, helpers and shared state.
local ADDON, ns = ...

BINDING_HEADER_BOSSNAV = "BossNav"
BINDING_NAME_BOSSNAV_TOGGLE_MAP = "Toggle Dungeon Map"
BINDING_NAME_BOSSNAV_CYCLE_BOSS = "Select Next Boss"
BINDING_NAME_BOSSNAV_PREV_STEP = "Select Previous Boss"
BINDING_NAME_BOSSNAV_NEXT_STEP = "Next Map Floor"
BINDING_NAME_BOSSNAV_TOGGLE_HUD = "Toggle Direction HUD"
BINDING_NAME_BOSSNAV_MARK_WAYPOINT = "Mark Waypoint Here"
BINDING_NAME_BOSSNAV_MARK_BOSS = "Mark Nearby Boss (skull)"
BINDING_NAME_BOSSNAV_TOGGLE_TAB = "Switch Bosses / Quests / Loot / Profs Tab"
BINDING_NAME_BOSSNAV_SWITCH_NAV = "Switch Navigation: Quest Giver / Dungeon"

BossNavDB = BossNavDB or {}

local CANVAS_W, CANVAS_H = 540, 360
local SIDEBAR_W = 325
local LEGACY_ASPECT = 1.5
local WAYPOINT_RADIUS = 0.025
local FOREVER_IMG = "Interface\\AddOns\\BossNav\\Images\\"
local SKULL_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[BossNav]|r " .. tostring(msg))
end

local function Norm(name)
    if not name then return nil end
    local s = tostring(name):lower()
    s = s:gsub("^the%s+", "")
    s = s:gsub("[^%w]", "")
    return s
end

local function IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

local function BaseName(n)
    return n:match("^(.-)%s*%(") or n
end

local function NamesMatch(cfgName, unitName)
    if not cfgName or not unitName then return false end
    if cfgName == unitName then return true end
    if BaseName(cfgName) == unitName then return true end
    local inner = cfgName:match("%((.-)%)")
    if inner and inner == unitName then return true end
    return false
end

local function DB()
    BossNavDB.routes = BossNavDB.routes or {}
    BossNavDB.progress = BossNavDB.progress or {}
    if BossNavDB.hud == nil then BossNavDB.hud = true end
    if BossNavDB.minimap == nil then BossNavDB.minimap = true end
    if BossNavDB.skull == nil then BossNavDB.skull = true end
    if BossNavDB.worldmap == nil then BossNavDB.worldmap = true end
    if BossNavDB.flightmap == nil then BossNavDB.flightmap = true end
    if BossNavDB.questmap == nil then BossNavDB.questmap = true end
    return BossNavDB
end

local function FloorName(cfg, floor)
    if not cfg or not cfg.floorNames then return "Floor " .. tostring(floor) end
    for i, f in ipairs(cfg.floors) do
        if f == floor then return cfg.floorNames[i] or ("Floor " .. tostring(floor)) end
    end
    return "Floor " .. tostring(floor)
end

--------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------
local state = {
    cfg = nil,          -- current dungeon config
    zoneName = nil,
    bossIdx = 1,
    killed = {},        -- [bossName] = true
    visited = {},       -- [waypointKey] = true
    gold = 0,           -- copper earned inside the current dungeon
    floorOverride = nil,
    autoFloor = nil,    -- floor derived from the player's current uiMap
    shownFloor = nil,   -- floor currently drawn
    mapID = nil,        -- player's uiMapID
    inInstance = false,
    testMode = false,
    travelIdx = nil,    -- outside instances: index into the travel list of the dungeon to walk to
    tab = "boss",       -- sidebar tab: "boss", "quest", "loot" or "prof"
    lootIdx = 1,        -- selected item on the Loot tab, 1 = newest
    profIdx = 1,        -- selected member on the Profs tab
    questIdx = 1,       -- selected quest on the Quests tab
    questAll = false,   -- Quests tab: true shows both factions' quests
}

-- shared with the other BossNav files
ns.CANVAS_H = CANVAS_H
ns.CANVAS_W = CANVAS_W
ns.DB = DB
ns.FOREVER_IMG = FOREVER_IMG
ns.FloorName = FloorName
ns.IsSecret = IsSecret
ns.LEGACY_ASPECT = LEGACY_ASPECT
ns.NamesMatch = NamesMatch
ns.Norm = Norm
ns.Print = Print
ns.SIDEBAR_W = SIDEBAR_W
ns.SKULL_TEX = SKULL_TEX
ns.WAYPOINT_RADIUS = WAYPOINT_RADIUS
ns.atan2 = atan2
ns.state = state
