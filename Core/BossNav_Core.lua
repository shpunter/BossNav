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
--   Core/BossNav_Core.lua             constants, helpers, shared state
--   Core/BossNav_Data.lua             dungeon list, boss pins, trails, portrait IDs
--   Quests/BossNav_QuestData.lua      quests per dungeon: giver, place, faction, level
--   Window/BossNav_Progress.lua       saved per-dungeon progress
--   Loot/BossNav_Gold.lua             gold earned in the current dungeon
--   Loot/BossNav_XP.lua               experience earned in the current dungeon
--   Core/BossNav_MapAPI.lua           guarded access to the client's map API
--   Bosses/BossNav_Entrances.lua      dungeon entrances in the open world, travel list by level
--   Travel/BossNav_Routes.lua         zone-to-zone routing: which exit or flight master leads toward a dungeon
--   Window/BossNav_Window.lua         map window frames, sidebar rows, pins
--   Bosses/BossNav_Parts.lua          dungeons the game lists in parts (Scarlet wings, Dire Maul, Spire, Stratholme): a row per part
--   Window/BossNav_TabLook.lua       the look of a tab: rounded top corners, gold outline on the open one
--   Window/BossNav_Tabs.lua          section tabs (Dungeons / Quests / Loot / Profs), the Dungeons column headers (Dungeons / Bosses / Items) and switching
--   Bosses/BossNav_MapArt.lua         map art renderers
--   Core/BossNav_Waypoints.lua        boss selection, floors, waypoints
--   Window/BossNav_Render.lua         drawing the whole map window
--   Window/BossNav_HUD.lua            top-of-screen direction HUD
--   Window/BossNav_Minimap.lua        minimap boss icons
--   Bosses/BossNav_Live.lua           periodic live update
--   Travel/BossNav_Travel.lua         travel mode: arrow, distance and minimap pin to a dungeon entrance
--   Travel/BossNav_RouteToggle.lua    the "By foot" / "Flying" boxes under the map and /bnav route
--   Travel/BossNav_TravelPanel.lua    the dungeon list column, and outside a dungeon the zone map with the entrance pin
--   Bosses/BossNav_BossPreview.lua    outside a dungeon, Bosses column focused: the picked dungeon's map and boss pins
--   Travel/BossNav_WorldMap.lua       dungeon entrance marks on the game's world map
--   Bosses/BossNav_Kills.lua          kill tracking and extra bosses
--   Bosses/BossNav_Marker.lua         skull raid mark on a boss as soon as it is seen
--   Bosses/BossNav_Portraits.lua      boss portraits learned in game for bosses without a known one
--   Core/BossNav_Roster.lua           group roster: names, classes, class colours, group chat channel
--   Core/BossNav_Role.lua             is the player tanking: group role, spec, stance or Righteous Fury
--   Threat/BossNav_ThreatPlates.lua   threat label next to each enemy nameplate health bar
--   Plates/BossNav_ClassColor.lua     paints a health bar in the class colour of the player it shows
--   Plates/BossNav_ClassPlates.lua    that colour on nameplates and party / raid blocks
--   Plates/BossNav_ClassFrames.lua    that colour on target, target of target and party frames
--   Plates/BossNav_RangeFade.lua      fades party and raid frames of members farther than ~30 yards
--   Plates/BossNav_DrinkIcon.lua      cup icon next to a group member who is drinking
--   Plates/BossNav_PartyDistance.lua  how far each group member is, on party and raid frames
--   Threat/BossNav_AggroAlert.lua     tank alert: a mob that was attacking you turns to someone else
--   Threat/BossNav_Threat.lua         threat window: every mob in combat, who it attacks, your threat on it
--   Loot/BossNav_Loot.lua             loot roll tracker (Need / Greed / Pass, rolls, winner)
--   Loot/BossNav_LootPanel.lua        the Loot tab: item list and roll panel in the window
--   Loot/BossNav_LootPopup.lua        popup that shows Need / Greed / Pass live while an item is rolled
--   Loot/BossNav_EarnedPost.lua       P button on the HUD, keybind and /bnav earned: post gold, XP and run time to party chat
--   Profs/BossNav_Profs.lua           profession tracker (mines, herbs, skins, fish, crafts per member)
--   Profs/BossNav_ProfsChat.lua       teammates' gathers and crafts read from loot / craft chat lines
--   Profs/BossNav_ProfsPanel.lua      the Profs tab: member list and profession table in the window
--   Quests/BossNav_QuestLog.lua       finds a quest in your log by ID or by name; learns the game's real ID
--   Quests/BossNav_QuestStatus.lua    whether you already did a quest or have it in your log
--   Quests/BossNav_QuestText.lua      built-in quest text and rewards for the quests in BossNav_QuestData.lua
--   Quests/BossNav_QuestLogInfo.lua   quest text and rewards read from your quest log when you have the quest
--   Quests/BossNav_QuestInfo.lua      the selected quest drawn like the game's quest window
--   Quests/BossNav_QuestsPanel.lua    the Quests tab: a dungeon's quests and where to take them
--   Quests/BossNav_QuestMapPins.lua   quest givers of the selected dungeon on the game's world map
--   Items/BossNav_ItemData.lua        loot per dungeon boss, copied from Forever Atlas and foreverchanges.pro (static)
--   Items/BossNav_ItemClasses.lua     which class can use an item; the saved class ticks
--   Items/BossNav_ItemSlots.lua       slot, weapon type and hand of an item; the saved ticks
--   Items/BossNav_ItemFilter.lua      which items the Items column lists (the dungeon and boss you picked)
--   Items/BossNav_ItemInfo.lua        item name, icon, quality and level from the game client
--   Items/BossNav_ItemCompare.lua     the item card's comparison with the item you wear in that slot
--   Items/BossNav_FilterPanel.lua     the item filter boxes under the map (class, slot, weapon, hand) and their commands
--   Items/BossNav_ItemsPanel.lua      the Items column: item list with icons and an item card over the map
--   Core/BossNav_Zone.lua             zone changes
--   Core/BossNav_Commands.lua         keybind actions, slash commands, help
--   Core/BossNav_Events.lua           event wiring
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
BINDING_NAME_BOSSNAV_TOGGLE_TAB = "Switch Section: Dungeons / Quests / Loot / Profs"
BINDING_NAME_BOSSNAV_NEXT_VIEW = "Switch Column: Dungeons / Bosses / Items"
BINDING_NAME_BOSSNAV_SWITCH_NAV = "Switch Navigation: Quest Giver / Dungeon"
BINDING_NAME_BOSSNAV_QUEST_DOWN = "Scroll Down (quest text / item list)"
BINDING_NAME_BOSSNAV_QUEST_UP = "Scroll Up (quest text / item list)"
BINDING_NAME_BOSSNAV_TOGGLE_THREAT = "Toggle Threat Window"
BINDING_NAME_BOSSNAV_RESET_KILLS = "Reset Kill Marks (after a dungeon reset)"
BINDING_NAME_BOSSNAV_POST_EARNED = "Post Gold and XP Earned to Party Chat"

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

-- Runs fn(...) like pcall, but prints an error the first time it happens,
-- so a broken feature says why instead of quietly stopping. Each distinct
-- error is printed once per session. For BossNav's own functions; a game
-- call that may fail on purpose (secret values) keeps a plain pcall.
local reportedErrors = {}
local function ReportError(ok, ...)
    if not ok then
        local err = tostring((...))
        if not reportedErrors[err] then
            reportedErrors[err] = true
            Print("|cffff4444error:|r " .. err .. "  (please report this line)")
        end
    end
    return ok, ...
end
local function SafeCall(fn, ...)
    return ReportError(pcall(fn, ...))
end

--------------------------------------------------------------------------
-- /bnav subcommands: each feature file registers its own words and help
-- lines here; BossNav_Commands.lua reads them when you type /bnav.
--------------------------------------------------------------------------
local commands = {}       -- [word] = function(rest, word)
local commandHelp = {}    -- help lines in the order the files registered them

-- AddCommand("loot", fn, { "  /bnav loot ...  what it does" })
-- AddCommand({ "prof", "profs" }, fn, help): several words for one command.
local function AddCommand(words, fn, help)
    if type(words) == "string" then words = { words } end
    for _, word in ipairs(words) do commands[word] = fn end
    for _, line in ipairs(help or {}) do commandHelp[#commandHelp + 1] = line end
end

local function FindCommand(word)
    return commands[word]
end

local function CommandHelp()
    return commandHelp
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

-- Settings that are on unless you turned them off.
local ON_BY_DEFAULT = { "hud", "minimap", "skull", "worldmap", "flightmap", "questmap", "threat" }

-- The saved settings, with defaults filled in. The defaults are filled once
-- per table: the game swaps in the saved table after this file loads, so a
-- new table gets them again.
local preparedDB
local function DB()
    if BossNavDB == preparedDB then return BossNavDB end
    BossNavDB.routes = BossNavDB.routes or {}
    BossNavDB.progress = BossNavDB.progress or {}
    for _, key in ipairs(ON_BY_DEFAULT) do
        if BossNavDB[key] == nil then BossNavDB[key] = true end
    end
    preparedDB = BossNavDB
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
    xp = 0,             -- experience earned inside the current dungeon
    floorOverride = nil,
    autoFloor = nil,    -- floor derived from the player's current uiMap
    shownFloor = nil,   -- floor currently drawn
    mapID = nil,        -- player's uiMapID
    inInstance = false,
    testMode = false,
    travelIdx = nil,    -- outside instances: index into the travel list of the dungeon to walk to
    tab = "travel",     -- sidebar tab: "travel", "boss", "quest", "loot" or "prof" ("travel" shows "boss" inside)
    lootIdx = 1,        -- selected item on the Loot tab, 1 = newest
    profIdx = 1,        -- selected member on the Profs tab
    questIdx = 1,       -- selected quest on the Quests tab
    questAll = false,   -- Quests tab: true shows both factions' quests
}

-- shared with the other BossNav files
ns.AddCommand = AddCommand
ns.CANVAS_H = CANVAS_H
ns.CommandHelp = CommandHelp
ns.FindCommand = FindCommand
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
ns.SafeCall = SafeCall
ns.WAYPOINT_RADIUS = WAYPOINT_RADIUS
ns.atan2 = atan2
ns.state = state
