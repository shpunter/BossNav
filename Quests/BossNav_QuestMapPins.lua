-- Quest givers on the game's own world map: where to take the quests of the
-- dungeon the Quests tab is about (the one you are in, else the one picked
-- with /bnav go). Only that dungeon's quests you can pick up right now:
-- your faction, your class, your level reached (even with /bnav quest all),
-- not done and not in your log yet. Givers on the same spot share one pin.
-- A quest in your log shows a "?" pin where it is handed in instead.
-- A giver outside the part of the map you are looking at (zoomed into a
-- zone, or into part of a map) stays visible: its pin sits on the edge of
-- the view, faded, with an arrow pointing toward the real spot.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local CanTakeQuest           = ns.CanTakeQuest
local MapPosFromWorld        = ns.MapPosFromWorld
local PlayerLevel            = ns.PlayerLevel
local QuestLevelRGB          = ns.QuestLevelRGB
local QuestStatus            = ns.QuestStatus
local QUEST_STATUS_WORD      = ns.QUEST_STATUS_WORD
local QuestXPText            = ns.QuestXPText
local ResolveMapIDByName     = ns.ResolveMapIDByName
local RoundIcon              = ns.RoundIcon
local VisibleQuests          = ns.VisibleQuests
local WorldMapCanvas         = ns.WorldMapCanvas
local WorldMapPlacePin       = ns.WorldMapPlacePin
local WorldMapShownID        = ns.WorldMapShownID
local WorldPos               = ns.WorldPos
local state                  = ns.state

local QUEST_TEX = "Interface\\GossipFrame\\AvailableQuestIcon"
local TURNIN_TEX = "Interface\\GossipFrame\\ActiveQuestIcon"
local FACTION_RGB = { A = { 0.25, 0.5, 1 }, H = { 1, 0.25, 0.25 }, B = { 1, 0.82, 0 } }

local pins = {}

local function HideQuestMapPins()
    for _, p in ipairs(pins) do p:Hide() end
end

-- Tooltip: the giver, then every quest taken from them, coloured like the
-- Quests tab: red above you, grey when it gives no experience, else green.
local function PinTooltip(p)
    if not (p.spot and GameTooltip) then return end
    pcall(function()
        local spot = p.spot
        GameTooltip:SetOwner(p, "ANCHOR_RIGHT")
        GameTooltip:AddLine((spot.handIn and "Hand in to " or "") .. spot.giver, 1, 0.82, 0)
        GameTooltip:AddLine(string.format("%s  %.1f, %.1f%s", spot.zone, spot.x, spot.y, spot.approx and " (about)" or ""), 0.6, 0.6, 0.6)
        local myLevel = PlayerLevel()
        for _, e in ipairs(spot.quests) do
            local q = e.quest
            local r, g, b = QuestLevelRGB(q, myLevel)
            if not r then
                local rgb = FACTION_RGB[q.faction] or FACTION_RGB.B
                r, g, b = rgb[1], rgb[2], rgb[3]
            end
            -- tooltips cannot cross out text: a done / in-log quest is tagged and dimmed
            local status = QuestStatus(q)
            if status then r, g, b = r * 0.55, g * 0.55, b * 0.55 end
            local xpText = not status and QuestXPText(q)
            GameTooltip:AddLine(string.format("[%d] %s%s%s%s", q.level, q.name, q.classes and (" (" .. q.classes .. ")") or "",
                status and ("  - " .. QUEST_STATUS_WORD[status]) or "",
                xpText and ("  |cffb48cff" .. xpText .. "|r") or ""), r, g, b)
        end
        if spot.offView then
            GameTooltip:AddLine("Outside this view; the arrow points to it", 1, 0.6, 0.2)
            GameTooltip:AddLine("Click: open the " .. spot.zone .. " map and show it on the Quests tab", 0.5, 0.8, 1)
        else
            GameTooltip:AddLine("Click: show it on the BossNav Quests tab", 0.5, 0.8, 1)
        end
        GameTooltip:Show()
    end)
end

local function GetPin(i)
    if not pins[i] then
        local c = WorldMapCanvas()
        local p = CreateFrame("Button", nil, c)
        p:SetSize(16, 16)
        p:SetHitRectInsets(-4, -4, -4, -4)
        p.layer = 20   -- above the entrance pins
        p.icon = p:CreateTexture(nil, "ARTWORK")
        p.icon:SetAllPoints()
        p.icon:SetTexture(QUEST_TEX)
        p.ring = p:CreateTexture(nil, "BORDER")
        p.ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        p.ring:SetBlendMode("ADD")
        p.ring:SetVertexColor(1.0, 0.72, 0.10, 0.95)
        p.ring:SetPoint("CENTER")
        p.ring:SetSize(36, 36)
        p.count = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        p.count:SetPoint("BOTTOMLEFT", p, "BOTTOMRIGHT", -3, -2)
        p:SetScript("OnClick", function(self)
            if not self.spot then return end
            -- pick its first quest; the arrow leads to this giver
            ns.SelectQuest(self.spot.quests[1].idx)
            -- an edge pin: go to the giver's own zone map
            if self.spot.offView and self.spot.mapID and WorldMapFrame.SetMapID then
                pcall(WorldMapFrame.SetMapID, WorldMapFrame, self.spot.mapID)
            end
            if not ns.mapFrame:IsShown() then ns.mapFrame:Show() end
            ns.SetTab("quest")
        end)
        p:SetScript("OnEnter", PinTooltip)
        p:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        pins[i] = p
    end
    return pins[i]
end

-- The spots to mark: one per giver place, each with its quests and their
-- index in the Quests tab list (for the click and the highlight).
-- A quest in your log adds a hand-in spot ("?" pin) where it goes back.
local function GiverSpots()
    local list = VisibleQuests()
    local spots, byKey = {}, {}
    local function Add(spot, q, i, handIn)
        local key = string.format("%s|%s|%.0f|%.0f", handIn and "in" or "take", spot.zone, spot.x, spot.y)
        local s = byKey[key]
        if not s then
            s = { zone = spot.zone, x = spot.x, y = spot.y, approx = q.approx, giver = spot.giver or "?",
                  handIn = handIn, quests = {} }
            byKey[key] = s
            spots[#spots + 1] = s
        end
        s.quests[#s.quests + 1] = { quest = q, idx = i, navKey = "quest:" .. tostring(spot.id or spot.name) }
    end
    for i, q in ipairs(list) do
        -- quests you can pick up now: faction, class, level, not done or in log
        if q.zone and q.x and q.y and not q.inside and CanTakeQuest(q) then
            Add(q, q, i, false)
        elseif ns.QuestNavSpot and QuestStatus(q) == "active" then
            local h = ns.QuestNavSpot(q, "handin")
            if h.zone and h.x and h.y and not h.inside then Add(h, q, i, true) end
        end
    end
    return spots
end

-- A world point as fractions of a uiMap, NOT limited to 0..1: a point off the
-- map comes back below 0 or above 1. nil when it is on another continent.
local function RawMapPos(cont, wx, wy, mapID)
    if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, cont, CreateVector2D(wx, wy), mapID)
    if ok and pos and type(pos.x) == "number" and type(pos.y) == "number" then return pos.x, pos.y end
    return nil
end

-- Where a spot falls on the shown map as fractions (may be outside 0..1),
-- or nil when that cannot be worked out (another continent, unknown zone).
local function SpotOnMap(s, mapID)
    local zoneMap = ResolveMapIDByName(s.zone)
    if not zoneMap then return nil end
    s.mapID = zoneMap
    if zoneMap == mapID then return s.x / 100, s.y / 100 end
    local cont, wx, wy = WorldPos(zoneMap, s.x / 100, s.y / 100)
    if not cont then return nil end
    local fx, fy = RawMapPos(cont, wx, wy, mapID)
    if fx then return fx, fy end
    return MapPosFromWorld(cont, wx, wy, mapID)
end

-- The part of the map currently on screen, as fractions: left, top, right,
-- bottom. The whole map when the client gives no view rectangle (not zoomed).
local function ViewRect()
    local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
    if sc and sc.NormalizeUIPosition and sc.GetLeft then
        local ok, l, t, r, b = pcall(function()
            -- NormalizeUIPosition takes UIParent-scale screen coordinates
            local k = sc:GetEffectiveScale() / UIParent:GetEffectiveScale()
            local x1, y1 = sc:NormalizeUIPosition(sc:GetLeft() * k, sc:GetTop() * k)
            local x2, y2 = sc:NormalizeUIPosition(sc:GetRight() * k, sc:GetBottom() * k)
            return x1, y1, x2, y2
        end)
        if ok and type(l) == "number" and type(t) == "number" and type(r) == "number" and type(b) == "number" and r > l and b > t then
            return math.max(0, l), math.max(0, t), math.min(1, r), math.min(1, b)
        end
    end
    return 0, 0, 1, 1
end

-- Arrow on an edge pin pointing at the real spot (fx, fy) from (px, py).
local function PointArrow(p, px, py, fx, fy)
    if not p.arrow then
        p.arrow = p:CreateTexture(nil, "OVERLAY")
        p.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
        p.arrow:SetSize(18, 18)
    end
    local dx, dy = fx - px, fy - py
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then p.arrow:Hide() return end
    p.arrow:ClearAllPoints()
    p.arrow:SetPoint("CENTER", p, "CENTER", dx / len * 13, -dy / len * 13)
    -- the arrow art points up; screen y grows downward on the map
    if p.arrow.SetRotation then p.arrow:SetRotation(math.atan2 and math.atan2(-dx, -dy) or math.atan(-dx, -dy)) end
    p.arrow:Show()
end

local EDGE_MARGIN = 0.025

local function RefreshQuestMapPins()
    local c = WorldMapCanvas()
    local mapID = WorldMapShownID()
    if not (c and mapID and DB().questmap and WorldMapFrame and WorldMapFrame:IsShown()) then
        HideQuestMapPins()
        return
    end
    local l, t, r, b = ViewRect()
    -- keep the edge pins inside the visible part, a little off its border
    local ml, mt = l + (r - l) * EDGE_MARGIN, t + (b - t) * EDGE_MARGIN
    local mr, mb = r - (r - l) * EDGE_MARGIN, b - (b - t) * EDGE_MARGIN
    -- a giver pin is "selected" only while the arrow leads to that quest's
    -- giver; while it leads to the dungeon, the dungeon pin has the ring
    local target = ns.NavTarget and ns.NavTarget()
    local questKey = target and target.isQuest and target.key or nil
    local shown = 0
    for _, s in ipairs(GiverSpots()) do
        local fx, fy = SpotOnMap(s, mapID)
        if fx then
            shown = shown + 1
            local p = GetPin(shown)
            p.spot = s
            local selected = false
            if questKey then
                for _, e in ipairs(s.quests) do
                    if e.navKey == questKey then selected = true end
                end
            end
            p.icon:SetTexture(s.handIn and TURNIN_TEX or QUEST_TEX)
            local px = math.max(ml, math.min(mr, fx))
            local py = math.max(mt, math.min(mb, fy))
            local onEdge = (px ~= fx or py ~= fy)
            s.offView = onEdge
            local size = selected and 20 or 16
            if onEdge then size = size - 2 end
            p:SetSize(size, size)
            if selected then p.ring:Show() else p.ring:Hide() end
            p.count:SetText(#s.quests > 1 and tostring(#s.quests) or "")
            p:SetAlpha(onEdge and 0.7 or (s.approx and 0.75 or 1))
            if onEdge then PointArrow(p, px, py, fx, fy) elseif p.arrow then p.arrow:Hide() end
            WorldMapPlacePin(p, c, px, py)
            p:Show()
        end
    end
    for j = shown + 1, #pins do pins[j]:Hide() end
end

-- /bnav quest show and the map button on a Quests tab row: navigate to the
-- giver, and open the game's world map on the giver's zone, zoomed in on
-- the giver, with the quest picked so its pin wears the ring.
local function ShowQuestOnWorldMap(idx)
    local list = VisibleQuests()
    local q = list[idx]
    if not q then ns.Print("No quest " .. tostring(idx) .. " in the list.") return end
    -- another quest than the picked one: its arrow end is picked by itself
    if idx ~= state.questIdx then state.questEnd = nil end
    -- a quest in your log: whoever takes it back
    if ns.QuestNavSpot then q = ns.QuestNavSpot(q) end
    if q.inside or not (q.zone and q.x and q.y) then
        local why = q.inside and (q.handIn and "handed in inside the dungeon" or "taken inside the dungeon")
            or (q.handIn and "hand-in place unknown" or "place unknown")
        ns.Print(q.name .. ": no spot on the world map (" .. why .. ").")
        return
    end
    local mapID = ResolveMapIDByName(q.zone)
    if not mapID then ns.Print("Cannot find the " .. q.zone .. " map.") return end
    state.questIdx = idx
    -- the travel arrow, HUD and minimap pin lead to the giver
    if ns.SetQuestTarget then ns.SetQuestTarget(q) end
    local db = DB()
    if not db.questmap then
        db.questmap = true
        ns.Print("Quest givers on the world map turned on (/bnav quest map turns them off).")
    end
    ns.OpenWorldMapAt(mapID, q.x / 100, q.y / 100, RefreshQuestMapPins)
    if ns.mapFrame and ns.mapFrame:IsShown() then BossNav_RefreshMap() end
end

-- shared with the other BossNav files
ns.ShowQuestOnWorldMap = ShowQuestOnWorldMap
ns.HideQuestMapPins = HideQuestMapPins
ns.RefreshQuestMapPins = RefreshQuestMapPins
