-- The item filters under the map on the Dungeons tab: four groups of boxes,
-- all ticked at first. Unticking a box hides the matching items from the
-- Items column; the ticks are saved, so they are still there next session.
--
--   Item filters                                     [reset]   /bnav filters
--   Class    [x] Warrior [x] Paladin [x] Hunter ...
--   Gear     [x] Helm    [x] Neck    [x] Shoulders ...
--   Weapon   [x] Axe     [x] Mace    [x] Sword ...
--   Wield    [x] One-Hand [x] Two-Hand ...
--
-- Clicking a group's name ticks all its boxes, or unticks them all when they
-- are all ticked already. The rules live in BossNav_ItemClasses.lua (class)
-- and BossNav_ItemSlots.lua (slot, weapon, hand).
local ADDON, ns = ...
-- from the files loaded before this one
local CANVAS_W               = ns.CANVAS_W
local ClassHex               = ns.ClassHex
local ClassName              = ns.ClassName
local ClassTicked            = ns.ClassTicked
local FindClass              = ns.FindClass
local HandFilter             = ns.HandFilter
local ITEM_CLASSES           = ns.ITEM_CLASSES
local OnlyMyClass            = ns.OnlyMyClass
local Print                  = ns.Print
local SetAllClasses          = ns.SetAllClasses
local SetClassTicked         = ns.SetClassTicked
local SlotFilter             = ns.SlotFilter
local SlotFiltersActive      = ns.SlotFiltersActive
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

local GROUPS = { ClassFilter, SlotFilter, WeaponFilter, HandFilter }

local function FiltersActive()
    return TickedCount() < #ITEM_CLASSES or SlotFiltersActive()
end

--------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------
local LABEL_W = 58          -- group name column
local PER_ROW = 7
local CELL_W = math.floor((CANVAS_W - LABEL_W) / PER_ROW)
local BOX = 18
local ROW_H = 19
local GROUP_GAP = 5
local TITLE_H = 18

local function RowsOf(g) return math.ceil(#g.entries / PER_ROW) end

local height = TITLE_H + 2
for _, g in ipairs(GROUPS) do height = height + RowsOf(g) * ROW_H + GROUP_GAP end

local panel = CreateFrame("Frame", nil, mapFrame)
panel:SetSize(CANVAS_W, height)
panel:SetPoint("BOTTOMLEFT", mapFrame, "BOTTOMLEFT", 12, 10)
panel:Hide()

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
title:SetText("Item filters")

local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -3)
hint:SetText("/bnav class | gear | weapon | wield  name | all | none")

local boxes = {}            -- { group, key, cb }

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

-- after any change: boxes in step, the item list starts at the top again
local function Changed()
    SyncBoxes()
    state.itemIdx = 1
    BossNav_RefreshMap()
end

local function ResetAll()
    for _, g in ipairs(GROUPS) do g.SetAll(true) end
    Changed()
end

local reset = CreateFrame("Button", nil, panel)
reset:SetSize(50, TITLE_H)
reset:SetPoint("LEFT", title, "RIGHT", 10, 0)
reset.text = reset:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
reset.text:SetPoint("CENTER")
reset.text:SetText("[reset]")
reset:SetScript("OnClick", ResetAll)

local y = -(TITLE_H + 2)
for _, g in ipairs(GROUPS) do
    -- the group name: a button that ticks or unticks the whole group
    local name = CreateFrame("Button", nil, panel)
    name:SetSize(LABEL_W - 4, ROW_H)
    name:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    name.text = name:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name.text:SetPoint("LEFT")
    name.text:SetText(g.title)
    name:SetScript("OnClick", function()
        g.SetAll(not g.AllTicked())
        Changed()
    end)
    -- a short group (Wield) spreads its boxes wider so the names fit
    local cellW = (#g.entries <= 5) and math.floor((CANVAS_W - LABEL_W) / 5) or CELL_W
    for i, e in ipairs(g.entries) do
        local col, row = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
        local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        cb:SetSize(BOX, BOX)
        cb:SetPoint("TOPLEFT", panel, "TOPLEFT", LABEL_W + col * cellW - 3, y - row * ROW_H)
        cb.label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cb.label:SetPoint("LEFT", cb, "RIGHT", 0, 0)
        cb.label:SetWidth(cellW - BOX)
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
    y = y - RowsOf(g) * ROW_H - GROUP_GAP
end

local function ShowFilterPanel()
    SyncBoxes()
    panel:Show()
end

local function HideFilterPanel()
    panel:Hide()
end

--------------------------------------------------------------------------
-- /bnav class | gear | weapon | wield  [name | all | none]
-- A name flips that box; /bnav class mine keeps only your class;
-- /bnav filters reset ticks everything.
--------------------------------------------------------------------------
local BY_ID = { class = ClassFilter, slot = SlotFilter, weapon = WeaponFilter, hand = HandFilter }
-- what the commands call them
local COMMAND = { class = "class", slot = "gear", weapon = "weapon", hand = "wield" }

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
    Print(g.title .. " filter: " .. Ticks(g) .. ".")
    if mapFrame:IsShown() then Changed() end
end

local function FiltersCommand(rest)
    if (rest or ""):lower():match("reset") then
        for _, g in ipairs(GROUPS) do g.SetAll(true) end
        Print("Item filters reset: everything ticked.")
        if mapFrame:IsShown() then Changed() end
        return
    end
    for _, g in ipairs(GROUPS) do Print(g.title .. ": " .. Ticks(g)) end
end

-- shared with the other BossNav files
ns.FilterCommand = FilterCommand
ns.ResetItemFilters = ResetAll
ns.FiltersActive = FiltersActive
ns.FiltersCommand = FiltersCommand
ns.HideFilterPanel = HideFilterPanel
ns.filterPanel = panel
ns.ShowFilterPanel = ShowFilterPanel
