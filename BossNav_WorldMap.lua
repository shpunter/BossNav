-- Dungeon entrance marks on the game's own world map.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local EntranceOf             = ns.EntranceOf
local FlightNodes            = ns.FlightNodes
local LevelColor             = ns.LevelColor
local LevelRGB               = ns.LevelRGB
local MapPosFromWorld        = ns.MapPosFromWorld
local PlayerLevel            = ns.PlayerLevel
local RoundIcon              = ns.RoundIcon
local SetEntranceIcon        = ns.SetEntranceIcon
local TRAVEL                 = ns.TRAVEL
local WorldPos               = ns.WorldPos
local state                  = ns.state

--------------------------------------------------------------------------
-- The world map's pin canvas (modern map frame). Everything is guarded: an
-- older map frame without a canvas simply gets no marks.
--------------------------------------------------------------------------
local canvas = nil
local hooked = false
local pins = {}

local function Canvas()
    if canvas then return canvas end
    if WorldMapFrame and WorldMapFrame.GetCanvas then
        local ok, c = pcall(WorldMapFrame.GetCanvas, WorldMapFrame)
        if ok and c then canvas = c end
    end
    return canvas
end

local function ShownMapID()
    if WorldMapFrame and WorldMapFrame.GetMapID then
        local ok, id = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
        if ok and type(id) == "number" then return id end
    end
    return nil
end

local flightPins = {}

local function HideWorldMapPins()
    for _, p in ipairs(pins) do p:Hide() end
    for _, p in ipairs(flightPins) do p:Hide() end
    if ns.HideQuestMapPins then ns.HideQuestMapPins() end
end

--------------------------------------------------------------------------
-- Flight masters: every one on the shown map. Known ones solid, the one you
-- stand at highlighted, undiscovered ones faded (classic taxi icons).
--------------------------------------------------------------------------
local TAXI_KNOWN   = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green"
local TAXI_CURRENT = "Interface\\TaxiFrame\\UI-Taxi-Icon-Yellow"
local TAXI_UNKNOWN = "Interface\\TaxiFrame\\UI-Taxi-Icon-Gray"

local function FlightTooltip(p)
    if not (p.node and GameTooltip) then return end
    pcall(function()
        GameTooltip:SetOwner(p, "ANCHOR_RIGHT")
        GameTooltip:AddLine(p.node.name, 1, 0.82, 0)
        if p.node.current then
            GameTooltip:AddLine("Flight master here", 1, 1, 0.5)
        elseif p.node.known then
            GameTooltip:AddLine("Flight path known", 0.5, 1, 0.5)
        else
            GameTooltip:AddLine("Not discovered yet", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
end

local function GetFlightPin(i)
    if not flightPins[i] then
        local c = Canvas()
        local p = CreateFrame("Button", nil, c)
        p:SetSize(10, 10)
        p.layer = 0
        p.icon = p:CreateTexture(nil, "ARTWORK")
        p.icon:SetAllPoints()
        p:SetScript("OnEnter", FlightTooltip)
        p:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        flightPins[i] = p
    end
    return flightPins[i]
end

-- Hovering a pin shows its tooltip: name in the level colour (green/red),
-- level range, where the entrance is.
local function PinTooltip(p)
    local e = p.entry
    if not (e and GameTooltip) then return end
    pcall(function()
        GameTooltip:SetOwner(p, "ANCHOR_RIGHT")
        local color = LevelColor(e, PlayerLevel())
        if color then
            GameTooltip:AddLine(color .. e.name .. "|r")
        else
            GameTooltip:AddLine(e.name, 1, 0.82, 0)
        end
        GameTooltip:AddLine("Level " .. e.levels, 1, 1, 1)
        local _, _, _, where = EntranceOf(e)
        if where then GameTooltip:AddLine(where, 0.6, 0.6, 0.6) end
        GameTooltip:AddLine("Click: walk there with BossNav", 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
end

local LEVEL_DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- The icon art has a clear margin inside its box, so the disc sits this far
-- inside the box: the rim you see is the margin minus the inset.
local DISC_INSET = 1.5

-- Tint the level ring of a pin whose icon is `size` wide; hide it when the
-- level range is unknown.
local function SetLevelRing(p, size)
    local r, g, b = LevelRGB(p.entry, PlayerLevel())
    if not r then p.level:Hide() return end
    p.level:SetSize(size - 2 * DISC_INSET, size - 2 * DISC_INSET)
    p.level:SetVertexColor(r, g, b, 0.95)
    p.level:Show()
end

local function GetPin(i)
    if not pins[i] then
        local c = Canvas()
        local p = CreateFrame("Button", nil, c)
        p:SetSize(12, 12)
        p:SetHitRectInsets(-4, -4, -4, -4)   -- easier to hover a small pin
        p.layer = 10
        p.icon = p:CreateTexture(nil, "ARTWORK")
        p.icon:SetAllPoints()
        RoundIcon(p.icon)
        -- Level ring: a tinted disc just larger than the round icon, so a
        -- green/red/grey rim shows whether the dungeon fits your level.
        p.level = p:CreateTexture(nil, "BACKGROUND")
        p.level:SetTexture(LEVEL_DISC)
        p.level:SetPoint("CENTER")
        p.ring = p:CreateTexture(nil, "BORDER")
        p.ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        p.ring:SetBlendMode("ADD")
        p.ring:SetVertexColor(1.0, 0.72, 0.10, 0.95)
        p.ring:SetPoint("CENTER")
        p.ring:SetSize(28, 28)
        p:SetScript("OnClick", function(self)
            if self.travelIdx then BossNav_SelectDungeon(self.travelIdx) end
        end)
        p:SetScript("OnEnter", PinTooltip)
        p:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        pins[i] = p
    end
    return pins[i]
end

-- Anchor a pin at fractions fx, fy of the canvas. The canvas is scaled when
-- the map zooms; the pin is counter-scaled so it keeps its screen size, and
-- its offset is given in its own (counter-scaled) units.
-- Our pins sit above everything else drawn on the map (the game's own pins,
-- other addons' pins): a frame level near the top of the 0-10000 range, set
-- again on every placement because the game re-levels the canvas's children.
-- p.layer orders our own kinds: flight masters < entrances < quest givers.
local PIN_LEVEL = 9000

local function PlacePin(p, c, fx, fy)
    p:SetFrameLevel(PIN_LEVEL + (p.layer or 0))
    local w, h = c:GetWidth(), c:GetHeight()
    local cs = c:GetScale()
    if not cs or cs <= 0 then cs = 1 end
    p:SetScale(1 / cs)
    p:ClearAllPoints()
    p:SetPoint("CENTER", c, "TOPLEFT", fx * w * cs, -fy * h * cs)
end

local function RefreshWorldMapPins()
    local c = Canvas()
    local mapID = ShownMapID()
    if not (c and mapID and DB().worldmap and WorldMapFrame:IsShown()) then
        for _, p in ipairs(pins) do p:Hide() end
        for _, p in ipairs(flightPins) do p:Hide() end
        -- quest givers have their own toggle (/bnav quest map)
        if ns.RefreshQuestMapPins then pcall(ns.RefreshQuestMapPins) end
        return
    end
    local w, h = c:GetWidth(), c:GetHeight()
    if not (w and h and w > 0 and h > 0) then HideWorldMapPins() return end

    -- only one pin is "selected": the dungeon or the quest giver, whichever
    -- the arrow leads to right now (state.navFocus, see BossNav_Travel.lua)
    local target = ns.NavTarget and ns.NavTarget()
    local dungeonFocus = not (target and target.isQuest)
    local shown = 0
    for i, e in ipairs(TRAVEL) do
        local emap, ex, ey = EntranceOf(e)
        if emap and ex then
            local fx, fy
            if emap == mapID then
                fx, fy = ex, ey
            else
                local cont, wx, wy = WorldPos(emap, ex, ey)
                if cont then fx, fy = MapPosFromWorld(cont, wx, wy, mapID) end
            end
            if fx then
                shown = shown + 1
                local p = GetPin(shown)
                p.travelIdx = i
                p.entry = e
                PlacePin(p, c, fx, fy)
                SetEntranceIcon(p.icon)
                local selected = dungeonFocus and (i == state.travelIdx)
                local size = selected and 16 or 12
                p:SetSize(size, size)
                if selected then p.ring:Show() else p.ring:Hide() end
                SetLevelRing(p, size)
                p:Show()
            end
        end
    end
    for j = shown + 1, #pins do pins[j]:Hide() end

    -- Flight masters on this map
    local flights = 0
    if DB().flightmap then
        for _, n in ipairs(FlightNodes(mapID) or {}) do
            if n.x > 0 and n.x < 1 and n.y > 0 and n.y < 1 then
                flights = flights + 1
                local p = GetFlightPin(flights)
                p.node = n
                PlacePin(p, c, n.x, n.y)
                p.icon:SetTexture(n.current and TAXI_CURRENT or (n.known and TAXI_KNOWN or TAXI_UNKNOWN))
                p:SetAlpha(n.known and 1 or 0.45)
                p:Show()
            end
        end
    end
    for j = flights + 1, #flightPins do flightPins[j]:Hide() end

    -- Quest givers of the selected dungeon (BossNav_QuestMapPins.lua)
    if ns.RefreshQuestMapPins then pcall(ns.RefreshQuestMapPins) end
end

-- Hook the map frame once it exists: redraw on open, on map change and on
-- zoom; hide on close. Safe to call again.
local function SetupWorldMapPins()
    if hooked or not WorldMapFrame then return end
    hooked = true
    local function refresh() pcall(RefreshWorldMapPins) end
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", refresh) end
    if WorldMapFrame.OnCanvasScaleChanged then hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", refresh) end
    -- dragging a zoomed map moves the view: quest pins at its edge follow
    if WorldMapFrame.OnCanvasPanChanged then hooksecurefunc(WorldMapFrame, "OnCanvasPanChanged", refresh) end
    local sc = WorldMapFrame.ScrollContainer
    if sc and sc.HookScript then pcall(sc.HookScript, sc, "OnMouseUp", refresh) end
    WorldMapFrame:HookScript("OnShow", refresh)
    WorldMapFrame:HookScript("OnHide", HideWorldMapPins)
end

SetupWorldMapPins()

-- Zoom the open world map in on a spot (fractions of the shown map).
local function ZoomWorldMapTo(fx, fy)
    local f = WorldMapFrame
    local sc = f and f.ScrollContainer
    if f.PanAndZoomTo and pcall(f.PanAndZoomTo, f, fx, fy) then return end
    if sc and sc.PanAndZoomTo and pcall(sc.PanAndZoomTo, sc, fx, fy) then return end
    if sc and sc.SetZoomTarget and sc.GetScaleForMaxZoom and sc.SetPanTarget then
        pcall(function()
            sc:SetZoomTarget(sc:GetScaleForMaxZoom())
            sc:SetPanTarget(fx, fy)
        end)
    end
end

-- Open the game's world map on a uiMap, zoomed in on (fx, fy). The map lays
-- itself out a frame after opening, so it zooms again a moment later and
-- calls after() then (to redraw the pins).
local function OpenWorldMapAt(mapID, fx, fy, after)
    if not WorldMapFrame:IsShown() then
        if not (OpenWorldMap and pcall(OpenWorldMap, mapID)) then
            pcall(ShowUIPanel, WorldMapFrame)
        end
    end
    if WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID) end
    ZoomWorldMapTo(fx, fy)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, function()
            if WorldMapFrame:IsShown() and ShownMapID() == mapID then ZoomWorldMapTo(fx, fy) end
            if after then pcall(after) end
        end)
    end
    if after then pcall(after) end
end

-- /bnav go show and the map button on a dungeon row: pick the dungeon (the
-- arrow leads to it) and open the world map on its entrance, zoomed in, so
-- its pin wears the ring.
local function ShowDungeonOnWorldMap(idx)
    local e = TRAVEL[idx]
    if not e then ns.Print("No dungeon " .. tostring(idx) .. " in the list.") return end
    local mapID, fx, fy = EntranceOf(e)
    if not (mapID and fx and fy) then
        ns.Print(e.name .. ": entrance unknown (stand at it and type /bnav entrance).")
        return
    end
    if idx ~= state.travelIdx then BossNav_SelectDungeon(idx) end
    local db = DB()
    if not db.worldmap then
        db.worldmap = true
        ns.Print("Dungeon entrance marks on the world map turned on (/bnav worldmap turns them off).")
    end
    OpenWorldMapAt(mapID, fx, fy, RefreshWorldMapPins)
    if ns.mapFrame and ns.mapFrame:IsShown() then BossNav_RefreshMap() end
end

-- shared with the other BossNav files
ns.OpenWorldMapAt = OpenWorldMapAt
ns.ShowDungeonOnWorldMap = ShowDungeonOnWorldMap
ns.HideWorldMapPins = HideWorldMapPins
ns.RefreshWorldMapPins = RefreshWorldMapPins
ns.SetupWorldMapPins = SetupWorldMapPins
ns.WorldMapCanvas = Canvas
ns.WorldMapPlacePin = PlacePin
ns.WorldMapShownID = ShownMapID
