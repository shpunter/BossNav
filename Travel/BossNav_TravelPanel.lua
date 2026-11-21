-- The window outside a dungeon: your zone map with the entrance pin, and the
-- scrollable dungeon selector in the sidebar.
local ADDON, ns = ...
-- from the files loaded before this one
local CurrentLeg             = ns.CurrentLeg
local EntranceOf             = ns.EntranceOf
local GetBossPin             = ns.GetBossPin
local GetRow                 = ns.GetRow
local GetWayPin              = ns.GetWayPin
local HasEntrance            = ns.HasEntrance
local HideRouteToggle        = ns.HideRouteToggle
local LevelColor             = ns.LevelColor
local listAnchor             = ns.listAnchor
local MAX_ROWS               = ns.MAX_ROWS
local MapName                = ns.MapName
local MapPosFromWorld        = ns.MapPosFromWorld
local NavTarget              = ns.NavTarget
local OtherNavTarget         = ns.OtherNavTarget
local Place                  = ns.Place
local PlayerFaction          = ns.PlayerFaction
local PlayerLevel            = ns.PlayerLevel
local PlayerMapID            = ns.PlayerMapID
local PlayerPos              = ns.PlayerPos
local ROW_H                  = ns.ROW_H
local RenderBlank            = ns.RenderBlank
local RenderNative           = ns.RenderNative
local SIDEBAR_W              = ns.SIDEBAR_W
local SetEntranceIcon        = ns.SetEntranceIcon
local SetTargetIcon          = ns.SetTargetIcon
local ShowRouteToggle        = ns.ShowRouteToggle
local TRAVEL                 = ns.TRAVEL
local TravelMode             = ns.TravelMode
local WorldPos               = ns.WorldPos
local headerText             = ns.headerText
local helpText               = ns.helpText
local mapFrame               = ns.mapFrame
local noArtText              = ns.noArtText
local sidebar                = ns.sidebar
local state                  = ns.state
local statusText             = ns.statusText

local HELP_TRAVEL = "/bnav go [n|name] | /bnav go up|down | /bnav go off | /bnav entrance | /bnav hud | /bnav help"

--------------------------------------------------------------------------
-- Scrolling: the list is longer than the sidebar. scrollFirst is the index
-- of the dungeon shown in the top row. The mouse wheel over the list, the
-- /bnav go up|down commands and selecting a dungeon all move it.
--------------------------------------------------------------------------
local scrollFirst = 1

local function MaxFirst()
    return math.max(1, #TRAVEL - MAX_ROWS + 1)
end

local function ClampScroll(first)
    return math.max(1, math.min(first, MaxFirst()))
end

local function KeepSelectionVisible()
    local sel = state.travelIdx
    if not sel then return end
    if sel < scrollFirst then
        scrollFirst = sel
    elseif sel > scrollFirst + MAX_ROWS - 1 then
        scrollFirst = sel - MAX_ROWS + 1
    end
    scrollFirst = ClampScroll(scrollFirst)
end

-- Scroll the list by a number of rows (negative = up) and redraw.
local function TravelScrollBy(rows)
    scrollFirst = ClampScroll(scrollFirst + rows)
    if mapFrame:IsShown() then BossNav_RefreshMap() end
end

sidebar:EnableMouseWheel(true)
sidebar:SetScript("OnMouseWheel", function(_, delta)
    if TravelMode() and state.tab == "travel" then TravelScrollBy(-delta * 3) end
end)

-- Scrollbar on the right edge of the sidebar: a track and a thumb
local scrollbar = CreateFrame("Frame", nil, sidebar)
scrollbar:SetWidth(5)
scrollbar:SetPoint("TOPRIGHT", listAnchor, "TOPRIGHT", -1, 0)
scrollbar:SetPoint("BOTTOMRIGHT", listAnchor, "TOPRIGHT", -1, -MAX_ROWS * ROW_H)
scrollbar.track = scrollbar:CreateTexture(nil, "BACKGROUND")
scrollbar.track:SetAllPoints()
scrollbar.track:SetColorTexture(0.15, 0.15, 0.18, 1)
scrollbar.thumb = scrollbar:CreateTexture(nil, "ARTWORK")
scrollbar.thumb:SetWidth(5)
scrollbar.thumb:SetColorTexture(0.75, 0.62, 0.20, 1)
scrollbar:Hide()

local function DrawScrollbar()
    local n = #TRAVEL
    if n <= MAX_ROWS then scrollbar:Hide() return end
    local trackH = MAX_ROWS * ROW_H
    local thumbH = math.max(12, trackH * MAX_ROWS / n)
    local offset = (scrollFirst - 1) / (n - MAX_ROWS) * (trackH - thumbH)
    scrollbar.thumb:ClearAllPoints()
    scrollbar.thumb:SetPoint("TOP", scrollbar, "TOP", 0, -offset)
    scrollbar.thumb:SetHeight(thumbH)
    scrollbar:Show()
end

-- Called at the start of every window redraw so the bar never stays over
-- the boss list or the Loot / Profs panels, and the foot / flying boxes
-- under the map show only in travel mode.
local function HideTravelWidgets()
    scrollbar:Hide()
    HideRouteToggle()
end

--------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------
-- Target pin on the drawn map (dungeon entrance or quest giver), when it
-- lies on it.
local function DrawEntrancePin(entry)
    local emap, ex, ey = EntranceOf(entry)
    if not (emap and ex and ns.renderedMapID) then return end
    local fx, fy
    if emap == ns.renderedMapID then
        fx, fy = ex, ey
    else
        local cont, wx, wy = WorldPos(emap, ex, ey)
        if cont then fx, fy = MapPosFromWorld(cont, wx, wy, ns.renderedMapID) end
    end
    if not fx then return end
    local p = GetBossPin(1)
    p.bossIdx = nil
    Place(p, fx, fy)
    SetTargetIcon(p.icon, entry)
    p:SetSize(28, 28)
    p.ring:Show()
    p.label:SetText("|cffffd100" .. entry.name .. "|r")
    p.label:Show()
    p:Show()
end

-- The spot to walk to now when the entrance is in another zone: the zone
-- exit or the flight master, as a numbered dot with the leg's words.
local function DrawLegPin(entry, mapID)
    local px, py = PlayerPos(mapID)
    local leg = CurrentLeg(entry, mapID, px, py)
    if not (leg and leg.mapID and ns.renderedMapID) then return end
    if leg.kind == "entrance" or leg.kind == "direct" then return end
    local fx, fy
    if leg.mapID == ns.renderedMapID then
        fx, fy = leg.fx, leg.fy
    else
        local cont, wx, wy = WorldPos(leg.mapID, leg.fx, leg.fy)
        if cont then fx, fy = MapPosFromWorld(cont, wx, wy, ns.renderedMapID) end
    end
    if not fx then return end
    local p = GetWayPin(1)
    Place(p, fx, fy)
    p.dot:SetTexture("Interface\\COMMON\\Indicator-Yellow")
    p.num:SetText("|cffffd100" .. leg.text .. "|r")
    p:Show()
end

-- Sidebar: the rows from scrollFirst on, selected dungeon kept in view.
-- Names are coloured against your level (see LevelColor in BossNav_Travel.lua):
-- red above you, grey when outgrown, green when in range.
local function DrawSelector()
    KeepSelectionVisible()
    local myLevel = PlayerLevel()
    local myFaction = PlayerFaction()
    for row = 1, MAX_ROWS do
        local i = scrollFirst + row - 1
        local e = TRAVEL[i]
        if not e then break end
        local r = GetRow(row)
        -- only while the dungeon (not a quest) is the selection
        local selected = (i == state.travelIdx) and not (ns.QuestSelected and ns.QuestSelected())
        r.bossIdx = nil
        r.travelIdx = i
        r.mark:SetText(selected and ns.SELECTED_MARK or "")
        r.mark:Show()
        SetEntranceIcon(r.icon)
        local levelColor = LevelColor(e, myLevel)
        local color = levelColor or (selected and "|cffffd100" or "|cffffffff")
        local tag = HasEntrance(e) and "" or " |cff666666(no entrance)|r"
        if e.faction and myFaction and e.faction ~= myFaction then
            tag = tag .. " |cff666666(" .. e.faction .. " city)|r"
        end
        r.text:SetText(string.format("%s%s|r  %s%s|r%s", color, e.name, levelColor or "|cff888888", e.levels, tag))
        -- the map button only when the entrance has a spot on the world map
        r:SetMapButton(HasEntrance(e))
        r:Show()
    end
    DrawScrollbar()
end

-- Draws the whole window in travel mode. Returns false inside a dungeon or
-- in preview mode so the boss view is drawn instead.
local function RenderTravelTab()
    if not TravelMode() or state.tab ~= "travel" then return false end

    local mapID = PlayerMapID()
    state.mapID = mapID
    state.autoFloor = nil
    state.shownFloor = nil
    if not RenderNative(mapID) then
        RenderBlank()
        noArtText:SetText("This client exposes no map art for " .. tostring(MapName(mapID) or GetRealZoneText() or "this zone") .. ".")
        noArtText:Show()
    end

    local zone = MapName(mapID) or GetRealZoneText() or ""
    headerText:SetText("|cffffd100Travel|r  |cff888888" .. zone .. "|r")
    -- Follows the arrow: the quest giver or the dungeon, whichever
    -- /bnav nav (the Switch Navigation key) points at right now.
    local entry = NavTarget()
    if entry then
        local _, _, _, where = EntranceOf(entry)
        local other = OtherNavTarget()
        statusText:SetText(string.format("%s: |cff00ff00%s|r |cff888888%s|r   %s%s",
            entry.isQuest and "Quest giver" or "Dungeon", entry.name, entry.levels,
            where or "entrance unknown (/bnav entrance at the portal)",
            other and string.format("   |cff6699ff(also: %s)|r", other.name) or ""))
        DrawEntrancePin(entry)
        DrawLegPin(entry, mapID)
    else
        statusText:SetText("No dungeon picked. /bnav go picks the next one; /bnav go name or number picks one.")
    end

    DrawSelector()
    helpText:SetText(HELP_TRAVEL)
    ShowRouteToggle()
    BossNav_UpdateLive(true)
    return true
end

-- shared with the other BossNav files
ns.HideTravelWidgets = HideTravelWidgets
ns.RenderTravelTab = RenderTravelTab
ns.TravelScrollBy = TravelScrollBy
