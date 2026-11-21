-- Loot roll popup: a small window that opens by itself when a group-loot roll
-- starts and fills in live with who chose Need / Greed / Pass, the numbers
-- rolled and the winner. Several items dropping together are shown one under
-- the other, newest on top. It stays up the whole time any shown roll is still
-- running, and closes by itself a while after every shown item is decided.
-- Drag it with the mouse to move it.
-- The roll data itself comes from BossNav_Loot.lua.
local ADDON, ns = ...
-- from the files loaded before this one
local ColorName              = ns.ColorName
local DB                     = ns.DB
local LOOT_KIND_COLOR        = ns.LOOT_KIND_COLOR
local LOOT_KIND_LABEL        = ns.LOOT_KIND_LABEL
local LOOT_KIND_ORDER        = ns.LOOT_KIND_ORDER
local LootItems              = ns.LootItems
local LootSortedRolls        = ns.LootSortedRolls
local LootWinnerClass        = ns.LootWinnerClass
local Print                  = ns.Print

local WIDTH = 340
local MAX_BLOCKS = 4          -- items shown at once
local HIDE_AFTER = 20         -- seconds the window stays up after the last item is decided
local ROLL_MAX = 120          -- seconds: a roll with no result after this counts as over (a missed "won" line)
local ICON = 22
local PAD = 8

local function Enabled()
    local db = DB()
    if db.lootPopup == nil then db.lootPopup = true end
    return db.lootPopup
end

--------------------------------------------------------------------------
-- Frame
--------------------------------------------------------------------------
local win = CreateFrame("Frame", "BossNavLootPopup", UIParent)
win:SetSize(WIDTH, 60)
win:SetPoint("TOP", UIParent, "TOP", 0, -140)
win:SetFrameStrata("HIGH")
win:SetClampedToScreen(true)
win:Hide()
-- not in UISpecialFrames on purpose: Esc must not close it while a roll is running

win:SetMovable(true)
win:EnableMouse(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart", function(self) self:StartMoving() end)
win:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint(1)
    DB().lootPopupPos = { point, relPoint, x, y }
end)

local function RestorePosition()
    local p = DB().lootPopupPos
    if type(p) ~= "table" or not p[1] then return end
    win:ClearAllPoints()
    win:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local bg = win:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.75)

local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -6)
title:SetText("Loot rolls")

local hint = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("TOPRIGHT", win, "TOPRIGHT", -PAD, -8)
hint:SetText("closes when the rolls end")

-- One block per item: icon, link + status line, then one line per roll type
local blocks = {}
local function GetBlock(i)
    if not blocks[i] then
        local b = {}
        b.icon = win:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(ICON, ICON)
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.head = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.head:SetWidth(WIDTH - PAD * 2 - ICON - 6)
        b.head:SetJustifyH("LEFT")
        b.head:SetWordWrap(false)
        b.status = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.status:SetWidth(WIDTH - PAD * 2 - ICON - 6)
        b.status:SetJustifyH("LEFT")
        b.body = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.body:SetWidth(WIDTH - PAD * 2)
        b.body:SetJustifyH("LEFT")
        b.body:SetJustifyV("TOP")
        b.body:SetSpacing(2)
        blocks[i] = b
    end
    return blocks[i]
end

local function HideBlock(b)
    b.icon:Hide(); b.head:Hide(); b.status:Hide(); b.body:Hide()
end

local function ItemIcon(link)
    if C_Item and C_Item.GetItemIconByID then
        local ok, icon = pcall(C_Item.GetItemIconByID, link)
        if ok and icon then return icon end
    end
    if GetItemInfoInstant then
        local ok, _, _, _, _, icon = pcall(GetItemInfoInstant, link)
        if ok and icon then return icon end
    end
    return nil
end

--------------------------------------------------------------------------
-- Contents
--------------------------------------------------------------------------
local shown = {}      -- drops in the window, newest first
local hideAt = nil    -- GetTime() at which the window closes, once every drop is decided

local function Decided(it)
    return it.winner ~= nil or it.allPassed or (time() - (it.time or 0)) > ROLL_MAX
end

local function Status(it)
    if it.winner then return "|cffffd100Won by|r " .. ColorName(it.winner, LootWinnerClass(it), 14) end
    if it.allPassed then return "|cff888888Everyone passed|r" end
    return "|cff888888Rolling...|r"
end

-- One heading per roll type somebody chose, then each player on a line of their own:
--   Need:
--      Bob 87 (won)
--      Ann 45
local function Body(it)
    local lines = {}
    for _, kind in ipairs(LOOT_KIND_ORDER) do
        local list = LootSortedRolls(it, kind)
        if #list > 0 then
            lines[#lines + 1] = string.format("|cff%s%s:|r", LOOT_KIND_COLOR[kind], LOOT_KIND_LABEL[kind])
            for _, r in ipairs(list) do
                local won = (r.name == it.winner)
                lines[#lines + 1] = "      " .. ColorName(r.name, r.class, 12)
                    .. (r.roll and (" |cffffffff" .. r.roll .. "|r") or "")
                    .. (won and " |cffffd100(won)|r" or "")
            end
        end
    end
    if #lines == 0 then return "|cff888888nobody has chosen yet|r" end
    return table.concat(lines, "\n")
end

local function Render()
    local y = -24
    for i, it in ipairs(shown) do
        local b = GetBlock(i)
        local icon = ItemIcon(it.link)
        b.icon:ClearAllPoints()
        b.icon:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, y)
        if icon then b.icon:SetTexture(icon) else b.icon:SetColorTexture(0.2, 0.2, 0.2, 1) end
        b.head:ClearAllPoints()
        b.head:SetPoint("TOPLEFT", win, "TOPLEFT", PAD + ICON + 6, y)
        b.head:SetText(it.link)
        b.status:ClearAllPoints()
        b.status:SetPoint("TOPLEFT", b.head, "BOTTOMLEFT", 0, -1)
        b.status:SetText(Status(it))
        y = y - math.max(ICON, b.head:GetStringHeight() + b.status:GetStringHeight() + 1) - 3
        b.body:ClearAllPoints()
        b.body:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, y)
        b.body:SetText(Body(it))
        y = y - b.body:GetStringHeight() - 10
        b.icon:Show(); b.head:Show(); b.status:Show(); b.body:Show()
    end
    for i = #shown + 1, #blocks do HideBlock(blocks[i]) end
    win:SetHeight(-y)
end

-- Restart or stop the close timer: it runs only once every shown drop is decided
local function UpdateTimer()
    for _, it in ipairs(shown) do
        if not Decided(it) then hideAt = nil return end
    end
    hideAt = GetTime() + HIDE_AFTER
end

-- Checked twice a second: the close timer, and rolls that ran past ROLL_MAX
local tick = 0
win:SetScript("OnUpdate", function(self, elapsed)
    tick = tick + elapsed
    if tick < 0.5 then return end
    tick = 0
    if hideAt then
        if GetTime() >= hideAt then self:Hide() end
    else
        UpdateTimer()
    end
end)
win:SetScript("OnHide", function()
    hideAt = nil
    for i = #shown, 1, -1 do shown[i] = nil end
end)

-- Called for every loot-roll chat line, with the drop it belongs to
local function OnLootPopup(it)
    if not it or not Enabled() then return end
    local found = false
    for _, s in ipairs(shown) do
        if s == it then found = true break end
    end
    if not found then
        -- a fresh drop: drop decided items from the bottom to make room
        table.insert(shown, 1, it)
        while #shown > MAX_BLOCKS do table.remove(shown) end
    end
    if not win:IsShown() then
        RestorePosition()
        win:Show()
    end
    Render()
    UpdateTimer()
end

-- /bnav loot popup: switch the popup on or off
local function ToggleLootPopup()
    local db = DB()
    db.lootPopup = not Enabled()
    Print("Loot roll popup " .. (db.lootPopup and "on" or "off") .. ".")
    if not db.lootPopup then win:Hide() end
end

-- /bnav loot show: open the popup with the newest item, to check or move it
local function ShowLootPopup()
    local items = LootItems()
    if #items == 0 then Print("No loot rolls seen yet.") return end
    win:Hide()
    local was = DB().lootPopup
    DB().lootPopup = true
    OnLootPopup(items[#items])
    DB().lootPopup = was
end

-- shared with the other BossNav files
ns.OnLootPopup = OnLootPopup
ns.ShowLootPopup = ShowLootPopup
ns.ToggleLootPopup = ToggleLootPopup
