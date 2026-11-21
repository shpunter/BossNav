-- The tabs at the top of the sidebar and switching between them. What each
-- tab draws lives in its own file.
--
--   +----------+------+-------+ [key]   sections: real tabs, the open one is
--   | Dungeons | Loot | Profs |         joined to the panel below
--     Travel   Bosses   Quests   [key]   views of Dungeons: plain text, the open
--     ======                             one gold and underlined; Travel greyed
--   Wailing Caverns - 3/5 killed         out inside a dungeon
--                                        context: which dungeon the views are about
-- Loot and Profs have no views, so their lists start right under the tabs.
--
-- state.tab is always a view: "travel", "boss", "quest", "loot" or "prof".
-- Inside a dungeon "travel" draws (and lights up) as "boss".
-- Two keys: Switch Section (Dungeons / Loot / Profs) and Switch View
-- (Travel / Bosses / Quests).
local ADDON, ns = ...
-- from the files loaded before this one
local SIDEBAR_W              = ns.SIDEBAR_W
local SavedKilled            = ns.SavedKilled
local SetListTop             = ns.SetListTop
local mapFrame               = ns.mapFrame
local sidebar                = ns.sidebar
local state                  = ns.state

local GAP = 4
local TOP_Y, TOP_H = -2, 22             -- section tabs
local SUB_Y, SUB_H = -28, 18            -- view tabs
local CONTEXT_Y = -48                   -- context line
local LIST_TOP_VIEWS = -64              -- lists under all three rows
local LIST_TOP_FLAT = TOP_Y - TOP_H - 4 -- lists right under the section tabs
local HINT_W = 46                       -- room for "[S-F6]" at a row's right end

local GOLD = { 1, 0.82, 0 }
local EDGE = { 0.75, 0.62, 0.20, 1 }    -- the gold line the tabs sit on
local PANEL = { 0.06, 0.06, 0.08, 1 }   -- the sidebar background (BossNav_Window.lua)
local IDLE = { 0.13, 0.13, 0.16, 1 }    -- a closed section tab

local SECTIONS = { "dungeon", "loot", "prof" }
local SECTION_LABEL = { dungeon = "Dungeons", loot = "Loot", prof = "Profs" }
local VIEWS = { "travel", "boss", "quest" }
local VIEW_LABEL = { travel = "Travel", boss = "Bosses", quest = "Quests" }
local SECTION_OF = { travel = "dungeon", boss = "dungeon", quest = "dungeon", loot = "loot", prof = "prof" }
local lastView = "travel"   -- the Dungeons section reopens on the view open last

local function Outside()
    return ns.TravelMode and ns.TravelMode()
end

-- The view actually drawn: there is no Travel view inside a dungeon.
local function ShownTab()
    if state.tab == "travel" and not Outside() then return "boss" end
    return state.tab
end

local function IsTab(key)
    return SECTION_OF[key] ~= nil
end

local function SetTab(key)
    if not IsTab(key) then key = "boss" end
    state.tab = key
    if SECTION_OF[key] == "dungeon" then lastView = key end
    if not mapFrame:IsShown() then mapFrame:Show() end
    BossNav_RefreshMap()
end

local function OpenSection(section)
    SetTab(section == "dungeon" and lastView or section)
end

-- Switch Section key: Dungeons -> Loot -> Profs -> Dungeons
local function NextSection()
    local cur = SECTION_OF[ShownTab()] or "dungeon"
    local pos = 1
    for i, s in ipairs(SECTIONS) do
        if s == cur then pos = i end
    end
    OpenSection(SECTIONS[(pos % #SECTIONS) + 1])
end

-- Switch View key: Travel -> Bosses -> Quests -> Travel (no Travel inside).
-- From Loot or Profs it goes back to Dungeons first.
local function NextView()
    local cur = ShownTab()
    if SECTION_OF[cur] ~= "dungeon" then OpenSection("dungeon") return end
    local pos = 1
    for i, v in ipairs(VIEWS) do
        if v == cur then pos = i end
    end
    local nextKey = VIEWS[(pos % #VIEWS) + 1]
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
edge:SetColorTexture(unpack(EDGE))

local sectionTabs = {}
for _, key in ipairs(SECTIONS) do
    local b = CreateFrame("Button", nil, sidebar)
    b:SetHeight(TOP_H)
    b:SetFrameLevel(sidebar:GetFrameLevel() + 2)   -- over the edge line
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.top = b:CreateTexture(nil, "BORDER")         -- gold edge on top of the open tab
    b.top:SetHeight(2)
    b.top:SetPoint("TOPLEFT")
    b.top:SetPoint("TOPRIGHT")
    b.top:SetColorTexture(unpack(EDGE))
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 0.82, 0, 0.12)
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
    if open then
        -- the panel's colour and one pixel taller, so it covers the edge
        -- line and runs into the panel below
        b.bg:SetColorTexture(unpack(PANEL))
        b:SetHeight(TOP_H + 1)
        b.top:Show()
        b.text:SetTextColor(1, 1, 1)
    else
        b.bg:SetColorTexture(unpack(IDLE))
        b:SetHeight(TOP_H)
        b.top:Hide()
        b.text:SetTextColor(0.6, 0.6, 0.6)
    end
end

--------------------------------------------------------------------------
-- View tabs (Dungeons only)
--------------------------------------------------------------------------
local viewTabs = {}
for _, key in ipairs(VIEWS) do
    local b = CreateFrame("Button", nil, sidebar)
    b:SetHeight(SUB_H)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 0.82, 0, 0.08)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("CENTER", 0, 1)
    b.text:SetText(VIEW_LABEL[key])
    b.line = b:CreateTexture(nil, "ARTWORK")       -- underline of the open view
    b.line:SetHeight(2)
    b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 12, 0)
    b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -12, 0)
    b.line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    b:SetScript("OnClick", function() SetTab(key) end)
    viewTabs[key] = b
end

local viewHint = sidebar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
viewHint:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -4, SUB_Y - 4)
viewHint:SetJustifyH("RIGHT")

local function LayOutViews(hint)
    local left = 8
    local width = SIDEBAR_W - left - (hint and HINT_W or 8)
    local w = width / #VIEWS
    for i, key in ipairs(VIEWS) do
        local b = viewTabs[key]
        b:SetWidth(w)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", sidebar, "TOPLEFT", left + (i - 1) * w, SUB_Y)
    end
    viewHint:SetText(hint or "")
end

local function PaintView(b, open, enabled)
    b:SetEnabled(enabled)
    b.line:SetShown(open)
    if open then
        b.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    elseif enabled then
        b.text:SetTextColor(0.7, 0.7, 0.7)
    else
        b.text:SetTextColor(0.3, 0.3, 0.3)
    end
end

--------------------------------------------------------------------------
-- Context line: the dungeon the views are about
--------------------------------------------------------------------------
local context = sidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
context:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 10, CONTEXT_Y)
context:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -8, CONTEXT_Y)
context:SetJustifyH("LEFT")
context:SetWordWrap(false)

local function KillText(cfg, killed)
    local n = 0
    for _, b in ipairs(cfg.bosses) do
        if killed[b[1]] then n = n + 1 end
    end
    return string.format("|cff888888%d/%d killed|r", n, #cfg.bosses)
end

local function ContextText(view)
    if not Outside() then
        local cfg = state.cfg
        if not cfg then return "|cff888888No boss data for this zone|r" end
        return string.format("|cffffd100%s|r  -  %s", cfg.name, KillText(cfg, state.killed))
    end
    local e = ns.SelectedDungeon and ns.SelectedDungeon()
    if not e then
        return "|cff888888No dungeon picked: choose one on Travel|r"
    end
    if view == "travel" then
        return string.format("Heading to |cffffd100%s|r  |cff888888%s|r", e.name, e.levels or "")
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
    local outside = Outside()

    LayOutSections(KeyHint("BOSSNAV_TOGGLE_TAB"))
    for key, b in pairs(sectionTabs) do PaintSection(b, key == section) end

    local views = (section == "dungeon")
    LayOutViews(KeyHint("BOSSNAV_NEXT_VIEW"))
    for key, b in pairs(viewTabs) do
        b:SetShown(views)
        PaintView(b, key == shown, key ~= "travel" or outside)
    end
    viewHint:SetShown(views)
    context:SetShown(views)
    if views then context:SetText(ContextText(shown)) end

    SetListTop(views and LIST_TOP_VIEWS or LIST_TOP_FLAT)
end

-- shared with the other BossNav files
ns.IsTab = IsTab
ns.NextSection = NextSection
ns.NextTab = NextSection
ns.NextView = NextView
ns.SetTab = SetTab
ns.UpdateTabLook = UpdateTabLook
