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
local MapName                = ns.MapName
local MapWorldSize           = ns.MapWorldSize
local NextTab                = ns.NextTab
local Norm                   = ns.Norm
local PlayerFacing           = ns.PlayerFacing
local PlayerMapID            = ns.PlayerMapID
local PlayerPos              = ns.PlayerPos
local Print                  = ns.Print
local RefreshIfShown         = ns.RefreshIfShown
local RemoveBoss             = ns.RemoveBoss
local SaveEntrance           = ns.SaveEntrance
local SelectedBoss           = ns.SelectedBoss
local SelectedDungeon        = ns.SelectedDungeon
local SetTab                 = ns.SetTab
local TRAVEL                 = ns.TRAVEL
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
    -- outside: the Bosses column lists the picked dungeon's bosses
    if TravelMode() then ns.SelectPreviewBoss(idx) return end
    local cfg = state.cfg
    if not cfg or not cfg.bosses[idx] then return end
    state.bossIdx = idx
    if ns.PickItemBoss then ns.PickItemBoss(cfg, cfg.bosses[idx][1]) end
    state.floorOverride = nil
    TouchProgress()
    local b = cfg.bosses[idx]
    Print(string.format("Target: |cffffd100%s|r%s", b[1],
        state.killed[b[1]] and " |cff888888[DEAD]|r" or ""))
    RefreshIfShown()
    pcall(BossNav_UpdateLive, true)
end

-- Inside a dungeon: the next / previous boss, or the Trash row after the last
-- one (it only filters the Items column; the arrow keeps its boss).
local function StepInsideBoss(step)
    local cfg = state.cfg
    if not cfg then Print("No boss data for this zone.") return end
    local nxt = ns.StepBossColumn(cfg, state.bossIdx, step)
    if nxt == "trash" then
        ns.PickTrash(cfg)
        RefreshIfShown()
    elseif nxt then
        BossNav_SelectBoss(nxt)
    end
end

-- The next / previous keys walk the dungeon selector while you are outside,
-- or that dungeon's boss list while the Bosses column has the focus. On the Quests tab they walk
-- the quest list instead, on the Items tab the item list.
function BossNav_CycleBoss()
    if state.tab == "quest" and mapFrame:IsShown() then ns.CycleQuest(1) return end
    if state.tab == "item" and mapFrame:IsShown() then ns.CycleItem(1) return end
    if TravelMode() then
        if state.tab == "boss" and mapFrame:IsShown() and ns.CyclePreviewBoss(1) then return end
        BossNav_CycleDungeon(1)
        return
    end
    StepInsideBoss(1)
end
BossNav_NextStep = BossNav_CycleBoss

function BossNav_PrevBoss()
    if state.tab == "quest" and mapFrame:IsShown() then ns.CycleQuest(-1) return end
    if state.tab == "item" and mapFrame:IsShown() then ns.CycleItem(-1) return end
    if TravelMode() then
        if state.tab == "boss" and mapFrame:IsShown() and ns.CyclePreviewBoss(-1) then return end
        BossNav_CycleDungeon(-1)
        return
    end
    StepInsideBoss(-1)
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

-- Switch Section key (Dungeons / Quests / Loot / Profs) and Switch View key
-- (focus the Dungeons / Bosses / Items column), see BossNav_Tabs.lua
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

--------------------------------------------------------------------------
-- Core /bnav commands: map, bosses, floors, waypoints. Feature commands
-- (loot, quests, items, threat, plates...) are registered by their own files
-- with ns.AddCommand.
--------------------------------------------------------------------------
local AddCommand = ns.AddCommand

-- printed before the feature files' help lines
local CORE_HELP = {
    "  /bnav                 toggle the dungeon map (Esc closes it); outside a dungeon it shows the dungeon selector",
    "  /bnav go [n|name|off] outside: pick the dungeon to walk to (HUD arrow, yards, minimap pin to its entrance)",
    "  /bnav go up | down    scroll the dungeon list a page (the mouse wheel over the list scrolls it too)",
    "  /bnav go show [n]     pick the selected (or n-th) dungeon and show its entrance zoomed in on the world map",
    "  /bnav entrance [X Y]  outside: record the chosen dungeon's entrance at your feet (or X% across, Y% down the zone map)",
    "  /bnav boss [n|name]   select next boss, or boss number / name (outside: same as /bnav go)",
    "  /bnav prev            select previous boss",
    "  /bnav floor [n]       switch map floor (multi-floor dungeons)",
    "  /bnav kill            toggle [DEAD] on the selected boss",
    "  /bnav reset           clear all [DEAD] marks",
    "  /bnav mark X Y [note] add a numbered dot at X% across, Y% down the map",
    "  /bnav undo | clear    remove the last / all dots of this boss",
    "  /bnav restore         bring back the built-in trail of this boss",
    "  /bnav markboss X Y    place the selected boss pin at X% across, Y% down",
    "  /bnav addboss Name [X Y]  add a boss missing from the list (kills add them automatically)",
    "  /bnav delboss [Name]  remove an added boss",
    "  /bnav hud             toggle the top-screen boss bar",
    "  /bnav tab              next section: Dungeons / Quests / Loot / Profs (the Switch Section key)",
    "  /bnav tab view         Dungeons: focus the next column, Dungeons / Bosses / Items (the Switch Column key);",
    "                         the Select Next / Previous Boss keys walk the focused column",
    "  /bnav tab [travel|boss|item|quest|loot|prof|n] open that column or section; a number n picks item n on the Loot or Profs tab",
    "  /bnav pos             print map diagnostics",
    "  /bnav test            preview Wailing Caverns anywhere",
}

local function ShowHelp()
    Print("Commands:")
    for _, line in ipairs(CORE_HELP) do Print(line) end
    for _, line in ipairs(ns.CommandHelp()) do Print(line) end
    Print("Keybinds: Esc > Key Bindings > BossNav")
end

AddCommand({ "go", "travel", "dungeon" }, GoCommand)
AddCommand("entrance", MarkEntranceHere)

-- /bnav boss [n|name]: outside it picks a dungeon like /bnav go
AddCommand({ "boss", "next" }, function(rest)
    if TravelMode() then GoCommand(rest) return end
    local cfg = state.cfg
    if rest == "" or not cfg then BossNav_CycleBoss() return end
    local n = tonumber(rest)
    if n then BossNav_SelectBoss(n) return end
    local needle = rest:lower()
    for i, b in ipairs(cfg.bosses) do
        if b[1]:lower():find(needle, 1, true) then BossNav_SelectBoss(i) return end
    end
    Print("No boss matching '" .. rest .. "'.")
end)

AddCommand("prev", function() BossNav_PrevBoss() end)

AddCommand("floor", function(rest)
    local n = tonumber(rest)
    if n and state.cfg then
        state.floorOverride = n
        if not mapFrame:IsShown() then mapFrame:Show() end
        BossNav_RefreshMap()
    else
        BossNav_NextFloor()
    end
end)

AddCommand("kill", function()
    local boss = SelectedBoss()
    if not boss then return end
    state.killed[boss[1]] = (not state.killed[boss[1]]) or nil
    Print(boss[1] .. (state.killed[boss[1]] and " marked [DEAD]." or " marked alive."))
    TouchProgress()
    RefreshIfShown()
    pcall(BossNav_UpdateLive, true)
end)

AddCommand("reset", function()
    ClearProgress(state.cfg)
    Print("Kill marks cleared.")
    RefreshIfShown()
end)

AddCommand("mark", function(rest) BossNav_MarkWaypoint(rest) end)
AddCommand("markboss", MarkBossHere)

AddCommand("addboss", function(rest)
    local cfg = state.cfg
    if not cfg then Print("Enter a known dungeon first.") return end
    local name, tx, ty = rest:match("^(.-)%s+(%d+%.?%d*)%s+(%d+%.?%d*)%s*$")
    name = name or rest
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then Print("Usage: /bnav addboss Boss Name [X Y]") return end
    local x, y = tonumber(tx), tonumber(ty)
    local floor = (x and y) and (state.shownFloor or cfg.floors[1]) or nil
    if not AddBoss(cfg, name, x, y, floor) then Print(name .. " is already in the list.") end
end)

AddCommand("delboss", function(rest)
    local cfg = state.cfg
    if not cfg then Print("Enter a known dungeon first.") return end
    local name = (rest ~= "" and rest) or (SelectedBoss() and SelectedBoss()[1])
    if not name then Print("Usage: /bnav delboss [Boss Name]") return end
    if RemoveBoss(cfg, name) then
        Print(name .. " removed.")
    else
        Print(name .. " is a built-in boss or not in the list; only added bosses can be removed.")
    end
end)

-- /bnav undo | clear | restore: the selected boss's waypoints
AddCommand({ "undo", "clear", "restore" }, function(_, cmd)
    local cfg, boss = state.cfg, SelectedBoss()
    if not (cfg and boss) then
        Print("Select a boss first (/bnav boss).")
        return
    end
    if cmd == "restore" then
        if DB().routes[cfg.key] then DB().routes[cfg.key][boss[1]] = nil end
        Print("Built-in trail restored for " .. boss[1] .. ".")
        RefreshIfShown()
        return
    end
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
end)

AddCommand("hud", function() BossNav_ToggleHUD() end)

-- /bnav tab [name | n | view]
local TAB_WORDS = {
    loot = "loot", prof = "prof", profs = "prof", quest = "quest", quests = "quest",
    travel = "travel", dungeon = "travel", dungeons = "travel",
    boss = "boss", bosses = "boss", item = "item", items = "item",
}
AddCommand("tab", function(rest)
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
    elseif TAB_WORDS[which] then
        SetTab(TAB_WORDS[which])
    elseif which == "view" then
        BossNav_NextView()
    else
        BossNav_ToggleTab()
    end
end)

AddCommand("pos", Diagnostics)

AddCommand("test", function()
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
end)

SLASH_BOSSNAV1 = "/bnav"
SlashCmdList["BOSSNAV"] = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    rest = rest or ""
    if cmd == "" then BossNav_ToggleMap() return end
    local run = ns.FindCommand(cmd)
    if run then run(rest, cmd) else ShowHelp() end
end

-- shared with the other BossNav files
ns.ApplySavedBossPins = ApplySavedBossPins
