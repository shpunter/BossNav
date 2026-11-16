-- Dungeon entrance marks on the game's own world map.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local EntranceOf             = ns.EntranceOf
local LevelColor             = ns.LevelColor
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

local function HideWorldMapPins()
    for _, p in ipairs(pins) do p:Hide() end
end

local function PinTooltip(p)
    local e = p.entry
    if not (e and GameTooltip) then return end
    pcall(function()
        GameTooltip:SetOwner(p, "ANCHOR_RIGHT")
        GameTooltip:AddLine(e.name, 1, 0.82, 0)
        GameTooltip:AddLine("Level " .. e.levels, 1, 1, 1)
        local _, _, _, where = EntranceOf(e)
        if where then GameTooltip:AddLine(where, 0.6, 0.6, 0.6) end
        GameTooltip:AddLine("Click: walk there with BossNav", 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
end

local function GetPin(i)
    if not pins[i] then
        local c = Canvas()
        local p = CreateFrame("Button", nil, c)
        p:SetSize(20, 20)
        p:SetFrameLevel(c:GetFrameLevel() + 200)
        p.icon = p:CreateTexture(nil, "ARTWORK")
        p.icon:SetAllPoints()
        RoundIcon(p.icon)
        p.ring = p:CreateTexture(nil, "BORDER")
        p.ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        p.ring:SetBlendMode("ADD")
        p.ring:SetVertexColor(1.0, 0.72, 0.10, 0.95)
        p.ring:SetPoint("CENTER")
        p.ring:SetSize(46, 46)
        p.label = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        p.label:SetPoint("TOP", p, "BOTTOM", 0, 1)
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
local function PlacePin(p, c, fx, fy)
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
        HideWorldMapPins()
        return
    end
    local w, h = c:GetWidth(), c:GetHeight()
    if not (w and h and w > 0 and h > 0) then HideWorldMapPins() return end

    local myLevel = PlayerLevel()
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
                local selected = (i == state.travelIdx)
                local levelColor = LevelColor(e, myLevel)
                local color = levelColor or (selected and "|cffffd100" or "|cffffffff")
                p.label:SetText(string.format("%s%s|r %s%s|r", color, e.name, levelColor or "|cff888888", e.levels))
                if selected then p:SetSize(26, 26) p.ring:Show() else p:SetSize(20, 20) p.ring:Hide() end
                p:Show()
            end
        end
    end
    for j = shown + 1, #pins do pins[j]:Hide() end
end

-- Hook the map frame once it exists: redraw on open, on map change and on
-- zoom; hide on close. Safe to call again.
local function SetupWorldMapPins()
    if hooked or not WorldMapFrame then return end
    hooked = true
    local function refresh() pcall(RefreshWorldMapPins) end
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", refresh) end
    if WorldMapFrame.OnCanvasScaleChanged then hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", refresh) end
    WorldMapFrame:HookScript("OnShow", refresh)
    WorldMapFrame:HookScript("OnHide", HideWorldMapPins)
end

SetupWorldMapPins()

-- shared with the other BossNav files
ns.HideWorldMapPins = HideWorldMapPins
ns.RefreshWorldMapPins = RefreshWorldMapPins
ns.SetupWorldMapPins = SetupWorldMapPins
