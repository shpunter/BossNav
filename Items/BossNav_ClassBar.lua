-- The class filter under the map on the Dungeons tab: one box per class
-- (all ticked at first), plus all / none / mine buttons. Unticking a class
-- hides the items no ticked class can use from the Items column. The ticks
-- are saved (BossNav_ItemClasses.lua), so they are still there next session.
--
--   Item filter - classes     [all] [none] [mine]      /bnav class name|all|none|mine
--   [x] Warrior [x] Paladin [x] Hunter [x] Rogue [x] Priest
--   [x] Shaman  [x] Mage    [x] Warlock [x] Druid
local ADDON, ns = ...
-- from the files loaded before this one
local CANVAS_W               = ns.CANVAS_W
local ClassHex               = ns.ClassHex
local ClassName              = ns.ClassName
local ClassTicked            = ns.ClassTicked
local FindClass              = ns.FindClass
local ITEM_CLASSES           = ns.ITEM_CLASSES
local OnlyMyClass            = ns.OnlyMyClass
local Print                  = ns.Print
local SetAllClasses          = ns.SetAllClasses
local SetClassTicked         = ns.SetClassTicked
local TickedCount            = ns.TickedCount
local mapFrame               = ns.mapFrame
local state                  = ns.state

local PER_ROW = 5
local SLOT_W = 104          -- box + class name
local BOX = 24
local TITLE_H = 18

local bar = CreateFrame("Frame", nil, mapFrame)
bar:SetSize(CANVAS_W, TITLE_H + 4 + 2 * BOX)
bar:SetPoint("BOTTOMLEFT", mapFrame, "BOTTOMLEFT", 12, 10)
bar:Hide()

local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
title:SetText("Item filter - classes")

local boxes = {}

local function SyncBoxes()
    for class, cb in pairs(boxes) do cb:SetChecked(ClassTicked(class)) end
end

-- after any change: boxes in step, the item list starts at the top again
local function Changed()
    SyncBoxes()
    state.itemIdx = 1
    BossNav_RefreshMap()
end

for i, class in ipairs(ITEM_CLASSES) do
    local cb = CreateFrame("CheckButton", nil, bar, "UICheckButtonTemplate")
    cb:SetSize(BOX, BOX)
    local col, row = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
    cb:SetPoint("TOPLEFT", bar, "TOPLEFT", col * SLOT_W - 4, -(TITLE_H + 4) - row * BOX)
    cb.label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 1, 0)
    cb.label:SetText("|cff" .. ClassHex(class) .. ClassName(class) .. "|r")
    cb:SetScript("OnClick", function(self)
        SetClassTicked(class, self:GetChecked() and true or false)
        Changed()
    end)
    boxes[class] = cb
end

-- small text buttons after the title
local function TextButton(label, x, onClick)
    local b = CreateFrame("Button", nil, bar)
    b:SetSize(44, TITLE_H)
    b:SetPoint("LEFT", title, "RIGHT", x, 0)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end
TextButton("[all]", 10, function() SetAllClasses(true) Changed() end)
TextButton("[none]", 10 + 46, function() SetAllClasses(false) Changed() end)
TextButton("[mine]", 10 + 92, function() OnlyMyClass() Changed() end)

local hint = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, -3)
hint:SetText("/bnav class name | all | none | mine")

local function ShowClassBar()
    SyncBoxes()
    bar:Show()
end

local function HideClassBar()
    bar:Hide()
end

--------------------------------------------------------------------------
-- /bnav class [name | all | none | mine]: a name flips that class's box
--------------------------------------------------------------------------
local function ClassCommand(rest)
    local word = (rest or ""):lower():match("^%s*(%S*)")
    if word == "all" then
        SetAllClasses(true)
    elseif word == "none" then
        SetAllClasses(false)
    elseif word == "mine" or word == "me" then
        if not OnlyMyClass() then Print("Could not read your class.") return end
    else
        local class = FindClass(word)
        if not class then
            Print("Usage: /bnav class warrior | paladin | hunter | rogue | priest | shaman | mage | warlock | druid | all | none | mine")
            return
        end
        SetClassTicked(class, not ClassTicked(class))
    end
    local names = {}
    for _, c in ipairs(ITEM_CLASSES) do
        if ClassTicked(c) then names[#names + 1] = "|cff" .. ClassHex(c) .. ClassName(c) .. "|r" end
    end
    Print("Items for: " .. ((#names == 0) and "no class" or (TickedCount() == #ITEM_CLASSES and "every class" or table.concat(names, ", "))) .. ".")
    if mapFrame:IsShown() then Changed() end
end

-- shared with the other BossNav files
ns.ClassCommand = ClassCommand
ns.HideClassBar = HideClassBar
ns.ShowClassBar = ShowClassBar
