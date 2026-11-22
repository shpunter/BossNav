-- Quests tab of the map window: the quests of a dungeon in the sidebar, and a
-- panel over the map saying who gives the selected one and where. Inside a
-- dungeon it lists that dungeon; outside, the dungeon picked with /bnav go.
-- The quest data lives in BossNav_QuestData.lua.
local ADDON, ns = ...
-- from the files loaded before this one
local CANVAS_W               = ns.CANVAS_W
local DungeonQuests          = ns.DungeonQuests
local MARK_W                 = ns.MARK_W
local NAME_FONT_SIZE         = ns.NAME_FONT_SIZE
local PlayerFaction          = ns.PlayerFaction
local PlayerLevel            = ns.PlayerLevel
local Print                  = ns.Print
local QuestLevelColor        = ns.QuestLevelColor
local QuestLevelRGB          = ns.QuestLevelRGB
local QuestStatus            = ns.QuestStatus
local QUEST_STATUS_WORD      = ns.QUEST_STATUS_WORD
local listAnchor             = ns.listAnchor
local SIDEBAR_W              = ns.SIDEBAR_W
local SelectedDungeon        = ns.SelectedDungeon
local SetFontSize            = ns.SetFontSize
local TravelMode             = ns.TravelMode
local canvas                 = ns.canvas
local headerText             = ns.headerText
local navText                = ns.navText
local sidebar                = ns.sidebar
local state                  = ns.state
local statusText             = ns.statusText

local ROW_H = 24
local MAX_ROWS = 20
local FACTION_WORD = { A = "Alliance", H = "Horde", B = "Both factions" }

-- Faction crest(s) as inline text icons: one for a one-side quest, both for
-- a quest either side can take.
local ICON_A = "|TInterface\\FriendsFrame\\PlusManz-Alliance:%d:%d|t"
local ICON_H = "|TInterface\\FriendsFrame\\PlusManz-Horde:%d:%d|t"
local function FactionIcons(q, size)
    local a, h = ICON_A:format(size, size), ICON_H:format(size, size)
    if q.faction == "A" then return a end
    if q.faction == "H" then return h end
    return a .. h
end

--------------------------------------------------------------------------
-- Which quests to show
--------------------------------------------------------------------------
-- The dungeon the tab is about: the one you are in (or previewing), else
-- the one picked in the travel list.
local function QuestDungeon()
    if not TravelMode() then return state.cfg end
    local e = SelectedDungeon()
    return e and e.cfg or nil
end

-- Your class as a lowercase English word ("rogue"), or nil when the client
-- will not say.
local function PlayerClass()
    local ok, _, classFile = pcall(UnitClass, "player")
    if not ok or type(classFile) ~= "string" or (ns.IsSecret and ns.IsSecret(classFile)) then return nil end
    return classFile:lower()
end

-- True when a class-only quest is not for your class.
local function OtherClass(q, myClass)
    if not (q.classes and myClass) then return false end
    for name in q.classes:gmatch("[^/]+") do
        if name:lower() == myClass then return false end
    end
    return true
end

-- The dungeon's quests your faction and class can take (all of them with
-- /bnav quest all; a filter is skipped when the client will not say your
-- faction or class).
local function VisibleQuests()
    local cfg = QuestDungeon()
    local faction = PlayerFaction()
    local myClass = PlayerClass()
    local list = {}
    for _, q in ipairs(DungeonQuests(cfg)) do
        local factionOk = not faction or q.faction == "B" or q.faction:sub(1, 1) == faction:sub(1, 1)
        if state.questAll or (factionOk and not OtherClass(q, myClass)) then
            list[#list + 1] = q
        end
    end
    return list, cfg
end

-- True when you can pick the quest up right now: your faction, your class,
-- your level reached, not done and not in your log. Ignores /bnav quest all.
-- A check the client will not answer (faction, class, level) is skipped.
local function CanTakeQuest(q)
    local faction = PlayerFaction()
    if faction and q.faction ~= "B" and q.faction:sub(1, 1) ~= faction:sub(1, 1) then return false end
    if OtherClass(q, PlayerClass()) then return false end
    local myLevel = PlayerLevel()
    if myLevel and q.level and q.level > myLevel then return false end
    return QuestStatus(q) == nil
end

-- Where a quest starts, in words.
local function StartText(q)
    local who = q.giver or "unknown"
    if q.start == "item" then
        who = "item " .. who .. (q.from and (", dropped by " .. q.from) or "")
    elseif q.start == "object" then
        who = who .. " (object)"
    end
    if q.inside then return who, "inside the dungeon" end
    if q.zone and q.x then
        return who, string.format("%s  %.1f, %.1f%s", q.zone, q.x, q.y, q.approx and " (about)" or "")
    end
    return who, q.zone or "place unknown"
end

-- Short "where to take it" for a sidebar row: the zone, or "inside".
local function PlaceTag(q)
    if q.inside then return "inside" end
    return q.zone or "place unknown"
end

local function TurninText(q)
    if not q.turnin then return nil end
    if q.tinside then return q.turnin .. ", inside the dungeon" end
    if q.tzone and q.tx then return string.format("%s, %s  %.1f, %.1f", q.turnin, q.tzone, q.tx, q.ty) end
    return q.turnin .. (q.tzone and (", " .. q.tzone) or "")
end

--------------------------------------------------------------------------
-- Picking a quest: select it and lead the arrow to its giver
--------------------------------------------------------------------------
-- A quest with a giver on the world map: the arrow, HUD and minimap pin lead
-- to the giver. A quest taken inside the dungeon (or with no known spot):
-- the arrow goes back to the dungeon entrance.
local function NavigateToQuest(q)
    if not q then return end
    if q.zone and q.x and q.y and not q.inside then
        if ns.SetQuestTarget then ns.SetQuestTarget(q, true) end
    elseif q.inside and ns.SetQuestInside then
        -- the dungeon entrance wears the quest icon while this quest is picked
        ns.SetQuestInside(SelectedDungeon())
        Print(q.name .. ": taken inside the dungeon"
            .. (SelectedDungeon() and (", navigating to " .. SelectedDungeon().name .. ".") or "."))
    elseif (state.questTarget or state.questInside) and ns.ClearQuestTarget then
        ns.ClearQuestTarget(true)
        Print(q.name .. ": giver place unknown"
            .. (SelectedDungeon() and (", navigating to " .. SelectedDungeon().name .. ".") or "."))
    end
end

-- Select the idx-th quest of the list (wrapping is the caller's job).
local function SelectQuest(idx)
    local list = VisibleQuests()
    local q = list[idx]
    if not q then return end
    state.questIdx = idx
    NavigateToQuest(q)
    -- the quest is the selection now, even when its giver place is unknown
    if state.selKind ~= "quest" then
        state.selKind = "quest"
        if ns.RefreshIfShown then ns.RefreshIfShown() end
    end
end

--------------------------------------------------------------------------
-- Sidebar rows
--------------------------------------------------------------------------
local questRows = {}
local function GetQuestRow(i)
    if not questRows[i] then
        local b = CreateFrame("Button", nil, sidebar)
        b:SetSize(SIDEBAR_W - 8, ROW_H)
        b:SetPoint("TOPLEFT", listAnchor, "TOPLEFT", 4, -(i - 1) * ROW_H)
        ns.AddRoundHover(b)   -- rounded mouse-over box
        -- "Show on the map" button at the right end of the row
        local m = CreateFrame("Button", nil, b)
        m:SetSize(18, 18)
        m:SetPoint("RIGHT", b, "RIGHT", -2, 0)
        m:SetFrameLevel(b:GetFrameLevel() + 2)
        m:SetNormalTexture("Interface\\Icons\\INV_Misc_Map_01")
        m:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        m:SetScript("OnClick", function()
            if b.questIdx and ns.ShowQuestOnWorldMap then
                ns.ShowQuestOnWorldMap(b.questIdx)
            end
        end)
        m:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Show on the map", 1, 0.82, 0)
            GameTooltip:Show()
        end)
        m:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        b.mapBtn = m
        -- layout like the dungeon list: ">" | quest text
        b.mark = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        -- pushed right so the ">" sits just in front of what it points at
        b.mark:SetPoint("LEFT", b, "LEFT", 6, 0)
        b.mark:SetWidth(MARK_W)
        b.mark:SetJustifyH("RIGHT")
        b.mark:SetWordWrap(false)
        SetFontSize(b.mark, NAME_FONT_SIZE)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("LEFT", b, "LEFT", MARK_W, 0)   -- 6 px left padding
        b.text:SetWidth(SIDEBAR_W - 8 - MARK_W - 24)
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        -- Line through a done / in-log quest (font strings cannot strike through)
        b.strike = b:CreateTexture(nil, "OVERLAY", nil, 7)
        b.strike:SetHeight(1.5)
        b.strike:SetPoint("LEFT", b.text, "LEFT", 0, 0)
        b.strike:Hide()
        b:SetScript("OnClick", function(self)
            if self.questIdx then
                SelectQuest(self.questIdx)
                BossNav_RefreshMap()
            end
        end)
        questRows[i] = b
    end
    return questRows[i]
end

--------------------------------------------------------------------------
-- Detail panel over the map
--------------------------------------------------------------------------
local panel = CreateFrame("Frame", nil, canvas)
panel:SetAllPoints()
panel:SetFrameLevel(canvas:GetFrameLevel() + 6)   -- above the map tiles and pins
local panelBg = panel:CreateTexture(nil, "BACKGROUND")
panelBg:SetAllPoints()
panelBg:SetColorTexture(0.03, 0.03, 0.04, 1)
panel:Hide()

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -14)
title:SetWidth(CANVAS_W - 32)
title:SetJustifyH("LEFT")

local body = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
body:SetWidth(CANVAS_W - 32)
body:SetJustifyH("LEFT")
body:SetJustifyV("TOP")
body:SetSpacing(4)

local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
empty:SetPoint("CENTER")
empty:SetWidth(CANVAS_W - 60)
empty:SetJustifyH("CENTER")

-- Colours that read on the quest window's parchment.
local LABEL = "|cff3d2b12%s|r  "
local INK = { A = "0a2a75", H = "7a0d0d", B = "4a3300" }
local function DarkLevelColor(q, myLevel)
    local r, g, b = QuestLevelRGB(q, myLevel)
    if not r then return "|cff000000" end
    return string.format("|cff%02x%02x%02x", r * 85, g * 85, b * 85)
end

-- The selected quest, drawn like the game's quest window
-- (BossNav_QuestInfo.lua) with where to take it under the title.
local function ShowQuest(q, myLevel)
    local lvl = DarkLevelColor(q, myLevel) .. q.level .. "|r"
        .. ((q.qlevel and q.qlevel ~= q.level) and ("  |cff3d2b12(quest level " .. q.qlevel .. ")|r") or "")
    local lines = {}
    lines[#lines + 1] = LABEL:format("Level") .. lvl .. "   " .. LABEL:format("For")
        .. FactionIcons(q, 14) .. " |cff" .. INK[q.faction] .. FACTION_WORD[q.faction] .. "|r"
        .. (q.classes and ("   " .. LABEL:format("Class") .. q.classes) or "")
    local status = QuestStatus(q)
    if status == "done" then
        lines[#lines + 1] = LABEL:format("Status") .. "Done - you already handed it in"
    elseif status == "active" then
        lines[#lines + 1] = LABEL:format("Status") .. "In your quest log"
    end
    local who, where = StartText(q)
    lines[#lines + 1] = LABEL:format("Take it from") .. who .. "  |cff033a03" .. where .. "|r"
    local back = TurninText(q)
    if back then lines[#lines + 1] = LABEL:format("Hand it in to") .. back end
    if q.pre then lines[#lines + 1] = LABEL:format("Do first") .. q.pre end
    if q.note then lines[#lines + 1] = LABEL:format("Tip") .. q.note end
    title:Hide(); body:Hide(); empty:Hide()
    ns.ShowQuestInfo(q, q.name, lines)
end

--------------------------------------------------------------------------
-- Render (called by BossNav_RefreshMap; returns true when the Quests tab is shown)
--------------------------------------------------------------------------
local function HideRows(from)
    for i = from, #questRows do questRows[i]:Hide() end
end

local function RenderQuestTab()
    if state.tab ~= "quest" then
        panel:Hide()
        ns.HideQuestInfo()
        HideRows(1)
        return false
    end

    local list, cfg = VisibleQuests()
    local count = #list
    state.questIdx = math.max(1, math.min(state.questIdx or 1, math.max(count, 1)))
    local faction = PlayerFaction()
    headerText:SetText("|cffffd100Quests|r  |cff888888" .. (cfg and cfg.name or "no dungeon picked") .. "|r")
    local myClass = PlayerClass()
    local forWhom = (faction or "you") .. (myClass and (" " .. myClass:sub(1, 1):upper() .. myClass:sub(2)) or "")
    statusText:SetText(cfg and string.format("%d quest%s for %s", count, count == 1 and "" or "s",
        state.questAll and "every faction and class" or forWhom) or "")
    navText:SetText("")
    panel:Show()

    -- Sidebar: keep the selected quest in view (20 rows fit)
    local first = math.max(1, state.questIdx - MAX_ROWS + 1)
    local myLevel = PlayerLevel()
    local shown = 0
    for i = first, math.min(count, first + MAX_ROWS - 1) do
        local q = list[i]
        shown = shown + 1
        local r = GetQuestRow(shown)
        r.questIdx = i
        -- selected like a dungeon row: the gold band, colours unchanged
        -- only while a quest (not the dungeon) is the selection
        local questSel = ns.QuestSelected and ns.QuestSelected()
        ns.SetRowActive(r, questSel and i == state.questIdx)
        -- level and name coloured like the dungeon list: red / grey / green;
        -- a done or in-log quest is crossed out and tagged instead of the place
        local status = QuestStatus(q)
        -- the map button only when the giver has a spot on the world map
        -- and the quest is still to be picked up (not done, not in the log)
        if q.zone and q.x and not q.inside and not status then r.mapBtn:Show() else r.mapBtn:Hide() end
        local lvlColor = QuestLevelColor(q, myLevel) or "|cff888888"
        local nameColor = QuestLevelColor(q, myLevel) or "|cffffffff"
        local main = string.format("%s %s[%d]|r %s%s|r", FactionIcons(q, 14), lvlColor, q.level, nameColor, q.name)
        local tag = status and QUEST_STATUS_WORD[status] or PlaceTag(q)
        r.text:SetText(main)
        local strikeW = math.min(r.text:GetStringWidth() or 0, r.text:GetWidth())
        r.text:SetText(main .. " |cff666666(" .. tag .. ")|r")
        if status and strikeW > 0 then
            r.strike:SetWidth(strikeW)
            if status == "done" then r.strike:SetColorTexture(0.85, 0.85, 0.85, 0.9)
            else r.strike:SetColorTexture(1.0, 0.82, 0.0, 0.9) end
            r.strike:Show()
        else
            r.strike:Hide()
        end
        r:Show()
    end
    HideRows(shown + 1)

    if not cfg or count == 0 then ns.HideQuestInfo() end
    if not cfg then
        title:Hide(); body:Hide()
        empty:SetText("Pick a dungeon first: /bnav go name, or the Dungeons tab.\nThe quests of that dungeon show up here.")
        empty:Show()
    elseif count == 0 then
        title:Hide(); body:Hide()
        empty:SetText("No known quests for " .. cfg.name .. (state.questAll and "." or " for your faction and class.\n/bnav quest all shows every quest."))
        empty:Show()
    else
        ShowQuest(list[state.questIdx], myLevel)
    end
    -- the world map highlights the selected quest's giver
    if ns.RefreshWorldMapPins then pcall(ns.RefreshWorldMapPins) end
    return true
end

--------------------------------------------------------------------------
-- /bnav quest [n | next | prev | all | list]
--------------------------------------------------------------------------
local function CycleQuest(step)
    local count = #VisibleQuests()
    if count == 0 then return end
    SelectQuest((((state.questIdx or 1) + step - 1) % count) + 1)
    BossNav_RefreshMap()
end

local function PrintQuests()
    local list, cfg = VisibleQuests()
    if not cfg then Print("Pick a dungeon first (/bnav go name).") return end
    if #list == 0 then Print("No known quests for " .. cfg.name .. ".") return end
    Print(cfg.name .. " quests:")
    for i, q in ipairs(list) do
        local who, where = StartText(q)
        Print(string.format("  %d. [%d] %s - %s, %s", i, q.level, q.name, who, where))
    end
end

local function QuestCommand(rest)
    local arg = (rest or ""):lower()
    local n = tonumber(arg)
    if arg == "list" then PrintQuests() return end
    -- /bnav quest down|up|top: scroll the quest text and rewards
    local scrollStep = ({ down = 1, up = -1, top = 0 })[arg]
    if scrollStep then
        if state.tab ~= "quest" then ns.SetTab("quest") end
        ns.ScrollQuestInfo(scrollStep)
        return
    end
    -- /bnav quest show [n]: the selected (or n-th) quest's giver on the world map
    local showArg = arg:match("^show%s*(%d*)$")
    if showArg then
        ns.ShowQuestOnWorldMap(tonumber(showArg) or state.questIdx or 1)
        return
    end
    if arg == "map" then
        local db = ns.DB()
        db.questmap = not db.questmap
        Print("Quest givers on the world map " .. (db.questmap and "on" or "off") .. ".")
        if ns.RefreshWorldMapPins then pcall(ns.RefreshWorldMapPins) end
        return
    end
    if arg == "all" then
        state.questAll = not state.questAll
        Print(state.questAll and "Quests show for every faction and class." or "Quests show for your faction and class only.")
    elseif n then
        SelectQuest(n)
    elseif arg == "next" then
        SelectQuest(math.min(#VisibleQuests(), (state.questIdx or 1) + 1))
    elseif arg == "prev" then
        SelectQuest(math.max(1, (state.questIdx or 1) - 1))
    end
    ns.SetTab("quest")
end

-- /bnav quest ...
ns.AddCommand({ "quest", "quests", "q" }, function(rest)
    if not ns.mapFrame:IsShown() then ns.mapFrame:Show() end
    QuestCommand(rest)
end, {
    "  /bnav quest [n]       Quests tab: the quests of this dungeon (outside: the one picked with /bnav go), who gives them and where",
    "  /bnav quest next|prev pick the next / previous quest (the Select Next / Previous Boss keys do it too on that tab)",
    "  /bnav quest all       show every faction's and class's quests, or only yours again",
    "  /bnav quest list      print the quest list and giver places to your chat",
    "  /bnav quest down|up|top  scroll the quest text and rewards (also keybinds)",
    "  /bnav quest show [n]  navigate to the selected (or n-th) quest's giver and show it zoomed in on the world map",
    "  /bnav quest map       toggle the quest givers of the selected dungeon on the game's world map",
})

-- shared with the other BossNav files
ns.CycleQuest = CycleQuest
ns.SelectQuest = SelectQuest
ns.RenderQuestTab = RenderQuestTab
ns.VisibleQuests = VisibleQuests
ns.CanTakeQuest = CanTakeQuest
