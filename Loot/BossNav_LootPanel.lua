-- Loot tab of the map window: a list of rolled items in the sidebar, and a
-- panel over the map with the roll results of the selected item. The tab
-- buttons themselves live in BossNav_Tabs.lua.
local ADDON, ns = ...
-- from the files loaded before this one
local CANVAS_W               = ns.CANVAS_W
local ChatChannel            = ns.ChatChannel
local ClassText              = ns.ClassText
local ColorName              = ns.ColorName
local DB                     = ns.DB
local LOOT_KIND_COLOR        = ns.LOOT_KIND_COLOR
local LOOT_KIND_LABEL        = ns.LOOT_KIND_LABEL
local LOOT_KIND_ORDER        = ns.LOOT_KIND_ORDER
local LinkName               = ns.LinkName
local LootItems              = ns.LootItems
local LootSortedRolls        = ns.LootSortedRolls
local LootWinnerClass        = ns.LootWinnerClass
local Print                  = ns.Print
local listAnchor             = ns.listAnchor
local SIDEBAR_W              = ns.SIDEBAR_W
local canvas                 = ns.canvas
local headerText             = ns.headerText
local mapFrame               = ns.mapFrame
local navText                = ns.navText
local sidebar                = ns.sidebar
local state                  = ns.state
local statusText             = ns.statusText

local ROW_H = 24
local MAX_ROWS = 20
local LINE_H = 20
local MAX_LINES = 12          -- rows between the title block and the bottom controls

--------------------------------------------------------------------------
-- Item helpers
--------------------------------------------------------------------------
-- Icon texture of an item link; nil when the client does not know the item
local function ItemIcon(link)
    local ok, icon
    if C_Item and C_Item.GetItemIconByID then
        ok, icon = pcall(C_Item.GetItemIconByID, link)
        if ok and icon then return icon end
    end
    if GetItemIcon then
        ok, icon = pcall(GetItemIcon, link)
        if ok and icon then return icon end
    end
    if GetItemInfoInstant then
        local ok2, _, _, _, _, icon2 = pcall(GetItemInfoInstant, link)
        if ok2 and icon2 then return icon2 end
    end
    return nil
end

-- Colour escape at the start of a link: old "|cff1eff00" or modern "|cnIQ2:"
local function LinkColor(link)
    return link:match("^(|cn[^:|]+:)") or link:match("^(|c%x%x%x%x%x%x%x%x)") or "|cffffffff"
end

--------------------------------------------------------------------------
-- Item rows in the sidebar
--------------------------------------------------------------------------
-- Own tooltip frame: unlike GameTooltip it never adds the "compare with your
-- equipped item" panels, and it is placed to the right of the window.
local itemTip = CreateFrame("GameTooltip", "BossNavLootTooltip", UIParent, "GameTooltipTemplate")
itemTip:SetFrameStrata("TOOLTIP")
itemTip:SetClampedToScreen(true)

local selectedLink = nil   -- item shown on the panel; its tooltip stays up while the tab is open

local function ShowLinkTip(link)
    if not link then itemTip:Hide() return end
    itemTip:SetOwner(mapFrame, "ANCHOR_NONE")
    itemTip:ClearAllPoints()
    itemTip:SetPoint("TOPLEFT", mapFrame, "TOPRIGHT", 6, 0)
    local ok = pcall(itemTip.SetHyperlink, itemTip, link)
    if ok then itemTip:Show() else itemTip:Hide() end
end
mapFrame:HookScript("OnHide", function() itemTip:Hide() end)

local ROW_ICON = 18
local lootRows = {}
local function GetLootRow(i)
    if not lootRows[i] then
        local b = CreateFrame("Button", nil, sidebar)
        b:SetSize(SIDEBAR_W - 8, ROW_H)
        b:SetPoint("TOPLEFT", listAnchor, "TOPLEFT", 4, -(i - 1) * ROW_H)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints()
        b.hl:SetColorTexture(1, 0.82, 0, 0.15)
        b.num = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.num:SetPoint("LEFT", b, "LEFT", 4, 0)
        b.num:SetWidth(22)
        b.num:SetJustifyH("RIGHT")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(ROW_ICON, ROW_ICON)
        b.icon:SetPoint("LEFT", b, "LEFT", 30, 0)
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)   -- trim the icon's dark border
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("LEFT", b, "LEFT", 30 + ROW_ICON + 5, 0)
        b.text:SetWidth(SIDEBAR_W - (30 + ROW_ICON + 5) - 8)
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        b:SetScript("OnClick", function(self)
            if self.lootIdx then
                state.lootIdx = self.lootIdx
                BossNav_RefreshMap()
            end
        end)
        -- hovering a row previews that item; leaving goes back to the selected one
        b:SetScript("OnEnter", function(self) ShowLinkTip(self.link) end)
        b:SetScript("OnLeave", function() ShowLinkTip(selectedLink) end)
        lootRows[i] = b
    end
    return lootRows[i]
end

--------------------------------------------------------------------------
-- Roll result panel over the map
--------------------------------------------------------------------------
local panel = CreateFrame("Frame", nil, canvas)
panel:SetAllPoints()
panel:SetFrameLevel(canvas:GetFrameLevel() + 6)   -- above the map tiles and pins
local panelBg = panel:CreateTexture(nil, "BACKGROUND")
panelBg:SetAllPoints()
panelBg:SetColorTexture(0.03, 0.03, 0.04, 1)
panel:Hide()

local TITLE_ICON = 32
local panelIcon = panel:CreateTexture(nil, "ARTWORK")
panelIcon:SetSize(TITLE_ICON, TITLE_ICON)
panelIcon:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -14)
panelIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
panelIcon:Hide()

local panelTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
panelTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + TITLE_ICON + 8, -14)
panelTitle:SetWidth(CANVAS_W - 32 - TITLE_ICON - 8)
panelTitle:SetJustifyH("LEFT")

local panelStatus = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
panelStatus:SetPoint("TOPLEFT", panelTitle, "BOTTOMLEFT", 0, -4)
panelStatus:SetWidth(CANVAS_W - 32)
panelStatus:SetJustifyH("LEFT")

local panelEmpty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
panelEmpty:SetPoint("CENTER")
panelEmpty:SetWidth(CANVAS_W - 60)
panelEmpty:SetJustifyH("CENTER")

--------------------------------------------------------------------------
-- Bottom controls: which roll types to post, and the post button
--------------------------------------------------------------------------
-- Disenchant rolls are posted together with Greed.
local POST_KINDS = { { "need", "Need" }, { "greed", "Greed" }, { "pass", "Pass" } }
local POST_GROUP = { need = "need", greed = "greed", de = "greed", pass = "pass" }

local function PostSettings()
    local db = DB()
    if not db.lootPost then db.lootPost = { need = true, greed = false, pass = false } end
    return db.lootPost
end

local postChecks = {}
local x = 12
for _, def in ipairs(POST_KINDS) do
    local kind, label = def[1], def[2]
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", x, 6)
    cb.label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 1, 0)
    cb.label:SetText("|cff" .. LOOT_KIND_COLOR[kind] .. label .. "|r")
    cb:SetScript("OnClick", function(self)
        PostSettings()[kind] = self:GetChecked() and true or false
    end)
    postChecks[kind] = cb
    x = x + 24 + 1 + 52
end

local postHint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
postHint:SetPoint("LEFT", panel, "BOTTOMLEFT", x + 4, 18)
postHint:SetText("types to post")

local postBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
postBtn:SetSize(160, 22)
postBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 7)

-- One line for the item, then one line per player of each ticked roll type.
-- rich = true uses class icons and colours (own chat only); group chat strips
-- colour codes and icons, so there the class is written as text.
local function PostLines(it, rich)
    local lines = {}
    local status = it.winner and ("won by " .. it.winner) or (it.allPassed and "everyone passed" or "still rolling")
    lines[1] = it.link .. " - " .. status
    local prefs = PostSettings()
    for _, kind in ipairs(LOOT_KIND_ORDER) do
        if prefs[POST_GROUP[kind]] then
            for _, r in ipairs(LootSortedRolls(it, kind)) do
                local won = (r.name == it.winner)
                local kindText = LOOT_KIND_LABEL[kind] .. (r.roll and (" " .. r.roll) or "")
                local who
                if rich then
                    who = LinkName(r.name, r.class, 14)
                    kindText = "|cff" .. LOOT_KIND_COLOR[kind] .. kindText .. "|r"
                else
                    local cls = ClassText(r.class)
                    who = r.name .. (cls and (", " .. cls) or "")
                end
                lines[#lines + 1] = kindText .. "  " .. who .. (won and (rich and "  |cffffd100(winner)|r" or "  (winner)") or "")
            end
        end
    end
    return lines
end

local function PostSelected()
    local items = LootItems()
    local count = #items
    if count == 0 then Print("No loot rolls to post.") return end
    local idx = math.max(1, math.min(state.lootIdx, count))   -- 1 = newest
    local it = items[count - idx + 1]
    local chan = ChatChannel()
    for _, line in ipairs(PostLines(it, chan == nil)) do
        if chan then
            local ok, err = pcall(SendChatMessage, line, chan)
            if not ok then Print("could not post to chat: " .. tostring(err)) return end
        else
            Print(line)
        end
    end
end
postBtn:SetScript("OnClick", PostSelected)

local function UpdateControls()
    local prefs = PostSettings()
    for kind, cb in pairs(postChecks) do cb:SetChecked(prefs[kind] and true or false) end
    local _, where = ChatChannel()
    postBtn:SetText(where and ("Post to " .. where .. " chat") or "Print to my chat")
end

-- One line per roller: kind | roll | name
local lines = {}
local function GetLine(i)
    if not lines[i] then
        local l = {}
        local y = -64 - (i - 1) * LINE_H
        l.kind = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        l.kind:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, y)
        l.kind:SetWidth(70)
        l.kind:SetJustifyH("LEFT")
        l.roll = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        l.roll:SetPoint("TOPLEFT", panel, "TOPLEFT", 100, y)
        l.roll:SetWidth(36)
        l.roll:SetJustifyH("RIGHT")
        l.name = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        l.name:SetPoint("TOPLEFT", panel, "TOPLEFT", 150, y)
        l.name:SetWidth(CANVAS_W - 150 - 16)
        l.name:SetJustifyH("LEFT")
        l.name:SetWordWrap(false)
        lines[i] = l
    end
    return lines[i]
end
local function HideLinesFrom(i)
    for j = i, #lines do
        lines[j].kind:Hide(); lines[j].roll:Hide(); lines[j].name:Hide()
    end
end

local function ItemStatus(it)
    if it.winner then return "|cffffd100Won by|r " .. ColorName(it.winner, LootWinnerClass(it), 16) end
    if it.allPassed then return "|cff888888Everyone passed|r" end
    return "|cff888888Rolling...|r"
end

local function ShowItem(it)
    local icon = ItemIcon(it.link)
    if icon then panelIcon:SetTexture(icon); panelIcon:Show() else panelIcon:Hide() end
    panelTitle:SetText(it.link)
    panelStatus:SetText(ItemStatus(it) .. "  |cff888888" .. date("%H:%M", it.time or 0) .. "|r")
    panelTitle:Show(); panelStatus:Show()
    -- One section per roll type: a header row, then one row per player
    local n, hidden = 0, 0
    local function Row(kindText, rollText, nameText)
        n = n + 1
        if n > MAX_LINES then hidden = hidden + 1 return end
        local l = GetLine(n)
        l.kind:SetText(kindText); l.roll:SetText(rollText); l.name:SetText(nameText)
        l.kind:Show(); l.roll:Show(); l.name:Show()
    end
    for _, kind in ipairs(LOOT_KIND_ORDER) do
        local list = LootSortedRolls(it, kind)
        if #list > 0 then
            Row("|cff" .. LOOT_KIND_COLOR[kind] .. LOOT_KIND_LABEL[kind] .. "|r", "",
                "|cff555555" .. #list .. (#list == 1 and " player" or " players") .. "|r")
            for _, r in ipairs(list) do
                local won = (r.name == it.winner)
                Row("", r.roll and ("|cffffffff" .. r.roll .. "|r") or "|cff555555-|r",
                    ColorName(r.name, r.class, 16) .. (won and "  |cffffd100(winner)|r" or ""))
            end
        end
    end
    if hidden > 0 then
        local l = GetLine(MAX_LINES)
        l.kind:SetText(""); l.roll:SetText("")
        l.name:SetText("|cff888888... and " .. (hidden + 1) .. " more (see /bnav loot)|r")
    end
    HideLinesFrom(math.min(n, MAX_LINES) + 1)
    if n == 0 then
        panelEmpty:SetText("Nobody has rolled on this item yet.")
        panelEmpty:Show()
    else
        panelEmpty:Hide()
    end
end

--------------------------------------------------------------------------
-- Render (called by BossNav_RefreshMap; returns true when the Loot tab is shown)
--------------------------------------------------------------------------
local function RenderLootTab()
    if state.tab ~= "loot" then
        panel:Hide()
        for _, r in ipairs(lootRows) do r:Hide() end
        selectedLink = nil
        itemTip:Hide()
        return false
    end

    local items = LootItems()
    local count = #items
    if state.lootIdx < 1 then state.lootIdx = 1 end
    if state.lootIdx > count then state.lootIdx = math.max(count, 1) end

    headerText:SetText("|cffffd100Loot rolls|r  |cff888888blue and better|r")
    statusText:SetText(count > 0 and string.format("%d item%s recorded", count, count == 1 and "" or "s") or "")
    navText:SetText("")

    -- Sidebar: newest first, numbered so /bnav tab N can pick one
    for i = 1, math.min(count, MAX_ROWS) do
        local it = items[count - i + 1]
        local r = GetLootRow(i)
        r.lootIdx = i
        r.link = it.link
        local selected = (i == state.lootIdx)
        r.num:SetText((selected and "|cffffd100" or "|cff888888") .. i .. ".|r")
        local name = it.link:match("%[(.-)%]") or it.link
        local icon = ItemIcon(it.link)
        if icon then r.icon:SetTexture(icon); r.icon:Show() else r.icon:Hide() end
        r.text:SetText(LinkColor(it.link) .. name .. "|r" .. (it.winner and ("  " .. ColorName(it.winner, LootWinnerClass(it), 12)) or ""))
        r:Show()
    end
    for i = math.min(count, MAX_ROWS) + 1, #lootRows do lootRows[i]:Hide() end

    -- Panel: the selected item
    panel:Show()
    UpdateControls()
    if count == 0 then
        panelTitle:Hide(); panelStatus:Hide(); panelIcon:Hide()
        HideLinesFrom(1)
        panelEmpty:SetText("No loot rolls seen yet.\nGroup-loot rolls on blue and better items show up here.")
        panelEmpty:Show()
        selectedLink = nil
        itemTip:Hide()
    else
        local it = items[count - state.lootIdx + 1]
        ShowItem(it)
        selectedLink = it.link
        ShowLinkTip(selectedLink)   -- item details to the right of the window
    end
    return true
end

-- shared with the other BossNav files
ns.PostLootSelected = PostSelected
ns.RenderLootTab = RenderLootTab
