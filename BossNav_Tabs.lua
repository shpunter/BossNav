-- The "Bosses" / "Loot" / "Profs" tab buttons at the top of the sidebar, and
-- switching between the tabs. What each tab draws lives in its own file.
local ADDON, ns = ...
-- from the files loaded before this one
local SIDEBAR_W              = ns.SIDEBAR_W
local mapFrame               = ns.mapFrame
local sidebar                = ns.sidebar
local state                  = ns.state

local TAB_H = 20
local TAB_ORDER = { "boss", "loot", "prof" }
local TAB_LABEL = { boss = "Bosses", loot = "Loot", prof = "Profs" }
local tabs = {}

local function IsTab(key)
    return TAB_LABEL[key] ~= nil
end

local function SetTab(key)
    if not IsTab(key) then key = "boss" end
    state.tab = key
    if not mapFrame:IsShown() then mapFrame:Show() end
    BossNav_RefreshMap()
end

-- Bosses -> Loot -> Profs -> Bosses (keybind and /bnav tab)
local function NextTab()
    local pos = 1
    for i, key in ipairs(TAB_ORDER) do
        if key == state.tab then pos = i end
    end
    SetTab(TAB_ORDER[(pos % #TAB_ORDER) + 1])
end

local tabW = (SIDEBAR_W - 4 * (#TAB_ORDER + 1)) / #TAB_ORDER
for i, key in ipairs(TAB_ORDER) do
    local b = CreateFrame("Button", nil, sidebar)
    b:SetSize(tabW, TAB_H)
    b:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 4 + (i - 1) * (tabW + 4), -2)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 0.82, 0, 0.15)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("CENTER")
    b.text:SetText(TAB_LABEL[key])
    b:SetScript("OnClick", function() SetTab(key) end)
    tabs[key] = b
end

-- Light up the active tab (called on every redraw of the window)
local function UpdateTabLook()
    -- Outside every dungeon the first tab holds the dungeon selector.
    local outside = ns.TravelMode and ns.TravelMode()
    tabs.boss.text:SetText(outside and "Travel" or TAB_LABEL.boss)
    for key, b in pairs(tabs) do
        if key == state.tab then
            b.bg:SetColorTexture(0.35, 0.28, 0.10, 1)
            b.text:SetTextColor(1, 1, 1)
        else
            b.bg:SetColorTexture(0.12, 0.12, 0.15, 1)
            b.text:SetTextColor(0.6, 0.6, 0.6)
        end
    end
end

-- shared with the other BossNav files
ns.IsTab = IsTab
ns.NextTab = NextTab
ns.SetTab = SetTab
ns.UpdateTabLook = UpdateTabLook
