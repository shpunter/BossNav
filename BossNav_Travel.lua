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

-- True while the live arrow should run outside: a dungeon is picked.
local function TravelActive()
    return TravelMode() and SelectedDungeon() ~= nil
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

-- Colour code of a dungeon against your level: red above you, grey when you
-- have outgrown it, green when you are inside its range, nil when unknown.
local function LevelColor(entry, myLevel)
    if not (myLevel and entry.minLevel and entry.maxLevel) then return nil end
    if entry.minLevel > myLevel then return "|cffff4040" end
    if entry.maxLevel < myLevel then return "|cff888888" end
    return "|cff40ff40"
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

-- Yards east and south from the player (at px, py on mapID) to the entrance of
-- an entry. On failure returns nil and a reason word.
local function OffsetToEntrance(entry, mapID, px, py)
    local emap, ex, ey = EntranceOf(entry)
    if not ex then return nil, "unknown" end
    if not emap then return nil, "nomap" end
    if not (mapID and px) then return nil, "noposition" end
    local cont, wx, wy = WorldPos(mapID, px, py)
    local econt, twx, twy = WorldPos(emap, ex, ey)
    if cont and econt then
        if cont ~= econt then return nil, "continent" end
        local north, west = twx - wx, twy - wy
        return -west, -north
    end
    if emap == mapID then
        local ww, wh = MapWorldSize(mapID)
        if ww then return (ex - px) * ww, (ey - py) * wh end
    end
    return nil, "noworld"
end

--------------------------------------------------------------------------
-- Icons
--------------------------------------------------------------------------
local ENTRANCE_TEX = "Interface\\Minimap\\Dungeon"
local ENTRANCE_FALLBACK_TEX = "Interface\\Icons\\INV_Misc_Map_01"

local function SetEntranceIcon(tex)
    if not tex then return end
    local okTex = tex:SetTexture(ENTRANCE_TEX)
    if okTex == false then tex:SetTexture(ENTRANCE_FALLBACK_TEX) end
    tex:SetTexCoord(0, 1, 0, 1)
    if tex.SetDesaturated then pcall(tex.SetDesaturated, tex, false) end
    tex:SetAlpha(1)
    tex:Show()
    if tex.cross then tex.cross:Hide() end
end

--------------------------------------------------------------------------
-- Live update outside: player marker on the zone map, HUD arrow, minimap pin
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
    local entry = SelectedDungeon()
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

    local dxE, dyS = OffsetToEntrance(entry, mapID, px, py)
    local _, _, _, where = EntranceOf(entry)
    SetEntranceIcon(hud.icon)
    hud.main:SetText(string.format("|cffffd100%s|r  |cff888888%s|r", entry.name, entry.levels))

    if not dxE then
        local reason = dyS
        hud.arrow:Hide()
        HideMinimapPins()
        local text = REASON_TEXT[reason] or "No route."
        if reason == "nomap" then text = text:format(entry.zone or "?") end
        if reason == "continent" or reason == "noworld" then text = text:format(where or "?") end
        hud.sub:SetText(text)
        navText:SetText("|cffffd100" .. entry.name .. "|r: " .. text)
        return
    end

    local yards = math.sqrt(dxE * dxE + dyS * dyS)
    local bearing = atan2(-dxE, -dyS)
    local rel = bearing - (facing or 0)
    if hud.arrow.SetRotation then hud.arrow:SetRotation(rel) end
    hud.arrow:Show()
    local dir = facing and DirectionWord(rel) or "see map"
    local zone = GetRealZoneText() or ""
    hud.sub:SetText(string.format("%d yd, %s  |cff888888%s|r", math.floor(yards), dir, zone))
    navText:SetText(string.format("|cffffd100%s|r: %d yd, %s.  Entrance: %s", entry.name, math.floor(yards), dir, where or "?"))

    if DB().minimap then
        local p = GetMinimapPin(1)
        local clamped = PlaceMinimapPin(p, dxE, dyS, facing)
        p:SetSize(18, 18)
        SetEntranceIcon(p.icon)
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
ns.ClearTravelTarget = ClearTravelTarget
ns.LevelColor = LevelColor
ns.MapPosFromWorld = MapPosFromWorld
ns.PlayerLevel = PlayerLevel
ns.RestoreTravelTarget = RestoreTravelTarget
ns.SelectedDungeon = SelectedDungeon
ns.SetEntranceIcon = SetEntranceIcon
ns.TravelActive = TravelActive
ns.TravelMode = TravelMode
ns.TravelOnZone = TravelOnZone
ns.UpdateTravelLive = UpdateTravelLive
ns.WorldPos = WorldPos
