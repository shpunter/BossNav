-- Keybind actions, slash commands, help.
local ADDON, ns = ...
-- from the files loaded before this one
local AddBoss                = ns.AddBoss
local ClearProgress          = ns.ClearProgress
local ClearTravelTarget      = ns.ClearTravelTarget
local CurrentFloor           = ns.CurrentFloor
local DB                     = ns.DB
local DUNGEONS               = ns.DUNGEONS
local EditableWaypoints      = ns.EditableWaypoints
local FloorName              = ns.FloorName
local HideMinimapPins        = ns.HideMinimapPins
local LootCommand            = ns.LootCommand
local MapName                = ns.MapName
local MapWorldSize           = ns.MapWorldSize
local NextTab                = ns.NextTab
local Norm                   = ns.Norm
local PlayerFacing           = ns.PlayerFacing
local PlayerMapID            = ns.PlayerMapID
local PlayerPos              = ns.PlayerPos
local PostLootSelected       = ns.PostLootSelected
local Print                  = ns.Print
local ProfCommand            = ns.ProfCommand
local RefreshIfShown         = ns.RefreshIfShown
local RemoveBoss             = ns.RemoveBoss
local RouteCommand           = ns.RouteCommand
local SaveEntrance           = ns.SaveEntrance
local SelectedBoss           = ns.SelectedBoss
local SelectedDungeon        = ns.SelectedDungeon
local SetTab                 = ns.SetTab
local SkullCommand           = ns.SkullCommand
local PortraitCommand        = ns.PortraitCommand
local TRAVEL                 = ns.TRAVEL
local ThreatCommand          = ns.ThreatCommand
local TouchProgress          = ns.TouchProgress
local TravelMode             = ns.TravelMode
local UpdateHUDVisibility    = ns.UpdateHUDVisibility
local UpdateZone             = ns.UpdateZone
local ZONE_INDEX             = ns.ZONE_INDEX
local mapFrame               = ns.mapFrame
local state                  = ns.state

--------------------------------------------------------------------------
-- Public actions (keybinds + slash)
--------------------------------------------------------------------------
function BossNav_ToggleMap()
    if mapFrame:IsShown() then
        mapFrame:Hide()
    else
        mapFrame:Show()
        BossNav_RefreshMap()
    end
end

function BossNav_SelectBoss(idx)
    -- outside: the Bosses tab lists the picked dungeon's bosses
    if TravelMode() then ns.SelectPreviewBoss(idx) return end
    local cfg = state.cfg
    if not cfg or not cfg.bosses[idx] then return end
    state.bossIdx = idx
    state.floorOverride = nil
    TouchProgress()
    local b = cfg.bosses[idx]
    Print(string.format("Target: |cffffd100%s|r%s", b[1],
        state.killed[b[1]] and " |cff888888[DEAD]|r" or ""))
    RefreshIfShown()
    pcall(BossNav_UpdateLive, true)
end

-- The next / previous keys walk the dungeon selector while you are outside,
-- or that dungeon's boss list on the Bosses tab. On the Quests tab they walk
-- the quest list instead.
function BossNav_CycleBoss()
    if state.tab == "quest" and mapFrame:IsShown() then ns.CycleQuest(1) return end
    if TravelMode() then
        if state.tab == "boss" and mapFrame:IsShown() and ns.CyclePreviewBoss(1) then return end
        BossNav_CycleDungeon(1)
        return
    end
    local cfg = state.cfg
    if not cfg then Print("No boss data for this zone.") return end
    BossNav_SelectBoss((state.bossIdx % #cfg.bosses) + 1)
end
BossNav_NextStep = BossNav_CycleBoss

function BossNav_PrevBoss()
    if state.tab == "quest" and mapFrame:IsShown() then ns.CycleQuest(-1) return end
    if TravelMode() then
        if state.tab == "boss" and mapFrame:IsShown() and ns.CyclePreviewBoss(-1) then return end
        BossNav_CycleDungeon(-1)
        return
    end
    local cfg = state.cfg
    if not cfg then Print("No boss data for this zone.") return end
    BossNav_SelectBoss(((state.bossIdx - 2) % #cfg.bosses) + 1)
end
BossNav_PrevStep = BossNav_PrevBoss

-- /bnav go [n | name | off]: pick the dungeon to walk to (outside only).
local function GoCommand(rest)
    if state.testMode then
        state.testMode = false
        UpdateZone()
    end
    if not TravelMode() then Print("You are inside a dungeon; the selector works outside.") return end
    local arg = (rest or ""):lower()
    if arg == "off" or arg == "none" or arg == "clear" then
        ClearTravelTarget()
        return
    end
    if arg == "" then BossNav_CycleDungeon(1) return end
    if arg == "up" or arg == "down" then
        -- scroll the selector a page without changing the pick
        if not mapFrame:IsShown() then mapFrame:Show() end
        ns.TravelScrollBy((arg == "up" and -1 or 1) * (ns.MAX_ROWS - 1))
        return
    end
    -- /bnav go show [n]: the selected (or n-th) dungeon's entrance on the world map
    local showArg = arg:match("^show%s*(%d*)$")
    if showArg then
        local idx = tonumber(showArg) or state.travelIdx
        if not idx then Print("Pick a dungeon first (/bnav go).") return end
        ns.ShowDungeonOnWorldMap(idx)
        return
    end
    local n = tonumber(arg)
    if n then BossNav_SelectDungeon(n) return end
    for i, e in ipairs(TRAVEL) do
        if e.name:lower():find(arg, 1, true) then BossNav_SelectDungeon(i) return end
    end
    Print("No dungeon matching '" .. rest .. "'.")
end

-- /bnav entrance [X Y]: record the chosen dungeon's entrance at your feet, or
-- at X% across, Y% down the zone map you are on.
local function MarkEntranceHere(args)
    local entry = SelectedDungeon()
    if not entry then Print("Pick a dungeon first (/bnav go).") return end
    local mapID = PlayerMapID()
    if not mapID then Print("The client reports no map for your position here.") return end
    local px, py
    local tx, ty = (args or ""):match("^(%d+%.?%d*)%s+(%d+%.?%d*)")
    if tx and ty then
        px, py = tonumber(tx) / 100, tonumber(ty) / 100
        if px < 0 or px > 1 or py < 0 or py > 1 then Print("Coordinates are percent values 0-100.") return end
    else
        px, py = PlayerPos(mapID)
        if not px then Print("Your position is hidden here. Use |cffffd100/bnav entrance 42 71|r (percent across, percent down).") return end
    end
    local zoneName = MapName(mapID) or GetRealZoneText()
    SaveEntrance(entry, mapID, px * 100, py * 100, zoneName)
    Print(string.format("Entrance of %s recorded: %s %.1f, %.1f.", entry.name, tostring(zoneName), px * 100, py * 100))
    RefreshIfShown()
    if ns.RefreshWorldMapPins then pcall(ns.RefreshWorldMapPins) end
    pcall(BossNav_UpdateLive, true)
end

function BossNav_NextFloor()
    local cfg = state.cfg
    if not cfg or #cfg.floors < 2 then Print("This map has a single floor.") return end
    local cur = state.shownFloor or CurrentFloor(cfg)
    local pos = 1
    for i, f in ipairs(cfg.floors) do if f == cur then pos = i end end
    state.floorOverride = cfg.floors[(pos % #cfg.floors) + 1]
    Print("Map floor: " .. FloorName(cfg, state.floorOverride))
    if not mapFrame:IsShown() then mapFrame:Show() end
    BossNav_RefreshMap()
end

-- Switch Section key (Dungeons / Loot / Profs) and Switch View key
-- (Travel / Bosses / Quests), see BossNav_Tabs.lua
function BossNav_ToggleTab()
    NextTab()
end

function BossNav_NextView()
    ns.NextView()
end

function BossNav_ToggleHUD()
    DB().hud = not DB().hud
    Print("Direction HUD " .. (DB().hud and "on" or "off") .. ".")
    UpdateHUDVisibility()
end

function BossNav_MarkWaypoint(note)
    local cfg, boss = state.cfg, SelectedBoss()
    if not cfg or not boss then Print("Select a boss first (/bnav boss).") return end
    local mapID = PlayerMapID()
    local px, py = PlayerPos(mapID)
    -- Typed coordinates: "/bnav mark 45 60 note" places a dot at 45% across, 60% down.
    if type(note) == "string" then
        local tx, ty, restNote = note:match("^(%d+%.?%d*)%s+(%d+%.?%d*)%s*(.-)$")
        if tx and ty then
            px, py = tonumber(tx) / 100, tonumber(ty) / 100
            note = restNote
            if px < 0 or px > 1 or py < 0 or py > 1 then Print("Coordinates are percent values 0-100.") return end
        end
    end
    if not px then
        Print("This client hides your position in dungeons. Place a dot by map percent instead, e.g. |cffffd100/bnav mark 45 60 bridge|r (45% across, 60% down).")
        return
    end
    local list = EditableWaypoints(cfg, boss)
    local hasNote = type(note) == "string" and note ~= ""
    list[#list + 1] = { x = px * 100, y = py * 100, mapID = mapID,
        floor = state.autoFloor or state.shownFloor or cfg.floors[1], note = hasNote and note or nil }
    Print(string.format("Waypoint %d saved for %s%s.", #list, boss[1], hasNote and (": " .. note) or ""))
    RefreshIfShown()
end

local function MarkBossHere(args)
    local cfg, boss = state.cfg, SelectedBoss()
    if not cfg or not boss then Print("Select a boss first (/bnav boss).") return end
    local tx, ty = (args or ""):match("^(%d+%.?%d*)%s+(%d+%.?%d*)")
    if tx and ty then
        boss[2], boss[3] = tonumber(tx), tonumber(ty)
        boss[4] = state.shownFloor or cfg.floors[1]
        local db = DB()
        db.bossPins = db.bossPins or {}
        db.bossPins[cfg.key] = db.bossPins[cfg.key] or {}
        db.bossPins[cfg.key][boss[1]] = { x = boss[2], y = boss[3], floor = boss[4] }
        Print(string.format("Pin for %s placed at %.0f%% across, %.0f%% down.", boss[1], boss[2], boss[3]))
        RefreshIfShown()
        return
    end
    local px, py = PlayerPos(PlayerMapID())
    if not px then
        Print("This client hides your position in dungeons. Use |cffffd100/bnav markboss 45 60|r (percent across, percent down) to place the pin by hand.")
        return
    end
    boss[2], boss[3] = px * 100, py * 100
    boss[4] = state.autoFloor or state.shownFloor or cfg.floors[1]
    local db = DB()
    db.bossPins = db.bossPins or {}
    db.bossPins[cfg.key] = db.bossPins[cfg.key] or {}
    db.bossPins[cfg.key][boss[1]] = { x = boss[2], y = boss[3], floor = boss[4] }
    Print(string.format("Pin for %s set to your position (%.1f, %.1f).", boss[1], boss[2], boss[3]))
    RefreshIfShown()
end

-- Apply boss pins the player recorded with /bnav markboss (saved variables)
local function ApplySavedBossPins()
    local saved = DB().bossPins
    if not saved then return end
    for _, cfg in ipairs(DUNGEONS) do
        local pins = saved[cfg.key]
        if pins then
            for _, b in ipairs(cfg.bosses) do
                local p = pins[b[1]]
                if p then b[2], b[3], b[4] = p.x, p.y, p.floor or b[4] end
            end
        end
    end
end

local function Diagnostics()
    local zone, sub = GetRealZoneText(), GetSubZoneText()
    local inInst, instType = IsInInstance()
    local mapID = PlayerMapID()
    local px, py = PlayerPos(mapID)
    local facing = PlayerFacing()
    Print(string.format("Zone: %s / %s  instance=%s(%s)", tostring(zone), tostring(sub), tostring(inInst), tostring(instType)))
    -- Raw client answers, unfiltered, so a failure can be pinned down
    local okB, rawBest = pcall(function() return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") end)
    local okP, rawPos = pcall(function()
        if not (mapID and C_Map and C_Map.GetPlayerMapPosition) then return "no api/map" end
        local v = C_Map.GetPlayerMapPosition(mapID, "player")
        if not v then return "nil" end
        if v.GetXY then local x, y = v:GetXY() return string.format("%.4f, %.4f", x or -1, y or -1) end
        return tostring(v.x) .. ", " .. tostring(v.y)
    end)
    local okU, rawUnit = pcall(function()
        if not UnitPosition then return "no api" end
        local y, x, z, inst = UnitPosition("player")
        return string.format("%s, %s, %s inst=%s", tostring(x), tostring(y), tostring(z), tostring(inst))
    end)
    Print(string.format("raw: GetBestMapForUnit=%s  GetPlayerMapPosition=%s  UnitPosition=%s",
        okB and tostring(rawBest) or ("err " .. tostring(rawBest)),
        okP and tostring(rawPos) or ("err " .. tostring(rawPos)),
        okU and tostring(rawUnit) or ("err " .. tostring(rawUnit))))
    Print(string.format("uiMapID: %s (%s)  pos: %s  facing: %s",
        tostring(mapID), tostring(MapName(mapID)),
        px and string.format("%.1f, %.1f", px * 100, py * 100) or "n/a",
        facing and string.format("%.2f", facing) or "n/a"))
    local layers = 0
    if mapID and C_Map and C_Map.GetMapArtLayers then
        local ok, l = pcall(C_Map.GetMapArtLayers, mapID)
        if ok and type(l) == "table" then layers = #l end
    end
    local ww, wh = MapWorldSize(mapID)
    Print(string.format("Native art layers: %d  world size: %s  dungeon data: %s  floor: %s",
        layers, ww and string.format("%.0fx%.0f yd", ww, wh) or "n/a",
        state.cfg and state.cfg.name or "none", tostring(state.shownFloor or state.autoFloor or "-")))
end

local function ShowHelp()
    Print("Commands:")
    Print("  /bnav                 toggle the dungeon map (Esc closes it); outside a dungeon it shows the dungeon selector")
    Print("  /bnav go [n|name|off] outside: pick the dungeon to walk to (HUD arrow, yards, minimap pin to its entrance)")
    Print("  /bnav go up | down    scroll the dungeon list a page (the mouse wheel over the list scrolls it too)")
    Print("  /bnav go show [n]     pick the selected (or n-th) dungeon and show its entrance zoomed in on the world map")
    Print("  /bnav route foot|fly  outside: walk zone to zone, or use flight masters where a path is known at both ends (the boxes under the map; no word flips it)")
    Print("  /bnav worldmap        toggle the dungeon entrance marks on the game's world map")
    Print("  /bnav flights         toggle the flight masters on the game's world map (faded = not discovered yet)")
    Print("  /bnav entrance [X Y]  outside: record the chosen dungeon's entrance at your feet (or X% across, Y% down the zone map)")
    Print("  /bnav boss [n|name]   select next boss, or boss number / name (outside: same as /bnav go)")
    Print("  /bnav prev            select previous boss")
    Print("  /bnav floor [n]       switch map floor (multi-floor dungeons)")
    Print("  /bnav kill            toggle [DEAD] on the selected boss")
    Print("  /bnav reset           clear all [DEAD] marks")
    Print("  /bnav mark X Y [note] add a numbered dot at X% across, Y% down the map")
    Print("  /bnav undo | clear    remove the last / all dots of this boss")
    Print("  /bnav restore         bring back the built-in trail of this boss")
    Print("  /bnav markboss X Y    place the selected boss pin at X% across, Y% down")
    Print("  /bnav addboss Name [X Y]  add a boss missing from the list (kills add them automatically)")
    Print("  /bnav delboss [Name]  remove an added boss")
    Print("  /bnav hud             toggle the top-screen boss bar")
    Print("  /bnav skull           toggle the auto skull mark on bosses")
    Print("  /bnav skull now       put a skull on a boss in view, no target needed (also a keybind)")
    Print("  /bnav skull test      explain why your target was or was not marked")
    Print("  /bnav portrait        learn the portrait of the boss you target (also happens by itself)")
    Print("  /bnav portrait list   which boss portraits were learned in game; 'clear' forgets them")
    Print("  /bnav threat          toggle the threat window: every mob in combat, who it attacks, your threat % (also a keybind)")
    Print("  /bnav threat test     show the threat window with made-up mobs for 30 seconds; drag it with the mouse to move it")
    Print("  /bnav threat reset    put the threat window back at its starting spot")
    Print("  /bnav threat plates   turn the threat label next to each enemy health bar on or off")
    Print("  /bnav threat tank     tank mode: auto (found from role, stance or Righteous Fury) -> always on -> off")
    Print("  /bnav threat alert    tank mode: warning and sound when a mob turns from you to someone else (on/off)")
    Print("  /bnav threat debug   print the raw threat values the game gives for each mob in view")
    Print("  /bnav minimap         toggle minimap icons (needs a position; this client hides it)")
    Print("  /bnav loot [n|all]    last 5 loot rolls (blue and better): who chose Need/Greed/Pass, their roll, the winner")
    Print("  /bnav quest [n]       Quests tab: the quests of this dungeon (outside: the one picked with /bnav go), who gives them and where")
    Print("  /bnav quest next|prev pick the next / previous quest (the Select Next / Previous Boss keys do it too on that tab)")
    Print("  /bnav quest all       show every faction's and class's quests, or only yours again")
    Print("  /bnav quest list      print the quest list and giver places to your chat")
    Print("  /bnav quest down|up|top  scroll the quest text and rewards (also keybinds)")
    Print("  /bnav quest show [n]  navigate to the selected (or n-th) quest's giver and show it zoomed in on the world map")
    Print("  /bnav nav             switch the arrow between the quest giver and the dungeon (also a keybind)")
    Print("  /bnav nav quest|dungeon  follow that one; /bnav nav off forgets the quest giver target")
    Print("  /bnav quest map       toggle the quest givers of the selected dungeon on the game's world map")
    Print("  /bnav tab              next section: Dungeons / Loot / Profs (the Switch Section key)")
    Print("  /bnav tab view         next view of Dungeons: Travel / Bosses / Quests (the Switch View key)")
    Print("  /bnav tab [travel|boss|quest|loot|prof|n] open that tab; a number n picks item n on the Loot or Profs tab")
    Print("  /bnav prof [n]        Profs tab: how often each member mined, skinned, gathered, fished or crafted; n lists member n's spells")
    Print("  /bnav prof post       post the profession counts to party/raid chat (/bnav prof list prints them to you)")
    Print("  /bnav prof clear      forget the profession counts (also done when you leave the group)")
    Print("  /bnav prof debug      print every group spell cast the game reports, to see what is counted")
    Print("  /bnav loot post       post the selected item's rolls to party/raid chat (types ticked on the Loot tab)")
    Print("  /bnav loot auto       toggle the roll summary printed after each item is won")
    Print("  /bnav loot clear      forget the loot roll history")
    Print("  /bnav loot who        show how the addon sees your group (names and classes)")
    Print("  /bnav pos             print map diagnostics")
    Print("  /bnav test            preview Wailing Caverns anywhere")
    Print("Keybinds: Esc > Key Bindings > BossNav")
end

SLASH_BOSSNAV1 = "/bnav"
SlashCmdList["BOSSNAV"] = function(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    rest = rest or ""
    local cfg = state.cfg

    if cmd == "" then
        BossNav_ToggleMap()
    elseif cmd == "go" or cmd == "travel" or cmd == "dungeon" then
        GoCommand(rest)
    elseif cmd == "nav" then
        -- /bnav nav [quest|dungeon|off]: which target the arrow follows
        local arg = rest:lower()
        if arg == "off" or arg == "clear" then ns.ClearQuestTarget()
        elseif arg == "quest" or arg == "q" then ns.SwitchNav("quest")
        elseif arg == "dungeon" or arg == "d" then ns.SwitchNav("dungeon")
        else ns.SwitchNav() end
    elseif cmd == "entrance" then
        MarkEntranceHere(rest)
    elseif cmd == "route" then
        RouteCommand(rest)
    elseif cmd == "walk" or cmd == "foot" then
        RouteCommand("foot")
    elseif cmd == "fly" then
        RouteCommand("fly")
    elseif (cmd == "boss" or cmd == "next") and TravelMode() then
        GoCommand(rest)
    elseif cmd == "boss" or cmd == "next" then
        if rest ~= "" and cfg then
            local n = tonumber(rest)
            if n then
                BossNav_SelectBoss(n)
            else
                local needle = rest:lower()
                for i, b in ipairs(cfg.bosses) do
                    if b[1]:lower():find(needle, 1, true) then BossNav_SelectBoss(i) return end
                end
                Print("No boss matching '" .. rest .. "'.")
            end
        else
            BossNav_CycleBoss()
        end
    elseif cmd == "prev" then
        BossNav_PrevBoss()
    elseif cmd == "floor" then
        local n = tonumber(rest)
        if n and cfg then
            state.floorOverride = n
            if not mapFrame:IsShown() then mapFrame:Show() end
            BossNav_RefreshMap()
        else
            BossNav_NextFloor()
        end
    elseif cmd == "kill" then
        local boss = SelectedBoss()
        if boss then
            state.killed[boss[1]] = (not state.killed[boss[1]]) or nil
            Print(boss[1] .. (state.killed[boss[1]] and " marked [DEAD]." or " marked alive."))
            TouchProgress()
            RefreshIfShown()
            pcall(BossNav_UpdateLive, true)
        end
    elseif cmd == "reset" then
        ClearProgress(state.cfg)
        Print("Kill marks cleared.")
        RefreshIfShown()
    elseif cmd == "mark" then
        BossNav_MarkWaypoint(rest)
    elseif cmd == "markboss" then
        MarkBossHere(rest)
    elseif cmd == "addboss" then
        local cfg = state.cfg
        if not cfg then Print("Enter a known dungeon first.") return end
        local name, tx, ty = (rest or ""):match("^(.-)%s+(%d+%.?%d*)%s+(%d+%.?%d*)%s*$")
        name = name or rest
        name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then Print("Usage: /bnav addboss Boss Name [X Y]") return end
        local x, y = tonumber(tx), tonumber(ty)
        local floor = (x and y) and (state.shownFloor or cfg.floors[1]) or nil
        if not AddBoss(cfg, name, x, y, floor) then Print(name .. " is already in the list.") end
    elseif cmd == "delboss" then
        local cfg = state.cfg
        if not cfg then Print("Enter a known dungeon first.") return end
        local name = (rest ~= "" and rest) or (SelectedBoss() and SelectedBoss()[1])
        if not name then Print("Usage: /bnav delboss [Boss Name]") return end
        if RemoveBoss(cfg, name) then
            Print(name .. " removed.")
        else
            Print(name .. " is a built-in boss or not in the list; only added bosses can be removed.")
        end
    elseif cmd == "undo" or cmd == "clear" or cmd == "restore" then
        local boss = SelectedBoss()
        if not (cfg and boss) then
            Print("Select a boss first (/bnav boss).")
        elseif cmd == "restore" then
            if DB().routes[cfg.key] then DB().routes[cfg.key][boss[1]] = nil end
            Print("Built-in trail restored for " .. boss[1] .. ".")
            RefreshIfShown()
        else
            local wps = EditableWaypoints(cfg, boss)
            if #wps == 0 then
                Print("No waypoints for this boss.")
            elseif cmd == "undo" then
                table.remove(wps)
                Print("Last waypoint removed for " .. boss[1] .. ".")
                RefreshIfShown()
            else
                for i = #wps, 1, -1 do wps[i] = nil end
                Print("Waypoints cleared for " .. boss[1] .. ". /bnav restore brings the built-in trail back.")
                RefreshIfShown()
            end
        end
    elseif cmd == "hud" then
        BossNav_ToggleHUD()
    elseif cmd == "skull" then
        SkullCommand(rest)
    elseif cmd == "portrait" or cmd == "portraits" or cmd == "icon" or cmd == "icons" then
        PortraitCommand(rest)
    elseif cmd == "minimap" then
        DB().minimap = not DB().minimap
        Print("Minimap boss icons " .. (DB().minimap and "on" or "off") .. ".")
        if not DB().minimap then HideMinimapPins() end
    elseif cmd == "worldmap" then
        DB().worldmap = not DB().worldmap
        Print("Dungeon entrance marks on the world map " .. (DB().worldmap and "on" or "off") .. ".")
        if ns.RefreshWorldMapPins then pcall(ns.RefreshWorldMapPins) end
    elseif cmd == "flights" or cmd == "flight" or cmd == "taxi" then
        DB().flightmap = not DB().flightmap
        Print("Flight masters on the world map " .. (DB().flightmap and "on" or "off") .. ".")
        if ns.RefreshWorldMapPins then pcall(ns.RefreshWorldMapPins) end
    elseif cmd == "loot" then
        if rest:lower() == "post" then
            PostLootSelected()
        else
            LootCommand(rest)
        end
    elseif cmd == "tab" then
        local n = tonumber(rest)
        local which = rest:lower()
        if n then
            if state.tab == "prof" then
                state.profIdx = n
                SetTab("prof")
            elseif state.tab == "quest" then
                ns.SelectQuest(n)
                SetTab("quest")
            else
                state.lootIdx = n
                SetTab("loot")
            end
        elseif which == "loot" then
            SetTab("loot")
        elseif which == "prof" or which == "profs" then
            SetTab("prof")
        elseif which == "quest" or which == "quests" then
            SetTab("quest")
        elseif which == "travel" or which == "dungeon" or which == "dungeons" then
            SetTab("travel")
        elseif which == "boss" or which == "bosses" then
            SetTab("boss")
        elseif which == "view" then
            BossNav_NextView()
        else
            BossNav_ToggleTab()
        end
    elseif cmd == "prof" or cmd == "profs" then
        ProfCommand(rest)
    elseif cmd == "quest" or cmd == "quests" or cmd == "q" then
        if not mapFrame:IsShown() then mapFrame:Show() end
        ns.QuestCommand(rest)
    elseif cmd == "threat" or cmd == "aggro" then
        ThreatCommand(rest)
    elseif cmd == "pos" then
        Diagnostics()
    elseif cmd == "test" then
        state.testMode = true
        state.cfg = ZONE_INDEX[Norm("Wailing Caverns")]
        state.zoneName = "Wailing Caverns (preview)"
        state.bossIdx = 1
        state.killed = {}
        state.floorOverride = nil
        state.autoFloor = nil
        UpdateHUDVisibility()
        mapFrame:Show()
        BossNav_RefreshMap()
    else
        ShowHelp()
    end
end

-- shared with the other BossNav files
ns.ApplySavedBossPins = ApplySavedBossPins
