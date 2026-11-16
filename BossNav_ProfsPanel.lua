-- Profs tab of the map window: group members in the sidebar (with their
-- action count) and a table over the map with one row per profession and one
-- column per member. The counts come from BossNav_Profs.lua.
local ADDON, ns = ...
-- from the files loaded before this one
local CANVAS_W               = ns.CANVAS_W
local ChatChannel            = ns.ChatChannel
local ColorName              = ns.ColorName
local DB                     = ns.DB
local PostProfs              = ns.PostProfs
local ProfCommand            = ns.ProfCommand
local ProfList               = ns.ProfList
local ProfMembers            = ns.ProfMembers
local ProfTotalActions       = ns.ProfTotalActions
local SIDEBAR_W              = ns.SIDEBAR_W
local canvas                 = ns.canvas
local headerText             = ns.headerText
local navText                = ns.navText
local sidebar                = ns.sidebar
local state                  = ns.state
local statusText             = ns.statusText

local ROW_H = 24
local MAX_ROWS = 20
local LINE_H = 20
local MAX_COLS = 5            -- member columns in the table
local MAX_PROF_ROWS = 10      -- profession rows (plus the Total row)
local LABEL_W = 150
local COL_W = math.floor((CANVAS_W - 24 - LABEL_W) / MAX_COLS)

--------------------------------------------------------------------------
-- Member rows in the sidebar
--------------------------------------------------------------------------
local rows = {}
local function GetMemberRow(i)
    if not rows[i] then
        local b = CreateFrame("Button", nil, sidebar)
        b:SetSize(SIDEBAR_W - 8, ROW_H)
        b:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 4, -24 - (i - 1) * ROW_H)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints()
        b.hl:SetColorTexture(1, 0.82, 0, 0.15)
        b.num = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.num:SetPoint("LEFT", b, "LEFT", 4, 0)
        b.num:SetWidth(22)
        b.num:SetJustifyH("RIGHT")
        b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.count:SetPoint("RIGHT", b, "RIGHT", -8, 0)
        b.count:SetWidth(40)
        b.count:SetJustifyH("RIGHT")
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("LEFT", b, "LEFT", 30, 0)
        b.text:SetWidth(SIDEBAR_W - 30 - 48 - 8)
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        b:SetScript("OnClick", function(self)
            if self.profIdx then
                state.profIdx = self.profIdx
                BossNav_RefreshMap()
            end
        end)
        rows[i] = b
    end
    return rows[i]
end

--------------------------------------------------------------------------
-- Table panel over the map
--------------------------------------------------------------------------
local panel = CreateFrame("Frame", nil, canvas)
panel:SetAllPoints()
panel:SetFrameLevel(canvas:GetFrameLevel() + 6)   -- above the map tiles and pins
local panelBg = panel:CreateTexture(nil, "BACKGROUND")
panelBg:SetAllPoints()
panelBg:SetColorTexture(0.03, 0.03, 0.04, 1)
panel:Hide()

local panelTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
panelTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -14)
panelTitle:SetWidth(CANVAS_W - 32)
panelTitle:SetJustifyH("LEFT")
panelTitle:SetText("Who did what")

local panelEmpty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
panelEmpty:SetPoint("CENTER")
panelEmpty:SetWidth(CANVAS_W - 60)
panelEmpty:SetJustifyH("CENTER")

-- Row 0 is the header (member names), rows 1.. are professions, the last one is Total
local grid = {}   -- grid[r] = { label = fs, cells = { fs, ... }, line = tex (header only) }
local ICON = 16
local function GetGridRow(r)
    if not grid[r] then
        local y = -46 - r * LINE_H
        local g = { cells = {} }
        g.label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        g.label:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)
        g.label:SetWidth(LABEL_W)
        g.label:SetJustifyH("LEFT")
        g.label:SetWordWrap(false)
        for c = 1, MAX_COLS do
            local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            fs:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + LABEL_W + (c - 1) * COL_W, y)
            fs:SetWidth(COL_W - 4)
            fs:SetJustifyH("CENTER")
            fs:SetWordWrap(false)
            g.cells[c] = fs
        end
        if r == 0 then   -- thin line under the header row
            g.line = panel:CreateTexture(nil, "ARTWORK")
            g.line:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y - LINE_H + 3)
            g.line:SetSize(CANVAS_W - 32, 1)
            g.line:SetColorTexture(0.45, 0.40, 0.25, 0.9)
        end
        grid[r] = g
    end
    return grid[r]
end

local function HideRow(g)
    g.label:Hide()
    for _, fs in ipairs(g.cells) do fs:Hide() end
    if g.line then g.line:Hide() end
end

local function HideGridFrom(r)
    for i = r, #grid do
        if grid[i] then HideRow(grid[i]) end
    end
    if r <= 0 and grid[0] then HideRow(grid[0]) end
end

local function ShowGridRow(r, labelText, values)
    local g = GetGridRow(r)
    g.label:SetText(labelText); g.label:Show()
    if g.line then g.line:Show() end
    for c = 1, MAX_COLS do
        local v = values[c]
        if v then g.cells[c]:SetText(v); g.cells[c]:Show() else g.cells[c]:Hide() end
    end
end

-- Which members get a column: the first ones seen, always including the selected member
local function Columns(count, selected)
    local cols = {}
    for i = 1, math.min(count, MAX_COLS) do cols[i] = i end
    if selected > MAX_COLS then cols[MAX_COLS] = selected end
    return cols
end

-- Name trimmed to the column width
local function ShortLabel(name)
    if #name > 10 then return name:sub(1, 9) .. "." end
    return name
end

local function ProfLabel(prof)
    local icon = DB().profIcons and DB().profIcons[prof]
    if icon then return string.format("|T%s:%d:%d:0:0|t %s", tostring(icon), ICON, ICON, prof) end
    return prof
end

local function ShowTable(list, selected)
    local cols = Columns(#list, selected)
    local header = {}
    for c, idx in ipairs(cols) do
        local m = list[idx]
        header[c] = ColorName(ShortLabel(m.name), m.class, 12)
    end
    ShowGridRow(0, "|cff888888Profession|r", header)
    local profs = ProfList()
    local r = 0
    for _, prof in ipairs(profs) do
        if r >= MAX_PROF_ROWS then break end
        r = r + 1
        local vals = {}
        for c, idx in ipairs(cols) do
            local n = list[idx].profs[prof]
            local color = (idx == selected) and "|cffffd100" or "|cffffffff"
            vals[c] = n and (color .. n .. "|r") or "|cff444444-|r"
        end
        ShowGridRow(r, ProfLabel(prof), vals)
    end
    if #profs > MAX_PROF_ROWS then
        grid[r].label:SetText("|cff888888... and " .. (#profs - MAX_PROF_ROWS + 1) .. " more|r")
    end
    r = r + 1
    local totals = {}
    for c, idx in ipairs(cols) do
        local color = (idx == selected) and "|cffffd100" or "|cffffffff"
        totals[c] = color .. (list[idx].total or 0) .. "|r"
    end
    ShowGridRow(r, "|cffffd100Total|r", totals)
    HideGridFrom(r + 1)
end

--------------------------------------------------------------------------
-- Bottom controls
--------------------------------------------------------------------------
local clearBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
clearBtn:SetSize(80, 22)
clearBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 7)
clearBtn:SetText("Clear")
clearBtn:SetScript("OnClick", function() ProfCommand("clear") end)

local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("LEFT", clearBtn, "RIGHT", 10, 0)
hint:SetWidth(CANVAS_W - 12 - 80 - 10 - 170 - 12)
hint:SetJustifyH("LEFT")
hint:SetText("/bnav prof N lists every spell of member N")

local postBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
postBtn:SetSize(160, 22)
postBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 7)
postBtn:SetScript("OnClick", PostProfs)

--------------------------------------------------------------------------
-- Render (called by BossNav_RefreshMap; returns true when the Profs tab is shown)
--------------------------------------------------------------------------
local function RenderProfTab()
    if state.tab ~= "prof" then
        panel:Hide()
        for _, r in ipairs(rows) do r:Hide() end
        return false
    end

    local list = ProfMembers()
    local count = #list
    if state.profIdx < 1 then state.profIdx = 1 end
    if state.profIdx > count then state.profIdx = math.max(count, 1) end

    headerText:SetText("|cffffd100Professions|r  |cff888888mines, herbs, skins, fish, crafts per member|r")
    statusText:SetText(count > 0 and string.format("%d member%s, %d actions", count, count == 1 and "" or "s", ProfTotalActions()) or "")
    navText:SetText("")

    -- Sidebar: members in the order first seen, numbered so /bnav prof N can pick one
    for i = 1, math.min(count, MAX_ROWS) do
        local m = list[i]
        local r = GetMemberRow(i)
        r.profIdx = i
        local selected = (i == state.profIdx)
        r.num:SetText((selected and "|cffffd100" or "|cff888888") .. i .. ".|r")
        r.text:SetText(ColorName(m.name, m.class, 14))
        r.count:SetText((selected and "|cffffd100" or "|cffffffff") .. (m.total or 0) .. "|r")
        r:Show()
    end
    for i = math.min(count, MAX_ROWS) + 1, #rows do rows[i]:Hide() end

    panel:Show()
    local _, where = ChatChannel()
    postBtn:SetText(where and ("Post to " .. where .. " chat") or "Print to my chat")
    if count == 0 then
        HideGridFrom(0)
        panelEmpty:SetText("No profession use seen yet.\nMining, herbs, skinning, fishing, disenchanting and crafting\nby anyone in the group are counted here.\n\n/bnav prof debug prints every cast the game reports, if nothing shows up.")
        panelEmpty:Show()
    else
        panelEmpty:Hide()
        ShowTable(list, state.profIdx)
    end
    return true
end

-- shared with the other BossNav files
ns.RenderProfTab = RenderProfTab
