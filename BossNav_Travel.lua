-- Travel mode: outside any dungeon, point at the entrance of a chosen one.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local DirectionWord          = ns.DirectionWord
local EntranceOf             = ns.EntranceOf
local GetMinimapPin          = ns.GetMinimapPin
local HideMinimapPins        = ns.HideMinimapPins
local HideMinimapPinsFrom    = ns.HideMinimapPinsFrom
local MapWorldSize           = ns.MapWorldSize
local Place                  = ns.Place
local PlaceMinimapPin        = ns.PlaceMinimapPin
local PlayerFacing           = ns.PlayerFacing
local PlayerMapID            = ns.PlayerMapID
local PlayerPos              = ns.PlayerPos
local Print                  = ns.Print
local RefreshIfShown         = ns.RefreshIfShown
local RouteMode              = ns.RouteMode
local TRAVEL                 = ns.TRAVEL
local UpdateHUDVisibility    = ns.UpdateHUDVisibility
local atan2                  = ns.atan2
local hud                    = ns.hud
local mapFrame               = ns.mapFrame
local navText                = ns.navText
local playerPin              = ns.playerPin
local state                  = ns.state

--------------------------------------------------------------------------
-- Selection
--------------------------------------------------------------------------
-- Outside every instance and not previewing a dungeon: the selector is shown.
local function TravelMode()
    return not state.inInstance and not state.testMode
end

local function SelectedDungeon()
    return state.travelIdx and TRAVEL[state.travelIdx] or nil
end

-- What the arrow leads to. Two targets can be kept at once: the picked
-- dungeon's entrance and a quest giver picked with "Show on the map" (until
-- you reach it). state.navFocus says which one the arrow follows; when only
-- one is set, that one. A quest giver target looks like a dungeon entry
-- (zone, x, y) so the same routing works.
local function NavTarget()
    local dungeon, quest = SelectedDungeon(), state.questTarget
    if state.navFocus == "dungeon" then return dungeon or quest end
    return quest or dungeon
end

-- What is "selected" in the lists: a quest (Quests tab) or a dungeon (Travel
-- tab), never both. state.selKind is set by picking either one.
local function QuestSelected()
    return state.selKind == "quest"
end

-- The target the arrow is NOT following right now, or nil.
local function OtherNavTarget()
    local dungeon, quest = SelectedDungeon(), state.questTarget
    if not (dungeon and quest) then return nil end
    return (NavTarget() == quest) and dungeon or quest
end

-- True while the live arrow should run outside: a dungeon or giver is picked.
local function TravelActive()
    return TravelMode() and NavTarget() ~= nil
end

local function IndexOfKey(key)
    for i, e in ipairs(TRAVEL) do
        if e.key == key then return i end
    end
    return nil
end

-- Your character level, or nil when the client will not say.
local function PlayerLevel()
    local ok, lvl = pcall(UnitLevel, "player")
    if ok and type(lvl) == "number" and lvl > 0 then return lvl end
    return nil
end

-- Colour of a dungeon against your level as r, g, b: red above you, grey
-- when you have outgrown it, green when you are inside its range, nil when
-- unknown. Used for the ring around the world map pins.
local function LevelRGB(entry, myLevel)
    if not (myLevel and entry.minLevel and entry.maxLevel) then return nil end
    if entry.minLevel > myLevel then return 1.0, 0.25, 0.25 end
    if entry.maxLevel < myLevel then return 0.53, 0.53, 0.53 end
    return 0.25, 1.0, 0.25
end

-- The same colour as a text colour code ("|cffrrggbb"), nil when unknown.
local function LevelColor(entry, myLevel)
    local r, g, b = LevelRGB(entry, myLevel)
    if not r then return nil end
    return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

-- How many levels below you a quest still gives experience. The game's own
-- answer when it has one, else the classic rule (5 up to level 9, then one
-- more every 10 levels).
local function QuestGreenRange(myLevel)
    for _, fn in ipairs({ "GetQuestGreenRange", "UnitQuestTrivialLevelRange" }) do
        if type(_G[fn]) == "function" then
            local ok, n = pcall(_G[fn], "player")
            if ok and type(n) == "number" and n > 0 then return n end
        end
    end
    return 5 + math.floor(myLevel / 10)
end

-- Colour of a quest against your level, the same three as the dungeons:
-- red when you cannot take it yet, grey when it gives no experience any
-- more, green otherwise. A quest row without qlevel guesses it as level + 5
-- (the usual gap in the data).
local function QuestLevelRGB(q, myLevel)
    if not (myLevel and q.level) then return nil end
    if q.level > myLevel then return 1.0, 0.25, 0.25 end
    local qlevel = q.qlevel or (q.level + 5)
    if myLevel - qlevel > QuestGreenRange(myLevel) then return 0.53, 0.53, 0.53 end
    return 0.25, 1.0, 0.25
end

local function QuestLevelColor(q, myLevel)
    local r, g, b = QuestLevelRGB(q, myLevel)
    if not r then return nil end
    return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

-- The selected dungeon changed: redraw the window and the world map marks.
local function TargetChanged()
    UpdateHUDVisibility()
    RefreshIfShown()
    if ns.RefreshWorldMapPins then pcall(ns.RefreshWorldMapPins) end
    pcall(BossNav_UpdateLive, true)
end

-- Bring back the dungeon picked in an earlier session (saved variables).
local function RestoreTravelTarget()
    local saved = DB().travel
    state.travelIdx = saved and saved.key and IndexOfKey(saved.key) or nil
end

function BossNav_SelectDungeon(idx)
    local e = TRAVEL[idx]
    if not e then return end
    state.travelIdx = idx
    state.navFocus = "dungeon"
    state.selKind = "dungeon"
    DB().travel = { key = e.key }
    local _, _, _, where = EntranceOf(e)
    Print(string.format("Travel target: |cffffd100%s|r  %s", e.name,
        where and ("(" .. where .. ")") or "(entrance unknown: stand at it and type /bnav entrance)"))
    TargetChanged()
end

function BossNav_CycleDungeon(step)
    local n = #TRAVEL
    if n == 0 then return end
    local idx
    if not state.travelIdx then
        idx = (step < 0) and n or 1
    else
        idx = ((state.travelIdx + step - 1) % n) + 1
    end
    BossNav_SelectDungeon(idx)
end

-- Lead the arrow to a quest's giver (q from BossNav_QuestData.lua).
-- brief: one chat line only (picking quests one after another in the list).
local function SetQuestTarget(q, brief)
    local key = "quest:" .. tostring(q.id or q.name)
    -- already leading there: nothing new to say
    if state.questTarget and state.questTarget.key == key and state.navFocus == "quest" then
        state.selKind = "quest"
        TargetChanged()
        return
    end
    state.questTarget = {
        key = key,
        name = q.giver or q.name, levels = q.name,
        zone = q.zone, x = q.x, y = q.y, isQuest = true,
    }
    state.navFocus = "quest"
    state.selKind = "quest"
    state.questInside = nil
    Print(string.format("Navigating to |cffffd100%s|r  (%s %.1f, %.1f) for %s",
        state.questTarget.name, q.zone, q.x, q.y, q.name))
    if brief then TargetChanged() return end
    if SelectedDungeon() then
        Print("The dungeon target is kept: /bnav nav (or the Switch Navigation key) goes back to it.")
    end
    if state.inInstance then Print("The arrow starts once you are out of the dungeon.") end
    TargetChanged()
end

-- A quest taken inside a dungeon: the arrow leads to that dungeon's
-- entrance, which then wears the quest icon. entry: the dungeon, or nil.
local function SetQuestInside(entry)
    state.questInside = entry and entry.key or nil
    state.questTarget = nil
    state.navFocus = "dungeon"
    state.selKind = "quest"
    TargetChanged()
end

local function ClearQuestTarget(quiet)
    -- the dungeon is the selection again (picking a quest sets it back after)
    state.selKind = "dungeon"
    if state.questInside and not state.questTarget then
        state.questInside = nil
        TargetChanged()
        return
    end
    state.questInside = nil
    if not state.questTarget then
        if not quiet then Print("No quest giver target.") end
        return
    end
    state.questTarget = nil
    state.navFocus = "dungeon"
    if not quiet then Print("Quest giver target cleared.") end
    TargetChanged()
end

-- Switch the arrow between the quest giver and the dungeon entrance.
-- which: "quest", "dungeon", or nil to flip.
local function SwitchNav(which)
    local dungeon, quest = SelectedDungeon(), state.questTarget
    if not (dungeon or quest) then
        Print("Nothing to navigate to: pick a dungeon (/bnav go) or a quest's map button.")
        return
    end
    if not which then which = (NavTarget() == quest) and "dungeon" or "quest" end
    if which == "quest" and not quest then
        Print("No quest giver target: use a quest's map button or /bnav quest show.")
        return
    elseif which == "dungeon" and not dungeon then
        Print("No dungeon target: pick one with /bnav go.")
        return
    end
    state.navFocus = which
    state.selKind = which
    local t = NavTarget()
    Print("Navigating to " .. (t.isQuest and "quest giver " or "dungeon ") .. "|cffffd100" .. t.name .. "|r.")
    TargetChanged()
end

function BossNav_SwitchNav()
    SwitchNav()
end

local function ClearTravelTarget(quiet)
    state.travelIdx = nil
    DB().travel = nil
    HideMinimapPins()
    if not quiet then Print("Travel target cleared.") end
    TargetChanged()
end

--------------------------------------------------------------------------
-- Geometry. World coordinates: x grows north, y grows west (the client's
-- convention). Facing is radians counter-clockwise from north.
--------------------------------------------------------------------------
-- Continent ID and world position of a point given as 0..1 fractions of a uiMap.
local function WorldPos(mapID, fx, fy)
    if not (mapID and fx and fy and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(fx, fy))
    if ok and cont and pos and type(pos.x) == "number" and type(pos.y) == "number" then
        return cont, pos.x, pos.y
    end
    return nil
end

-- A world point as 0..1 fractions of a given uiMap; nil when it lies off that map.
local function MapPosFromWorld(cont, wx, wy, mapID)
    if not (cont and wx and mapID and C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, cont, CreateVector2D(wx, wy), mapID)
    if not ok or not pos or type(pos.x) ~= "number" or type(pos.y) ~= "number" then return nil end
    if pos.x < 0 or pos.x > 1 or pos.y < 0 or pos.y > 1 then return nil end
    return pos.x, pos.y
end

-- The leg to walk now (BossNav_Routes.lua): the entrance when it is in your
-- zone, else the exit toward it or a flight master. Re-planned every few
-- seconds and whenever your zone, map or foot / flying choice changes.
local legCache = { key = nil, time = 0, leg = nil }
local function CurrentLeg(entry, mapID, px, py)
    local key = entry.key .. "|" .. tostring(mapID) .. "|" .. tostring(GetRealZoneText()) .. "|" .. RouteMode()
    local now = GetTime and GetTime() or 0
    if legCache.key ~= key or now - legCache.time > 3 then
        legCache.key, legCache.time = key, now
        local ok, leg = pcall(ns.NextLeg, entry, mapID, px, py)
        legCache.leg = ok and leg or nil
    end
    return legCache.leg
end

-- Yards east and south from the player (at px, py on mapID) to the leg's
-- spot. On failure returns nil and a reason word.
local function OffsetToLeg(leg, mapID, px, py)
    if not leg then return nil, "unknown" end
    if not leg.mapID then return nil, "nomap" end
    if not (mapID and px) then return nil, "noposition" end
    local cont, wx, wy = WorldPos(mapID, px, py)
    local econt, twx, twy = WorldPos(leg.mapID, leg.fx, leg.fy)
    if cont and econt then
        if cont ~= econt then return nil, "continent" end
        local north, west = twx - wx, twy - wy
        return -west, -north
    end
    if leg.mapID == mapID then
        local ww, wh = MapWorldSize(mapID)
        if ww then return (leg.fx - px) * ww, (leg.fy - py) * wh end
    end
    return nil, "noworld"
end

--------------------------------------------------------------------------
-- Icons
--------------------------------------------------------------------------
local ENTRANCE_TEX = "Interface\\Minimap\\Dungeon"
local QUEST_TEX = "Interface\\GossipFrame\\AvailableQuestIcon"
local ENTRANCE_FALLBACK_TEX = "Interface\\Icons\\INV_Misc_Map_01"

-- What the next leg's spot looks like: a flight master or a zone exit is
-- not the dungeon, so its pin must not wear the dungeon icon.
local LEG_TEX = {
    flight = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green",
    exit   = "Interface\\Icons\\Ability_Rogue_Sprint",
}

-- Top bar icon sizes. The quest "!" fills its whole box while the dungeon
-- art has a wide empty margin, so the quest icon gets a smaller box to look
-- the same size. Change HUD_QUEST_ICON to tune it.
local HUD_ICON, HUD_QUEST_ICON = 34, 24

local function SetIcon(tex, path, fallback)
    if not tex then return end
    local okTex = tex:SetTexture(path)
    if okTex == false and fallback then tex:SetTexture(fallback) end
    tex:SetTexCoord(0, 1, 0, 1)
    if tex.SetDesaturated then pcall(tex.SetDesaturated, tex, false) end
    tex:SetAlpha(1)
    tex:Show()
    if tex.cross then tex.cross:Hide() end
end

local function SetEntranceIcon(tex)
    SetIcon(tex, ENTRANCE_TEX, ENTRANCE_FALLBACK_TEX)
end

-- True when the target wears the quest icon: a quest giver, or the dungeon
-- whose picked quest is taken inside it.
local function ShowsQuestIcon(entry)
    if not entry then return false end
    return entry.isQuest or (state.questInside ~= nil and state.questInside == entry.key)
end

-- The icon of the target itself: a quest giver or the dungeon entrance.
local function SetTargetIcon(tex, entry)
    if ShowsQuestIcon(entry) then SetIcon(tex, QUEST_TEX, ENTRANCE_FALLBACK_TEX) else SetEntranceIcon(tex) end
end

-- The icon for the spot the leg leads to; the target itself (and a
-- straight line to it) keeps the target's icon.
local function SetLegIcon(tex, leg, entry)
    local path = leg and LEG_TEX[leg.kind]
    if path then SetIcon(tex, path, ENTRANCE_TEX) else SetTargetIcon(tex, entry) end
end

--------------------------------------------------------------------------
-- Live update outside: player marker on the zone map, HUD arrow, minimap pin
-- (the pin marks the leg's spot: entrance, zone exit or flight master)
--------------------------------------------------------------------------
local REASON_TEXT = {
    unknown    = "Entrance unknown. Stand at the portal and type /bnav entrance",
    nomap      = "This client has no map named %s. /bnav entrance at the portal fixes it.",
    noposition = "Your position is hidden here.",
    continent  = "On another continent: %s",
    noworld    = "Head to %s",
}

local function UpdateTravelLive(skipRefresh)
    local mapID = PlayerMapID()
    if mapID ~= state.mapID then
        state.mapID = mapID
        state.autoFloor = nil
        if not skipRefresh then RefreshIfShown() return end
    end
    local entry = NavTarget()
    if not entry then
        playerPin:Hide()
        HideMinimapPins()
        if mapFrame:IsShown() and state.tab == "boss" then
            navText:SetText("Pick a dungeon: |cffffd100/bnav go|r, or the Select Next Boss key.")
        end
        return
    end

    local px, py = PlayerPos(mapID)
    local facing = PlayerFacing()

    -- Your marker on the drawn zone map
    if mapFrame:IsShown() and state.tab == "boss" then
        if px and ns.renderedMapID == mapID then
            Place(playerPin, px, py)
            if facing and playerPin.arrow.SetRotation then playerPin.arrow:SetRotation(facing) end
            playerPin:Show()
        else
            playerPin:Hide()
        end
    end

    local leg = CurrentLeg(entry, mapID, px, py)
    local dxE, dyS = OffsetToLeg(leg, mapID, px, py)
    local legText = leg and leg.text or ""
    if entry.isQuest and leg and (leg.kind == "entrance" or leg.kind == "direct") then
        legText = string.format("Giver: %s %.1f, %.1f", entry.zone, entry.x, entry.y)
    end
    SetTargetIcon(hud.icon, entry)
    local iconSize = ShowsQuestIcon(entry) and HUD_QUEST_ICON or HUD_ICON
    hud.icon:SetSize(iconSize, iconSize)
    -- the other kept target, so you know a switch is possible
    local other = OtherNavTarget()
    local otherText = other and string.format("  |cff6699ff(also: %s)|r", other.name) or ""
    hud.main:SetText(string.format("|cffffd100%s|r  |cff888888%s|r%s", entry.name, entry.levels, otherText))

    if not dxE then
        local reason = dyS
        hud.arrow:Hide()
        HideMinimapPins()
        local text = REASON_TEXT[reason] or "No route."
        if reason == "nomap" then text = text:format(entry.zone or "?") end
        if reason == "continent" or reason == "noworld" then text = text:format(legText ~= "" and legText or "?") end
        hud.sub:SetText(text)
        navText:SetText("|cffffd100" .. entry.name .. "|r: " .. text)
        return
    end

    local yards = math.sqrt(dxE * dxE + dyS * dyS)
    -- At the quest giver: done, the arrow goes back to the dungeon (if any)
    if entry.isQuest and leg.kind == "entrance" and yards < 10 then
        Print("Arrived at " .. entry.name .. "." .. (SelectedDungeon() and (" Back to " .. SelectedDungeon().name .. ".") or ""))
        ClearQuestTarget(true)
        return
    end
    local bearing = atan2(-dxE, -dyS)
    local rel = bearing - (facing or 0)
    if hud.arrow.SetRotation then hud.arrow:SetRotation(rel) end
    hud.arrow:Show()
    local dir = facing and DirectionWord(rel) or "see map"
    -- Next to a flight master: the job is to take the flight, not to walk.
    if leg.kind == "flight" and yards < 25 then
        hud.sub:SetText("|cff40ff40" .. legText .. "|r")
        navText:SetText(string.format("|cffffd100%s|r: %s.", entry.name, legText))
    else
        local more = (leg.zonesLeft and leg.zonesLeft > 0) and string.format("  |cff888888+%d zone%s|r", leg.zonesLeft, leg.zonesLeft > 1 and "s" or "") or ""
        hud.sub:SetText(string.format("%d yd, %s  |cff888888%s|r%s", math.floor(yards), dir, legText, more))
        navText:SetText(string.format("|cffffd100%s|r: %d yd, %s.  %s%s", entry.name, math.floor(yards), dir, legText, more))
    end

    if DB().minimap then
        local p = GetMinimapPin(1)
        local clamped = PlaceMinimapPin(p, dxE, dyS, facing)
        p:SetSize(18, 18)
        SetLegIcon(p.icon, leg, entry)
        p.icon:SetAlpha(clamped and 0.55 or 1)
        p.ring:Show()
        p:Show()
        HideMinimapPinsFrom(2)
    else
        HideMinimapPins()
    end
end

--------------------------------------------------------------------------
-- Zone changes: arriving at the target clears it; a corpse run outside the
-- dungeon you died in points at its entrance.
--------------------------------------------------------------------------
local function IsGhost()
    local ok, ghost = pcall(UnitIsGhost, "player")
    return ok and ghost == true
end

local function TravelOnZone(prevCfg)
    local entry = SelectedDungeon()
    if state.inInstance and state.cfg and entry and entry.key == state.cfg.key then
        Print("Arrived at " .. entry.name .. ".")
        ClearTravelTarget(true)
    elseif TravelMode() and not entry and prevCfg and IsGhost() then
        local idx = IndexOfKey(prevCfg.key)
        if idx then
            Print("Corpse run: pointing at the " .. prevCfg.name .. " entrance.")
            BossNav_SelectDungeon(idx)
        end
    end
end

-- shared with the other BossNav files
ns.ClearQuestTarget = ClearQuestTarget
ns.ClearTravelTarget = ClearTravelTarget
ns.SetQuestTarget = SetQuestTarget
ns.SetQuestInside = SetQuestInside
ns.SwitchNav = SwitchNav
ns.CurrentLeg = CurrentLeg
ns.LevelColor = LevelColor
ns.LevelRGB = LevelRGB
ns.NavTarget = NavTarget
ns.QuestSelected = QuestSelected
ns.OtherNavTarget = OtherNavTarget
ns.MapPosFromWorld = MapPosFromWorld
ns.PlayerLevel = PlayerLevel
ns.QuestLevelColor = QuestLevelColor
ns.QuestLevelRGB = QuestLevelRGB
ns.RestoreTravelTarget = RestoreTravelTarget
ns.SelectedDungeon = SelectedDungeon
ns.SetEntranceIcon = SetEntranceIcon
ns.SetTargetIcon = SetTargetIcon
ns.TravelActive = TravelActive
ns.TravelMode = TravelMode
ns.TravelOnZone = TravelOnZone
ns.UpdateTravelLive = UpdateTravelLive
ns.WorldPos = WorldPos
