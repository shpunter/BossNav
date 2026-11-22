-- The item filters under the map on the Dungeons tab, as tabs: one tab per
-- group, the open tab's boxes below it. Every box is ticked at first;
-- unticking one hides the matching items from the Items column. The ticks
-- and the open tab are saved, so they are still there next session.
--
--   [Class] [Armor*] [Gear] [Weapon] [Wield] [Other]               [reset]
--   ---------------------------------------------------------------
--   [x] Cloth  [x] Leather  [ ] Mail  [ ] Plate  [x] Miscellaneous
--
-- Armor, Weapon and the boxes under Armor and Other are named by the client, the way its auction house names
-- those categories. A tab with an unticked box carries a "*". Clicking the
-- open tab again ticks all its boxes, or unticks them all when they are all
-- ticked already. The rules live in BossNav_ItemClasses.lua (class) and
-- BossNav_ItemSlots.lua (armour type, slot, weapon, hand).
local ADDON, ns = ...
-- from the files loaded before this one
local ArmorFilter            = ns.ArmorFilter
local CANVAS_W               = ns.CANVAS_W
local ClassHex               = ns.ClassHex
local ClassName              = ns.ClassName
local ClassTicked            = ns.ClassTicked
local DB                     = ns.DB
local FindClass              = ns.FindClass
local GoodsFilter            = ns.GoodsFilter
local HandFilter             = ns.HandFilter
local ITEM_CLASSES           = ns.ITEM_CLASSES
local OnlyMyClass            = ns.OnlyMyClass
local PaintTab               = ns.PaintTab
local Print                  = ns.Print
local SetAllClasses          = ns.SetAllClasses
local SetClassTicked         = ns.SetClassTicked
local SlotFilter             = ns.SlotFilter
local SlotFiltersActive      = ns.SlotFiltersActive
local StyleTab               = ns.StyleTab
local TAB_EDGE               = ns.TAB_EDGE
local TickedCount            = ns.TickedCount
local WeaponFilter           = ns.WeaponFilter
local mapFrame               = ns.mapFrame
local state                  = ns.state

-- the class filter, shaped like the other groups
local classEntries = {}
for _, c in ipairs(ITEM_CLASSES) do
    classEntries[#classEntries + 1] = { key = c, label = ClassName(c), hex = ClassHex(c) }
end
local ClassFilter = {
    id = "class", title = "Class", entries = classEntries,
    Ticked = ClassTicked, SetTicked = SetClassTicked, SetAll = SetAllClasses,
    AllTicked = function() return TickedCount() == #ITEM_CLASSES end,
    Find = FindClass,
}

local GROUPS = { ClassFilter, ArmorFilter, SlotFilter, WeaponFilter, HandFilter, GoodsFilter }
local BY_ID = { class = ClassFilter, armor = ArmorFilter, slot = SlotFilter, weapon = WeaponFilter, hand = HandFilter, other = GoodsFilter }
-- what the commands call them
local COMMAND = { class = "class", armor = "armor", slot = "gear", weapon = "weapon", hand = "wield", other = "other" }

local function FiltersActive()
    return TickedCount() < #ITEM_CLASSES or SlotFiltersActive()
end

-- the open tab, saved
local function OpenId()
    local id = DB().filterTab
    return BY_ID[id] and id or "class"
end

--------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------
local TAB_H = 22
local TAB_GAP = 4
local PER_ROW = 6
local CELL_W = math.floor(CANVAS_W / PER_ROW)
local BOX = 18
local ROW_H = 20
local BODY_TOP = TAB_H + 6

local GOLD = { 1, 0.82, 0 }

local maxRows = 1
for _, g in ipairs(GROUPS) do maxRows = math.max(maxRows, math.ceil(#g.entries / PER_ROW)) end

local panel = CreateFrame("Frame", nil, mapFrame)
panel:SetSize(CANVAS_W, BODY_TOP + maxRows * ROW_H + 4)
panel:SetPoint("BOTTOMLEFT", mapFrame, "BOTTOMLEFT", 12, 10)
panel:Hide()

local edge = panel:CreateTexture(nil, "ARTWORK")
edge:SetHeight(1)
edge:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -TAB_H)
edge:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -TAB_H)
edge:SetColorTexture(unpack(TAB_EDGE))

local tabs = {}             -- id -> tab button
local pages = {}            -- id -> frame holding that group's boxes
local boxes = {}            -- { group, key, cb, usable }

-- Ticks from the saved choice; a box no ticked class can use (guns with
-- only druids ticked) is greyed out and cannot be clicked. Its tick stays
-- saved and comes back when such a class is ticked again.
local DIM = 0.35
local function SyncBoxes()
    for _, b in ipairs(boxes) do
        b.cb:SetChecked(b.group.Ticked(b.key))
        local usable = (not b.usable) or ns.AnyTickedClass(b.usable)
        if usable then b.cb:Enable() else b.cb:Disable() end
        b.cb:SetAlpha(usable and 1 or DIM)
        b.cb.label:SetAlpha(usable and 1 or DIM)
    end
end

-- tabs: the open one joined to the boxes below, "*" on a filtering one
local function PaintTabs()
    local open = OpenId()
    for _, g in ipairs(GROUPS) do
        local b, on = tabs[g.id], (g.id == open)
        b.text:SetText(g.title .. (g.AllTicked() and "" or " |cffff8040*|r"))
        PaintTab(b, on, TAB_H)
        if on then b.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else b.text:SetTextColor(0.6, 0.6, 0.6) end
        pages[g.id]:SetShown(on)
    end
end

-- after any change: boxes and tabs in step, the item list starts at the top
local function Changed()
    SyncBoxes()
    PaintTabs()
    state.itemIdx = 1
    BossNav_RefreshMap()
end

local function OpenTab(id)
    if OpenId() == id then
        -- the open tab clicked again: all on / all off
        local g = BY_ID[id]
        g.SetAll(not g.AllTicked())
        Changed()
        return
    end
    DB().filterTab = id
    PaintTabs()
end

local function ResetAll()
    for _, g in ipairs(GROUPS) do g.SetAll(true) end
    Changed()
end

local x = 0
for _, g in ipairs(GROUPS) do
    local b = CreateFrame("Button", nil, panel)
    b:SetFrameLevel(panel:GetFrameLevel() + 2)   -- over the edge line
    StyleTab(b)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("CENTER", 0, -1)
    b.text:SetText(g.title .. " *")                -- widest it gets
    local w = math.max(60, math.ceil(b.text:GetStringWidth() or 0) + 16)
    b:SetSize(w, TAB_H)
    b:SetPoint("TOPLEFT", panel, "TOPLEFT", x, 0)
    x = x + w + TAB_GAP
    local id = g.id
    b:SetScript("OnClick", function() OpenTab(id) end)
    tabs[id] = b

    -- the boxes of this group
    local page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -BODY_TOP)
    page:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    page:Hide()
    pages[id] = page
    for i, e in ipairs(g.entries) do
        local col, row = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
        local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        cb:SetSize(BOX, BOX)
        cb:SetPoint("TOPLEFT", page, "TOPLEFT", col * CELL_W - 3, -row * ROW_H)
        cb.label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cb.label:SetPoint("LEFT", cb, "RIGHT", 0, 0)
        cb.label:SetWidth(CELL_W - BOX)
        cb.label:SetJustifyH("LEFT")
        cb.label:SetWordWrap(false)
        cb.label:SetText(e.hex and ("|cff" .. e.hex .. e.label .. "|r") or e.label)
        local key = e.key
        cb:SetScript("OnClick", function(self)
            g.SetTicked(key, self:GetChecked() and true or false)
            Changed()
        end)
        boxes[#boxes + 1] = { group = g, key = key, cb = cb, usable = e.usable }
    end
end

local reset = CreateFrame("Button", nil, panel)
reset:SetSize(50, TAB_H)
reset:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
reset.text = reset:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
reset.text:SetPoint("CENTER")
reset.text:SetText("[reset]")
reset:SetScript("OnClick", ResetAll)

local function ShowFilterPanel()
    SyncBoxes()
    PaintTabs()
    panel:Show()
end

local function HideFilterPanel()
    panel:Hide()
end

--------------------------------------------------------------------------
-- /bnav class | armor | gear | weapon | wield | other  [name | all | none]
-- A name flips that box (and opens that tab); /bnav class mine keeps only
-- your class; /bnav filters reset ticks everything; /bnav filters next
-- opens the next tab.
--------------------------------------------------------------------------
local function Ticks(g)
    if g.AllTicked() then return "all" end
    local t = {}
    for _, e in ipairs(g.entries) do
        if g.Ticked(e.key) then t[#t + 1] = e.hex and ("|cff" .. e.hex .. e.label .. "|r") or e.label end
    end
    return (#t == 0) and "none" or table.concat(t, ", ")
end

local function FilterCommand(groupId, rest)
    local g = BY_ID[groupId]
    if not g then return end
    local word = (rest or ""):lower():match("^%s*(.-)%s*$")
    if word == "all" then
        g.SetAll(true)
    elseif word == "none" then
        g.SetAll(false)
    elseif (word == "mine" or word == "me") and g == ClassFilter then
        if not OnlyMyClass() then Print("Could not read your class.") return end
    elseif word ~= "" then
        local key = g.Find(word)
        if not key then
            local names = {}
            for _, e in ipairs(g.entries) do names[#names + 1] = e.label:lower() end
            Print("Usage: /bnav " .. COMMAND[g.id] .. " " .. table.concat(names, " | ") .. " | all | none")
            return
        end
        g.SetTicked(key, not g.Ticked(key))
    end
    DB().filterTab = g.id
    Print(g.title .. " filter: " .. Ticks(g) .. ".")
    if mapFrame:IsShown() then Changed() end
end

local function FiltersCommand(rest)
    local word = (rest or ""):lower()
    if word:match("reset") then
        for _, g in ipairs(GROUPS) do g.SetAll(true) end
        Print("Item filters reset: everything ticked.")
        if mapFrame:IsShown() then Changed() end
        return
    end
    if word:match("next") then
        local open, pos = OpenId(), 1
        for i, g in ipairs(GROUPS) do if g.id == open then pos = i end end
        DB().filterTab = GROUPS[(pos % #GROUPS) + 1].id
        PaintTabs()
        return
    end
    for _, g in ipairs(GROUPS) do Print(g.title .. ": " .. Ticks(g)) end
end

-- /bnav class | armor | gear | weapon | wield | other name, /bnav filters
local function FilterWords(group, words)
    ns.AddCommand(words, function(rest) FilterCommand(group, rest) end)
end
FilterWords("class", { "class", "classes" })
FilterWords("other", { "other", "goods" })
FilterWords("armor", { "armor", "armour" })
FilterWords("slot", { "gear", "slot", "slots" })
FilterWords("weapon", { "weapon", "weapons" })
FilterWords("hand", { "wield", "hand", "hands" })
ns.AddCommand({ "filter", "filters" }, FiltersCommand, {
    "  /bnav class name      tick / untick a class in the item filters under the map (all | none | mine); saved",
    "  /bnav armor | gear | weapon | wield name   the same for armour type (cloth, plate...), gear (helm, boots, ring...), weapon types (axe, staff...), wield (one-hand, two-hand...)",
    "  /bnav other name      the same for everything else, by auction house category (recipe, trade goods, consumable...)",
    "  /bnav filters [reset | next]  list the item filters, tick everything again, or open the next filter tab",
})

-- shared with the other BossNav files
ns.ResetItemFilters = ResetAll
ns.FiltersActive = FiltersActive
ns.HideFilterPanel = HideFilterPanel
ns.filterPanel = panel
ns.ShowFilterPanel = ShowFilterPanel
