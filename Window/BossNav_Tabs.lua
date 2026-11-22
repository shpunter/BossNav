-- The tabs at the top of the sidebar, the column headers of the Dungeons
-- section, and switching between them. What each one draws lives in its own
-- file.
--
--   +----------+--------+------+-------+ [key]
--   | Dungeons | Quests | Loot | Profs |          sections: real tabs, the open
--   +----------+--------+------+-------+          one joined to the panel below
--
-- Dungeons shows three columns side by side, each with a header:
--
--   Dungeons          | Bosses  3/8 killed | Items  Kresh   [all] [key]
--   ===========                                                   focus: gold,
--   > Wailing Caverns | > Kresh            | > [#] Kresh's Back      underlined
--
-- The focused column decides what the Next / Previous keys walk and what the
-- map area shows (zone map, dungeon map or item card). Inside a dungeon the
-- dungeon list cannot take the focus (it shows where you are).
-- Quests shows the quests of the dungeon picked in Dungeons (context line).
-- Loot and Profs have no context, so their lists start right under the tabs.
--
-- state.tab is "travel", "boss" or "item" (the Dungeons section, by focused
-- column), or "quest", "loot", "prof". Inside a dungeon "travel" counts as "boss".
-- Two keys: Switch Section (Dungeons / Quests / Loot / Profs) and Switch View
-- (the focus: Dungeons / Bosses / Items columns).
local ADDON, ns = ...
-- from the files loaded before this one
local PaintTab               = ns.PaintTab
local SIDEBAR_W              = ns.SIDEBAR_W
local SavedKilled            = ns.SavedKilled
local StyleTab               = ns.StyleTab
local TAB_EDGE               = ns.TAB_EDGE
local SetListTop             = ns.SetListTop
local SetWide                = ns.SetWide
local bossCol                = ns.bossCol
local itemCol                = ns.itemCol
local mapFrame               = ns.mapFrame
local sidebar                = ns.sidebar
local state                  = ns.state

local GAP = 4
local TOP_Y, TOP_H = -2, 22             -- section tabs
local HEAD_Y, HEAD_H = -28, 18          -- column headers / context line
local LIST_TOP_COLUMNS = -50            -- Dungeons lists under the headers
local LIST_TOP_CONTEXT = -46            -- Quests list under the context line
local LIST_TOP_FLAT = TOP_Y - TOP_H - 4 -- Loot / Profs lists right under the tabs
local HINT_W = 46                       -- room for "[S-F6]" at a row's right end

local GOLD = { 1, 0.82, 0 }

local SECTIONS = { "dungeon", "quest", "loot", "prof" }
local SECTION_LABEL = { dungeon = "Dungeons", quest = "Quests", loot = "Loot", prof = "Profs" }
local COLUMNS = { "travel", "boss", "item" }
local SECTION_OF = { travel = "dungeon", boss = "dungeon", item = "dungeon", quest = "quest", loot = "loot", prof = "prof" }
local lastColumn = "travel"   -- the Dungeons section reopens on the column focused last

local function Outside()
    return ns.TravelMode and ns.TravelMode()
end

-- The column actually focused: the dungeon list has no focus inside a dungeon.
local function ShownTab()
    if state.tab == "travel" and not Outside() then return "boss" end
    return state.tab
end

local function IsTab(key)
    return SECTION_OF[key] ~= nil
end

local function InDungeonsSection()
    return SECTION_OF[state.tab] == "dungeon"
end

local function SetTab(key)
    if not IsTab(key) then key = "boss" end
    state.tab = key
    if SECTION_OF[key] == "dungeon" then lastColumn = key end
    if not mapFrame:IsShown() then mapFrame:Show() end
    BossNav_RefreshMap()
end

local function OpenSection(section)
    SetTab(section == "dungeon" and lastColumn or section)
end

-- Switch Section key: Dungeons -> Quests -> Loot -> Profs -> Dungeons
local function NextSection()
    local cur = SECTION_OF[ShownTab()] or "dungeon"
    local pos = 1
    for i, s in ipairs(SECTIONS) do
        if s == cur then pos = i end
    end
    OpenSection(SECTIONS[(pos % #SECTIONS) + 1])
end

-- Switch View key: focus Dungeons -> Bosses -> Items -> Dungeons (no
-- Dungeons column focus inside). From another section it opens Dungeons.
local function NextView()
    local cur = ShownTab()
    if SECTION_OF[cur] ~= "dungeon" then OpenSection("dungeon") return end
    local pos = 1
    for i, c in ipairs(COLUMNS) do
        if c == cur then pos = i end
    end
    local nextKey = COLUMNS[(pos % #COLUMNS) + 1]
    if nextKey == "travel" and not Outside() then nextKey = "boss" end
    SetTab(nextKey)
end

-- The bound key of a binding, shortened to fit ("SHIFT-F6" -> "S-F6"), or nil.
local function KeyHint(binding)
    local key = GetBindingKey and GetBindingKey(binding)
    if not key or key == "" then return nil end
    key = key:gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-"):gsub("NUMPAD", "N")
    return "[" .. key .. "]"
end

--------------------------------------------------------------------------
-- Section tabs
--------------------------------------------------------------------------
-- The line the section tabs sit on; the open tab covers its piece of it.
local edge = sidebar:CreateTexture(nil, "ARTWORK")
edge:SetHeight(1)
edge:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, TOP_Y - TOP_H)
edge:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, TOP_Y - TOP_H)
edge:SetColorTexture(unpack(TAB_EDGE))

local sectionTabs = {}
for _, key in ipairs(SECTIONS) do
    local b = CreateFrame("Button", nil, sidebar)
    b:SetHeight(TOP_H)
    b:SetFrameLevel(sidebar:GetFrameLevel() + 2)   -- over the edge line
    StyleTab(b)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("CENTER", 0, -1)
    b.text:SetText(SECTION_LABEL[key])
    b:SetScript("OnClick", function() OpenSection(key) end)
    sectionTabs[key] = b
end

local sectionHint = sidebar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
sectionHint:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -4, TOP_Y - 6)
sectionHint:SetJustifyH("RIGHT")

local function LayOutSections(hint)
    local width = SIDEBAR_W - (hint and HINT_W or 0)
    local w = (width - GAP * (#SECTIONS + 1)) / #SECTIONS
    for i, key in ipairs(SECTIONS) do
        local b = sectionTabs[key]
        b:SetWidth(w)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", sidebar, "TOPLEFT", GAP + (i - 1) * (w + GAP), TOP_Y)
    end
    sectionHint:SetText(hint or "")
end

local function PaintSection(b, open)
    PaintTab(b, open, TOP_H)
    if open then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(0.6, 0.6, 0.6) end
end

--------------------------------------------------------------------------
-- Column headers (Dungeons section): click one to focus that column
--------------------------------------------------------------------------
local headers = {}
-- rightPad: room kept free at the right end (the Items header's buttons)
local function NewHeader(key, col, rightPad)
    local b = CreateFrame("Button", nil, col)
    b:SetHeight(HEAD_H)
    b:SetPoint("TOPLEFT", col, "TOPLEFT", 8, HEAD_Y)
    b:SetPoint("TOPRIGHT", col, "TOPRIGHT", -8, HEAD_Y)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 0.82, 0, 0.08)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("LEFT", b, "LEFT", 2, 1)
    b.text:SetPoint("RIGHT", b, "RIGHT", -(rightPad or 0), 1)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b.line = b:CreateTexture(nil, "ARTWORK")       -- underline of the focused column
    b.line:SetHeight(2)
    b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, -2)
    b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, -2)
    b.line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    b:SetScript("OnClick", function() SetTab(key) end)
    headers[key] = b
    return b
end
NewHeader("travel", sidebar)
NewHeader("boss", bossCol)
local itemHeader = NewHeader("item", itemCol, 64 + HINT_W)

-- Switch View key hint at the right end of the last header
local viewHint = itemCol:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
viewHint:SetPoint("TOPRIGHT", itemCol, "TOPRIGHT", -6, HEAD_Y - 4)
viewHint:SetJustifyH("RIGHT")

-- "show all" button in the Items header while a boss or Trash filter is on:
-- drops the filter, back to all the dungeon's loot (bosses and trash)
local allBtn = CreateFrame("Button", nil, itemHeader)
allBtn:SetSize(64, HEAD_H)
allBtn:SetFrameLevel(itemHeader:GetFrameLevel() + 2)
allBtn.text = allBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
allBtn.text:SetPoint("CENTER")
allBtn.text:SetText("[show all]")
allBtn:SetScript("OnClick", function()
    if ns.ClearItemBoss then ns.ClearItemBoss() end
    BossNav_RefreshMap()
end)

-- the wing you are in, when inside a split dungeon (Scarlet Monastery...)
local function InsidePart(cfg)
    if Outside() or cfg ~= state.cfg or not ns.CurrentPart then return nil end
    return ns.CurrentPart(cfg)
end

local function KillText(cfg, killed)
    local part = InsidePart(cfg)
    local list = part and part.bosses or cfg.bosses
    local n = 0
    for _, b in ipairs(list) do
        if killed[b[1]] then n = n + 1 end
    end
    return string.format("|cff888888%d/%d killed|r", n, #list)
end

-- The dungeon the columns are about and its kills, or nil.
local function ColumnsDungeon()
    if not Outside() then return state.cfg, state.killed end
    local e = ns.SelectedDungeon and ns.SelectedDungeon()
    if not (e and e.cfg) then return nil end
    return e.cfg, SavedKilled(e.cfg)
end

local function HeaderTexts()
    local cfg, killed = ColumnsDungeon()
    local bossText = "Bosses" .. (cfg and ("  " .. KillText(cfg, killed or {})) or "")
    local boss = ns.ItemBoss and ns.ItemBoss()
    local filtered = ns.FiltersActive and ns.FiltersActive()
    local itemText = "Items  |cff888888" .. (boss or (cfg and "all loot" or "every dungeon"))
        .. (filtered and ", filtered" or "") .. "|r"
    return {
        travel = Outside() and "Dungeons" or "Dungeons  |cff888888(you are inside)|r",
        boss = bossText,
        item = itemText,
    }, boss
end

local function PaintHeaders(shown, hint)
    local texts, boss = HeaderTexts()
    for key, b in pairs(headers) do
        local focused = (key == shown)
        local enabled = key ~= "travel" or Outside()
        b:SetEnabled(enabled)
        b.line:SetShown(focused)
        b.text:SetText(texts[key])
        if focused then
            b.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        elseif enabled then
            b.text:SetTextColor(0.75, 0.75, 0.75)
        else
            b.text:SetTextColor(0.4, 0.4, 0.4)
        end
    end
    viewHint:SetText(hint or "")
    allBtn:ClearAllPoints()
    allBtn:SetPoint("RIGHT", itemHeader, "RIGHT", hint and -(HINT_W - 8) or 0, 0)
    allBtn:SetShown(boss ~= nil)
end

--------------------------------------------------------------------------
-- Context line (Quests section): the dungeon the quests are about
--------------------------------------------------------------------------
local context = sidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
context:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 10, HEAD_Y - 2)
context:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -8, HEAD_Y - 2)
context:SetJustifyH("LEFT")
context:SetWordWrap(false)

local function ContextText()
    if not Outside() then
        local cfg = state.cfg
        if not cfg then return "|cff888888No boss data for this zone|r" end
        local part = InsidePart(cfg)
        return string.format("|cffffd100%s|r  -  %s", part and part.name or cfg.name, KillText(cfg, state.killed))
    end
    local e = ns.SelectedDungeon and ns.SelectedDungeon()
    if not e then
        return "|cff888888No dungeon picked: choose one in Dungeons|r"
    end
    local tail = e.cfg and ("  -  " .. KillText(e.cfg, SavedKilled(e.cfg))) or ""
    return string.format("|cffffd100%s|r |cff888888(outside)|r%s", e.name, tail)
end

--------------------------------------------------------------------------
-- Redraw (called at the start of every window redraw)
--------------------------------------------------------------------------
local function UpdateTabLook()
    local shown = ShownTab()
    local section = SECTION_OF[shown] or "dungeon"

    LayOutSections(KeyHint("BOSSNAV_TOGGLE_TAB"))
    for key, b in pairs(sectionTabs) do PaintSection(b, key == section) end

    local columns = (section == "dungeon")
    SetWide(columns)
    for _, b in pairs(headers) do b:SetShown(columns) end
    if columns then PaintHeaders(shown, KeyHint("BOSSNAV_NEXT_VIEW")) end

    context:SetShown(section == "quest")
    if section == "quest" then context:SetText(ContextText()) end

    SetListTop(columns and LIST_TOP_COLUMNS or (section == "quest" and LIST_TOP_CONTEXT or LIST_TOP_FLAT))
end

-- shared with the other BossNav files
ns.InDungeonsSection = InDungeonsSection
ns.NextTab = NextSection
ns.NextView = NextView
ns.SetTab = SetTab
ns.UpdateTabLook = UpdateTabLook
