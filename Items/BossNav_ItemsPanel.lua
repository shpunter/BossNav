-- Items column of the Dungeons section (the third column): the loot list
-- (icon, name in its quality colour, who drops it), and, while the column
-- has the focus, a card over the map with the selected item: big icon, drop
-- source and chance, and the game's own item tooltip with every stat. Which
-- items are listed is up to BossNav_ItemFilter.lua (the dungeon and the boss
-- you picked).
--
-- Keys (column focused): Select Next / Previous Boss walk the list; the
-- Scroll keys page it. Mouse: click a row (focuses the column), wheel over
-- the list scrolls it, Shift-click puts the item link in chat.
local ADDON, ns = ...
-- from the files loaded before this one
local CANVAS_W               = ns.CANVAS_W
local ClearItemBoss          = ns.ClearItemBoss
local FilteredItems          = ns.FilteredItems
local ItemInfo               = ns.ItemInfo
local ItemQualityHex         = ns.ItemQualityHex
local ItemQualityWord        = ns.ItemQualityWord
local MARK_W                 = ns.MARK_W
local NAME_FONT_SIZE         = ns.NAME_FONT_SIZE
local Print                  = ns.Print
local ITEM_COL_W             = ns.ITEM_COL_W
local SetFontSize            = ns.SetFontSize
local canvas                 = ns.canvas
local headerText             = ns.headerText
local itemAnchor             = ns.itemAnchor
local itemCol                = ns.itemCol
local mapFrame               = ns.mapFrame
local navText                = ns.navText
local state                  = ns.state
local statusText             = ns.statusText

-- taller than the other lists: room between items, and the rounded box of
-- the selected row clears the square icon
local ROW_H = 28
local MAX_ROWS = 22         -- 22 x 28 px fits the column (taller since the item filters)
local ICON = ROW_H - 8     -- 4 px above and below
local TAG_W = 96           -- "who drops it" column at a row's right end
local BIG_ICON = 52

state.itemIdx = state.itemIdx or 1
local first = 1            -- list index shown in the top row
local lastList = nil       -- the list drawn last time

--------------------------------------------------------------------------
-- Selection and scrolling
--------------------------------------------------------------------------
local function Count()
    return #(FilteredItems())
end

local function ClampFirst(n)
    return math.max(1, math.min(first, math.max(1, n - MAX_ROWS + 1)))
end

-- keep the selected row in view
local function FollowSelection()
    local sel = state.itemIdx
    if sel < first then first = sel
    elseif sel > first + MAX_ROWS - 1 then first = sel - MAX_ROWS + 1 end
end

local function SelectItem(idx)
    local n = Count()
    if n == 0 then return end
    state.itemIdx = math.max(1, math.min(idx, n))
    FollowSelection()
    if mapFrame:IsShown() then BossNav_RefreshMap() end
end

-- step 1 / -1, wrapping round the list
local function CycleItem(step)
    local n = Count()
    if n == 0 then return end
    SelectItem(((state.itemIdx - 1 + step) % n) + 1)
end

-- a page up or down (the scroll keys): moves the selection too
local function PageItems(step)
    SelectItem(state.itemIdx + step * (MAX_ROWS - 1))
end

itemCol:EnableMouseWheel(true)
itemCol:SetScript("OnMouseWheel", function(_, delta)
    first = first - delta * 3
    first = ClampFirst(Count())
    BossNav_RefreshMap()
end)

--------------------------------------------------------------------------
-- Sidebar rows: ">" | icon | name ........ boss
--------------------------------------------------------------------------
local rows = {}
local function GetItemRow(i)
    if rows[i] then return rows[i] end
    local b = CreateFrame("Button", nil, itemCol)
    b:SetSize(ITEM_COL_W - 8, ROW_H)
    b:SetPoint("TOPLEFT", itemAnchor, "TOPLEFT", 4, -(i - 1) * ROW_H)
    ns.AddRoundHover(b)   -- rounded mouse-over box
    b.mark = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.mark:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.mark:SetWidth(MARK_W)
    b.mark:SetJustifyH("RIGHT")
    SetFontSize(b.mark, NAME_FONT_SIZE)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(ICON, ICON)
    b.icon:SetPoint("LEFT", b, "LEFT", MARK_W, 0)   -- 6 px left padding
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)   -- trim the icon's own border
    b.tag = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.tag:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    b.tag:SetWidth(TAG_W)
    b.tag:SetJustifyH("RIGHT")
    b.tag:SetWordWrap(false)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.text:SetPoint("RIGHT", b.tag, "LEFT", -4, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b:SetScript("OnClick", function(self)
        if not self.itemIdx then return end
        if IsShiftKeyDown() and self.link and ChatEdit_InsertLink then
            pcall(ChatEdit_InsertLink, self.link)
            return
        end
        state.itemIdx = self.itemIdx
        FollowSelection()
        ns.SetTab("item")   -- focus the column; the card shows the item
    end)
    rows[i] = b
    return b
end

-- An empty list says why, right in the column: nothing dropped there, or
-- the filters under the map hide all of it (with a button to undo them).
local emptyNote = itemCol:CreateFontString(nil, "OVERLAY", "GameFontDisable")
emptyNote:SetPoint("TOPLEFT", itemAnchor, "TOPLEFT", 10, -8)
emptyNote:SetPoint("RIGHT", itemCol, "RIGHT", -10, 0)
emptyNote:SetJustifyH("LEFT")
emptyNote:Hide()
local resetBtn = CreateFrame("Button", nil, itemCol)
resetBtn:SetSize(110, 20)
resetBtn:SetPoint("TOPLEFT", emptyNote, "BOTTOMLEFT", -2, -6)
resetBtn.text = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
resetBtn.text:SetPoint("LEFT")
resetBtn.text:SetText("[reset filters]")
resetBtn:SetScript("OnClick", function() ns.ResetItemFilters() end)
resetBtn:Hide()

local function ShowEmptyNote(n, cfg, boss)
    if n > 0 then
        emptyNote:Hide()
        resetBtn:Hide()
        return
    end
    if ns.FiltersActive() then
        emptyNote:SetText("No items match the filters under the map.")
        resetBtn:Show()
    else
        emptyNote:SetText(cfg and ("No known loot for " .. (boss or cfg.name) .. ".") or "No loot data.")
        resetBtn:Hide()
    end
    emptyNote:Show()
end

local function HideRows(from)
    for i = from, #rows do rows[i]:Hide() end
end

--------------------------------------------------------------------------
-- Item card over the map
--------------------------------------------------------------------------
-- It covers the map and runs on down to the item filters, over the
-- navigation and help lines (they have nothing to say about an item), so a
-- long tooltip and its comparison fit.
local panel = CreateFrame("Frame", nil, canvas)
panel:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
panel:SetPoint("RIGHT", canvas, "RIGHT", 0, 0)
panel:SetPoint("BOTTOM", ns.filterPanel, "TOP", 0, 8)
panel:SetFrameLevel(canvas:GetFrameLevel() + 6)   -- above the map tiles and pins
local panelBg = panel:CreateTexture(nil, "BACKGROUND")
panelBg:SetAllPoints()
panelBg:SetColorTexture(0.03, 0.03, 0.04, 1)
panel:Hide()

-- big icon with a frame in the item's quality colour
local iconEdge = panel:CreateTexture(nil, "BORDER")
iconEdge:SetSize(BIG_ICON + 4, BIG_ICON + 4)
iconEdge:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -14)
local bigIcon = panel:CreateTexture(nil, "ARTWORK")
bigIcon:SetSize(BIG_ICON, BIG_ICON)
bigIcon:SetPoint("CENTER", iconEdge, "CENTER")
bigIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", iconEdge, "TOPRIGHT", 12, -2)
title:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
title:SetJustifyH("LEFT")
title:SetWordWrap(false)

local source = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
source:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
source:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
source:SetJustifyH("LEFT")
source:SetWordWrap(false)

local facts = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
facts:SetPoint("TOPLEFT", source, "BOTTOMLEFT", 0, -4)
facts:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
facts:SetJustifyH("LEFT")
facts:SetWordWrap(false)

local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
empty:SetPoint("CENTER")
empty:SetWidth(CANVAS_W - 60)
empty:SetJustifyH("CENTER")

-- The game's item tooltip, drawn inside the card under the header.
local tip = CreateFrame("GameTooltip", "BossNavItemCardTooltip", panel, "GameTooltipTemplate")
tip:SetClampedToScreen(false)

local function ShowTip(id)
    tip:SetOwner(panel, "ANCHOR_NONE")
    tip:ClearAllPoints()
    tip:SetPoint("TOPLEFT", iconEdge, "BOTTOMLEFT", -4, -10)
    local ok = pcall(tip.SetItemByID, tip, id)
    if not ok then ok = pcall(tip.SetHyperlink, tip, "item:" .. id) end
    if ok then
        tip:Show()
        ns.ShowItemCompare(tip, panel, id)   -- what you wear in that slot
    else
        tip:Hide()
        ns.HideItemCompare()
    end
end

local function SourceText(e, cfg)
    local who = e.extra and ("|cffbbbbbb" .. e.boss .. "|r") or ("|cffffd100" .. e.boss .. "|r")
    local where = cfg and "" or ("  |cff888888" .. e.dungeon .. "|r")
    return (e.extra and "From " or "Drops from ") .. who .. where
end

local function FactsText(e, info)
    local parts = {}
    parts[#parts + 1] = e.chance and string.format("Drop chance |cffffffff%.1f%%|r", e.chance)
        or "Drop chance |cff888888unknown|r"
    if info.slot or info.kind then
        parts[#parts + 1] = "|cffffffff" .. (info.slot and info.kind and (info.slot .. ", " .. info.kind) or info.slot or info.kind) .. "|r"
    end
    if info.ilvl and info.ilvl > 1 then parts[#parts + 1] = "Item level |cffffffff" .. info.ilvl .. "|r" end
    if info.minLevel and info.minLevel > 1 then parts[#parts + 1] = "Requires level |cffffffff" .. info.minLevel .. "|r" end
    return "|cff999999" .. table.concat(parts, "   ") .. "|r"
end

local function ShowCard(e, cfg)
    local info = ItemInfo(e.id)
    local hex = ItemQualityHex(info.quality)
    iconEdge:SetColorTexture(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255, 0.9)
    bigIcon:SetTexture(info.icon)
    local word = ItemQualityWord(info.quality)
    title:SetText("|cff" .. hex .. info.name .. "|r" .. (word and ("  |cff666666" .. word .. "|r") or ""))
    source:SetText(SourceText(e, cfg))
    facts:SetText(FactsText(e, info))
    for _, r in ipairs({ iconEdge, bigIcon, title, source, facts }) do r:Show() end
    empty:Hide()
    ShowTip(e.id)
end

local function ShowEmpty(text)
    for _, r in ipairs({ iconEdge, bigIcon, title, source, facts }) do r:Hide() end
    tip:Hide()
    ns.HideItemCompare()
    empty:SetText(text)
    empty:Show()
end

--------------------------------------------------------------------------
-- Render (called by BossNav_RefreshMap). Draws the column on every Dungeons
-- view; true when the column has the focus and its card covers the map.
--------------------------------------------------------------------------
local function RenderItemTab()
    if not (ns.InDungeonsSection and ns.InDungeonsSection()) then
        panel:Hide()
        tip:Hide()
        ns.HideItemCompare()
        HideRows(1)
        ShowEmptyNote(1)
        ns.HideFilterPanel()
        return false
    end
    ns.ShowFilterPanel()
    local focused = (state.tab == "item")

    local list, cfg, boss = FilteredItems()
    local n = #list
    -- another dungeon or boss picked: start at the top of the new list
    if list ~= lastList then
        if lastList then state.itemIdx, first = 1, 1 end
        lastList = list
    end
    state.itemIdx = math.max(1, math.min(state.itemIdx or 1, math.max(n, 1)))
    first = ClampFirst(n)

    if focused then
        headerText:SetText("|cffffd100Items|r  |cff888888" .. (cfg and cfg.name or "every dungeon") .. "|r")
        local classNote = ns.FiltersActive() and "  |cff888888(some hidden by the filters under the map)|r" or ""
        statusText:SetText(string.format("%d item%s%s%s", n, n == 1 and "" or "s",
            boss and ("  |cff888888from|r " .. boss .. "  |cff888888([show all] or /bnav items all shows all the dungeon's loot)|r")
            or (cfg and "  |cff888888from every boss and trash (pick one in Bosses to filter)|r" or ""),
            classNote))
        navText:SetText("")
        panel:Show()
    else
        panel:Hide()
        tip:Hide()
        ns.HideItemCompare()
    end

    local shown = 0
    for i = first, math.min(n, first + MAX_ROWS - 1) do
        local e = list[i]
        local info = ItemInfo(e.id)
        shown = shown + 1
        local r = GetItemRow(shown)
        r.itemIdx = i
        r.link = info.link
        -- highlighted only while its card is shown (Items column focused);
        -- with the map up nothing in this list is "open"
        ns.SetRowActive(r, focused and i == state.itemIdx)
        r.icon:SetTexture(info.icon)
        r.text:SetText("|cff" .. ItemQualityHex(info.quality) .. info.name .. "|r")
        -- with one boss picked the column has nothing new to say: show the slot
        -- (Trash spans many mobs, so it keeps naming the source)
        r.tag:SetText((boss and boss ~= ns.TRASH) and (info.slot or info.kind or "") or e.boss)
        r:Show()
    end
    HideRows(shown + 1)
    ShowEmptyNote(n, cfg, boss)

    if not focused then return false end
    if n == 0 and ns.FiltersActive() then
        ShowEmpty("Nothing here for the filters ticked under the map.\nTick more boxes, or /bnav filters reset.")
    elseif n == 0 then
        ShowEmpty(cfg and ("No known loot for " .. (boss or cfg.name) .. " in Forever Atlas.")
            or "No loot data.")
    else
        ShowCard(list[state.itemIdx], cfg)
    end
    return true
end

--------------------------------------------------------------------------
-- /bnav items [n | next | prev | all | trash | down | up]
--------------------------------------------------------------------------
local function ItemsCommand(rest)
    local arg = (rest or ""):lower()
    local n = tonumber(arg)
    if arg == "all" then
        ClearItemBoss()
        Print("Items: all the dungeon's loot (bosses and trash).")
    elseif arg == "trash" then
        local cfg = ns.ItemDungeon()
        if cfg and ns.HasTrash(cfg) then
            ns.PickTrash(cfg)
            Print("Items: trash and rares of " .. cfg.name .. ".")
        else
            Print("Pick a dungeon first: there is no trash loot for every dungeon at once.")
        end
    elseif n then
        SelectItem(n)
    elseif arg == "next" then
        CycleItem(1)
    elseif arg == "prev" then
        CycleItem(-1)
    elseif arg == "down" or arg == "up" then
        PageItems(arg == "down" and 1 or -1)
    end
    ns.SetTab("item")
end

-- The Scroll Quest Text keys page the item list while it is shown.
local ScrollQuest = BossNav_ScrollQuest
function BossNav_ScrollQuest(step)
    if state.tab == "item" and mapFrame:IsShown() then
        PageItems(step)
    elseif ScrollQuest then
        ScrollQuest(step)
    end
end

-- shared with the other BossNav files
ns.CycleItem = CycleItem
ns.ItemsCommand = ItemsCommand
ns.RenderItemTab = RenderItemTab
