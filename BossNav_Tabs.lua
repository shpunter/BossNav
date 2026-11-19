-- The tab buttons at the top of the sidebar, in two rows, and switching
-- between the tabs. What each tab draws lives in its own file.
--   top row:    Dungeons | Loot | Profs
--   second row: Travel | Bosses | Quests   (only under Dungeons; Travel only
--               outside, where it holds the dungeon selector)
-- state.tab is always a leaf: "travel", "boss", "quest", "loot" or "prof".
-- Inside a dungeon "travel" draws (and lights up) as "boss".
local ADDON, ns = ...
-- from the files loaded before this one
local SIDEBAR_W              = ns.SIDEBAR_W
local mapFrame               = ns.mapFrame
local sidebar                = ns.sidebar
local state                  = ns.state

local TAB_H = 20
local GAP = 4
-- Travel -> Bosses -> Quests -> Loot -> Profs -> Travel (keybind and /bnav tab)
local TAB_ORDER = { "travel", "boss", "quest", "loot", "prof" }
local TAB_LABEL = { travel = "Travel", boss = "Bosses", quest = "Quests", loot = "Loot", prof = "Profs" }

-- Top row. Each entry names the leaf tab a click opens; "dungeon" holds the
-- Travel, Bosses and Quests tabs and reopens whichever was open last.
local TOP_ORDER = { "dungeon", "loot", "prof" }
local TOP_LABEL = { dungeon = "Dungeons", loot = "Loot", prof = "Profs" }
local SUB_ORDER = { "travel", "boss", "quest" }
local PARENT = { travel = "dungeon", boss = "dungeon", quest = "dungeon", loot = "loot", prof = "prof" }
local lastDungeonTab = "travel"

local topTabs, subTabs = {}, {}

local function Outside()
    return ns.TravelMode and ns.TravelMode()
end

-- The tab actually drawn: no Travel tab inside a dungeon.
local function ShownTab()
    if state.tab == "travel" and not Outside() then return "boss" end
    return state.tab
end

local function IsTab(key)
    return TAB_LABEL[key] ~= nil
end

local function SetTab(key)
    if not IsTab(key) then key = "boss" end
    state.tab = key
    if PARENT[key] == "dungeon" then lastDungeonTab = key end
    if not mapFrame:IsShown() then mapFrame:Show() end
    BossNav_RefreshMap()
end

local function NextTab()
    local pos = 1
    for i, key in ipairs(TAB_ORDER) do
        if key == ShownTab() then pos = i end
    end
    local nextKey = TAB_ORDER[(pos % #TAB_ORDER) + 1]
    if nextKey == "travel" and not Outside() then nextKey = "boss" end
    SetTab(nextKey)
end

local function MakeButton(w, x, y, label, onClick)
    local b = CreateFrame("Button", nil, sidebar)
    b:SetSize(w, TAB_H)
    b:SetPoint("TOPLEFT", sidebar, "TOPLEFT", x, y)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 0.82, 0, 0.15)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local topW = (SIDEBAR_W - GAP * (#TOP_ORDER + 1)) / #TOP_ORDER
for i, key in ipairs(TOP_ORDER) do
    topTabs[key] = MakeButton(topW, GAP + (i - 1) * (topW + GAP), -2, TOP_LABEL[key], function()
        SetTab(key == "dungeon" and lastDungeonTab or key)
    end)
end

-- The second row sits under the top row and spans the sidebar. Its buttons
-- are laid out on every redraw, since Travel comes and goes.
for _, key in ipairs(SUB_ORDER) do
    subTabs[key] = MakeButton(10, 0, 0, TAB_LABEL[key], function() SetTab(key) end)
end

local function LayOutSubTabs(keys)
    local w = (SIDEBAR_W - GAP * (#keys + 1)) / #keys
    for i, key in ipairs(keys) do
        local b = subTabs[key]
        b:SetWidth(w)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", sidebar, "TOPLEFT", GAP + (i - 1) * (w + GAP), -2 - TAB_H - 2)
    end
end

local function Paint(b, active, dim)
    if active then
        b.bg:SetColorTexture(0.35, 0.28, 0.10, 1)
        b.text:SetTextColor(1, 1, 1)
    else
        b.bg:SetColorTexture(dim and 0.09 or 0.12, dim and 0.09 or 0.12, dim and 0.11 or 0.15, 1)
        b.text:SetTextColor(0.6, 0.6, 0.6)
    end
end

-- Light up the active tabs (called on every redraw of the window)
local function UpdateTabLook()
    local shown = ShownTab()
    local parent = PARENT[shown] or "dungeon"
    for key, b in pairs(topTabs) do Paint(b, key == parent) end
    local outside = Outside()
    local keys = {}
    for _, key in ipairs(SUB_ORDER) do
        if key ~= "travel" or outside then keys[#keys + 1] = key end
    end
    LayOutSubTabs(keys)
    for key, b in pairs(subTabs) do
        b:SetShown(parent == "dungeon" and (key ~= "travel" or outside))
        Paint(b, key == shown, true)
    end
end

-- shared with the other BossNav files
ns.IsTab = IsTab
ns.NextTab = NextTab
ns.SetTab = SetTab
ns.UpdateTabLook = UpdateTabLook
