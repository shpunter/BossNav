-- The selected quest drawn like the game's quest window: parchment, the
-- title, "Description", "Quest Objectives" and "Rewards" with item slots and
-- coins. The text comes from your quest log when you have the quest
-- (BossNav_QuestLogInfo.lua), else from BossNav_QuestText.lua.
-- Long quests scroll: mouse wheel, /bnav quest down|up, or the keybinds.
local ADDON, ns = ...
-- from the files loaded before this one
local CANVAS_W               = ns.CANVAS_W
local CANVAS_H               = ns.CANVAS_H
local IsSecret               = ns.IsSecret
local QUEST_FACTIONS         = ns.QUEST_FACTIONS
local QUEST_REWARD_ITEMS     = ns.QUEST_REWARD_ITEMS
local QUEST_TEXT             = ns.QUEST_TEXT
local ReadQuestLog           = ns.ReadQuestLog
local canvas                 = ns.canvas
local mapFrame               = ns.mapFrame
local navText                = ns.navText

local PAD = 14
local CONTENT_W = CANVAS_W - 2 * PAD - 16          -- room for the scroll bar
local SLOT_W = math.floor((CONTENT_W - 8) / 2)    -- two reward slots per row
local SLOT_H = 41
local SCROLL_STEP = 60

-- quest window colours: black headings, dark brown text on parchment
local HEAD_R, HEAD_G, HEAD_B = 0, 0, 0
local TEXT_R, TEXT_G, TEXT_B = 0.18, 0.12, 0.06
-- item quality colours (grey, white, green, blue, purple, orange), darkened
-- just enough to read on parchment
local QUALITY_HEX = { [0] = "555555", "000000", "0b6e00", "0050b0", "7a1fb5", "b35900" }

--------------------------------------------------------------------------
-- Frame: parchment with a scrolling page
--------------------------------------------------------------------------
-- The page takes the whole left column: from the map's top down to the
-- window's bottom, less room for the navigation line and help under it
-- (moved below the page while it shows), so most quests fit unscrolled.
local FOOTER_H = 60
local frame = CreateFrame("Frame", nil, canvas)
frame:SetPoint("TOPLEFT", canvas, "TOPLEFT")
frame:SetPoint("BOTTOMRIGHT", mapFrame, "BOTTOMLEFT", 12 + CANVAS_W, 12 + FOOTER_H)
frame:SetFrameLevel(canvas:GetFrameLevel() + 8)   -- above the map, pins and the Quests panel
frame:Hide()
frame:SetScript("OnShow", function()
    navText:ClearAllPoints()
    navText:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -8)
end)
frame:SetScript("OnHide", function()
    navText:ClearAllPoints()
    navText:SetPoint("TOPLEFT", canvas, "BOTTOMLEFT", 0, -8)
end)
-- solid parchment colour first, so the page stays readable if the
-- texture below is missing on this client
local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
fill:SetAllPoints()
fill:SetColorTexture(0.87, 0.80, 0.64, 1)
local parchment = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
parchment:SetAllPoints()
parchment:SetTexture("Interface\\QuestFrame\\QuestBG")
parchment:SetTexCoord(0, 0.586, 0, 0.65)

local scroll = CreateFrame("ScrollFrame", nil, frame)
scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -10)
scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD - 16, 10)
local page = CreateFrame("Frame", nil, scroll)
page:SetSize(CONTENT_W, 10)
scroll:SetScrollChild(page)

-- thin scroll position bar at the right edge
local barBg = frame:CreateTexture(nil, "ARTWORK")
barBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD + 4, -10)
barBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD + 4, 10)
barBg:SetWidth(4)
barBg:SetColorTexture(0.35, 0.25, 0.12, 0.25)
local barThumb = frame:CreateTexture(nil, "OVERLAY")
barThumb:SetWidth(4)
barThumb:SetColorTexture(0.35, 0.25, 0.12, 0.9)

local function MaxScroll()
    return math.max(0, page:GetHeight() - scroll:GetHeight())
end

local function UpdateBar()
    local max = MaxScroll()
    if max <= 0 then barBg:Hide(); barThumb:Hide() return end
    local track = scroll:GetHeight()
    local h = math.max(20, track * scroll:GetHeight() / page:GetHeight())
    local y = (track - h) * scroll:GetVerticalScroll() / max
    barThumb:SetHeight(h)
    barThumb:ClearAllPoints()
    barThumb:SetPoint("TOP", barBg, "TOP", 0, -y)
    barBg:Show(); barThumb:Show()
end

local function ScrollTo(y)
    scroll:SetVerticalScroll(math.max(0, math.min(MaxScroll(), y)))
    UpdateBar()
end

-- step > 0 scrolls down, < 0 up; 0 goes back to the top.
local function ScrollQuestInfo(step)
    if step == 0 then ScrollTo(0) else ScrollTo(scroll:GetVerticalScroll() + step * SCROLL_STEP) end
end

-- keybinds (Bindings.xml): scroll while the quest page is open
function BossNav_ScrollQuest(step)
    if frame:IsVisible() then ScrollQuestInfo(step) end
end

frame:EnableMouseWheel(true)
frame:SetScript("OnMouseWheel", function(_, delta) ScrollQuestInfo(-delta) end)

--------------------------------------------------------------------------
-- Page pieces, created once and reused
--------------------------------------------------------------------------
local function SetFontObjectSafe(fs, name)
    local obj = _G[name]
    if obj then pcall(fs.SetFontObject, fs, obj) end
end

local function NewText(fontName, fallback, r, g, b)
    local fs = page:CreateFontString(nil, "OVERLAY", fallback)
    SetFontObjectSafe(fs, fontName)
    fs:SetWidth(CONTENT_W)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetTextColor(r, g, b)
    fs:SetShadowColor(0, 0, 0, 0)
    return fs
end

local texts = {}       -- pool of text lines; [i] reused in drawing order
local function TextAt(i, kind)
    local key = kind .. i
    if not texts[key] then
        if kind == "head" then
            texts[key] = NewText("QuestTitleFont", "GameFontNormalLarge", HEAD_R, HEAD_G, HEAD_B)
        elseif kind == "small" then
            texts[key] = NewText("QuestFontNormalSmall", "GameFontNormalSmall", TEXT_R, TEXT_G, TEXT_B)
        else
            texts[key] = NewText("QuestFont", "GameFontHighlight", TEXT_R, TEXT_G, TEXT_B)
            texts[key]:SetSpacing(2)
        end
    end
    return texts[key]
end

local function ItemIcon(id)
    if not id then return nil end
    local ok, icon
    if C_Item and C_Item.GetItemIconByID then ok, icon = pcall(C_Item.GetItemIconByID, id) if ok and icon then return icon end end
    if GetItemIcon then ok, icon = pcall(GetItemIcon, id) if ok and icon then return icon end end
    if GetItemInfoInstant then
        local ok2, _, _, _, _, icon2 = pcall(GetItemInfoInstant, id)
        if ok2 and icon2 then return icon2 end
    end
    return nil
end

-- Name and quality: the game's when it has the item loaded, else ours (the
-- classic quality, which WoW Forever changed on some items). An item the
-- game has not loaded yet is asked for; the page redraws when it arrives
-- (BossNav_ItemInfo.lua).
local function ItemNameQuality(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if id and get then
        local ok, name, _, quality = pcall(get, id)
        if ok and type(name) == "string" and not (IsSecret and IsSecret(name)) then
            if IsSecret and IsSecret(quality) then quality = nil end
            local known = QUEST_REWARD_ITEMS[id]
            return name, quality or (known and known[2])
        end
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    end
    local known = id and QUEST_REWARD_ITEMS[id]
    if known then return known[1], known[2] end
    return id and ("item " .. id) or "?", 1
end

-- A reward slot like the quest window's: icon with count, name plate beside.
local slots = {}
local function SlotAt(i)
    if slots[i] then return slots[i] end
    local s = CreateFrame("Button", nil, page)
    s:SetSize(SLOT_W, SLOT_H)
    s.icon = s:CreateTexture(nil, "ARTWORK")
    s.icon:SetSize(37, 37)
    s.icon:SetPoint("LEFT", s, "LEFT", 1, 0)
    s.plate = s:CreateTexture(nil, "BACKGROUND")
    s.plate:SetPoint("LEFT", s.icon, "RIGHT", -8, 0)
    s.plate:SetSize(SLOT_W - 30, 64)
    s.plate:SetTexture("Interface\\QuestFrame\\UI-QuestItemNameFrame")
    s.plateFill = s:CreateTexture(nil, "BACKGROUND", nil, -1)
    -- the frame art only covers the middle of the texture: ~40 in from
    -- the icon, ~30 short of the slot's right edge
    s.plateFill:SetPoint("TOPLEFT", s.icon, "TOPRIGHT", 42, -2)
    s.plateFill:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -32, 2)
    s.plateFill:SetColorTexture(0.62, 0.52, 0.36, 0.35)
    s.count = s:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    s.count:SetPoint("BOTTOMRIGHT", s.icon, "BOTTOMRIGHT", -2, 2)
    s.name = s:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    SetFontObjectSafe(s.name, "QuestFontNormalSmall")
    s.name:SetPoint("LEFT", s.icon, "RIGHT", 50, 0)
    s.name:SetWidth(SLOT_W - 37 - 50 - 40)
    s.name:SetMaxLines(2)
    s.name:SetJustifyH("LEFT")
    s.name:SetShadowColor(0, 0, 0, 0)
    s:SetScript("OnEnter", function(self)
        if not (GameTooltip and self.itemID) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. self.itemID)
        GameTooltip:Show()
    end)
    s:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    slots[i] = s
    return s
end

local function FillSlot(s, item)
    -- item: { id, count } from the table, or { id, name, icon, count, quality } from the log
    local id = item.id or item[1]
    local count = item.count or item[2] or 1
    local name, quality = item.name, item.quality
    if not name then name, quality = ItemNameQuality(id) end
    s.itemID = id
    s.icon:SetTexture(item.icon or ItemIcon(id) or "Interface\\Icons\\INV_Misc_QuestionMark")
    s.count:SetText(count > 1 and count or "")
    s.name:SetText("|cff" .. (QUALITY_HEX[quality or 1] or "000000") .. name .. "|r")
end

--------------------------------------------------------------------------
-- Text with the game's placeholders filled in
--------------------------------------------------------------------------
local function PlayerWord(fn, unit, index)
    if not fn then return nil end
    local r = { pcall(fn, unit) }
    local v = r[1] and r[1 + index]
    if type(v) ~= "string" or (IsSecret and IsSecret(v)) then return nil end
    return v
end

-- "$N" your name, "$C" class, "$R" race, "$Gman:woman;" by gender, "$B" new line.
local function FillPlaceholders(s)
    if not s then return nil end
    local name = PlayerWord(UnitName, "player", 1) or "adventurer"
    local class = PlayerWord(UnitClass, "player", 1) or "adventurer"
    local race = PlayerWord(UnitRace, "player", 1) or "traveler"
    local okSex, sex = pcall(UnitSex, "player")
    local female = okSex and sex == 3
    s = s:gsub("%$[Gg]%s*([^:;]*):([^;]*);", function(m, f) return female and f or m end)
    s = s:gsub("%$[Bb]", "\n")
    s = s:gsub("%$[Nn]", name):gsub("%$[Cc]", class):gsub("%$[Rr]", race)
    return s
end

--------------------------------------------------------------------------
-- Money: gold / silver / copper with coin icons, styled like the game's
-- quest window (BossNav_Gold.lua has a brighter one for the dark window)
--------------------------------------------------------------------------
local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:0:0:2:0|t"
local function RewardMoneyText(copper)
    if GetCoinTextureString then
        local ok, s = pcall(GetCoinTextureString, copper)
        if ok and type(s) == "string" then return s end
    end
    local g, sv, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. COIN:format("Gold") end
    if sv > 0 then parts[#parts + 1] = sv .. COIN:format("Silver") end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. COIN:format("Copper") end
    return table.concat(parts, " ")
end

local function SpellNameIcon(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, id)
        if ok and type(info) == "table" then return info.name, info.iconID end
    end
    if GetSpellInfo then
        local ok, name, _, icon = pcall(GetSpellInfo, id)
        if ok then return name, icon end
    end
    return nil
end

--------------------------------------------------------------------------
-- Drawing: stack the pieces top to bottom
--------------------------------------------------------------------------
local used = {}   -- counters per piece kind while drawing
local y           -- current depth on the page

local function Put(kind, text, gap)
    used[kind] = (used[kind] or 0) + 1
    local fs = TextAt(used[kind], kind)
    y = y + (gap or 0)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
    fs:SetText(text)
    fs:Show()
    y = y + fs:GetStringHeight()
    return fs
end

local function PutSlots(items)
    for i, item in ipairs(items) do
        used.slot = (used.slot or 0) + 1
        local s = SlotAt(used.slot)
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", page, "TOPLEFT", col * (SLOT_W + 8), -(y + 6 + row * (SLOT_H + 4)))
        FillSlot(s, item)
        s:Show()
    end
    if #items > 0 then y = y + 6 + math.ceil(#items / 2) * (SLOT_H + 4) end
end

local function HideUnused()
    for key, fs in pairs(texts) do
        local kind, n = key:match("^(%a+)(%d+)$")
        if tonumber(n) > (used[kind] or 0) then fs:Hide() end
    end
    for i = (used.slot or 0) + 1, #slots do slots[i]:Hide() end
end

-- The quest's text and rewards: your quest log first, then the table.
local function QuestInfo(q)
    local live = ReadQuestLog and ReadQuestLog(q)
    local known = QUEST_TEXT[q.id] or {}
    if not live then return known, false end
    -- the log may leave a part empty: fill it from the table
    local info = { d = live.d or known.d, o = live.o or known.o, rep = known.rep, sp = known.sp }
    info.c = (#live.c > 0) and live.c or known.c
    info.r = (#live.r > 0) and live.r or known.r
    info.m = (live.m and live.m > 0) and live.m or known.m
    return info, true
end

-- Draw a quest. title: the quest name; infoLines: BossNav's own lines
-- (level, faction, giver, place) shown under the title. Redrawing the same
-- quest keeps the scroll position; another quest starts at the top.
local shownID
local function ShowQuestInfo(q, titleText, infoLines)
    local sameQuest = (q.id == shownID)
    shownID = q.id
    frame:Show()
    wipe(used)
    y = 0
    local info, live = QuestInfo(q)

    Put("head", titleText)
    Put("small", table.concat(infoLines, "\n"), 6)

    local desc = FillPlaceholders(info.d)
    local obj = FillPlaceholders(info.o)
    if desc and desc ~= "" then
        Put("head", "Description", 14)
        Put("body", desc, 6)
    end
    if obj and obj ~= "" then
        Put("head", "Quest Objectives", 14)
        Put("body", obj, 6)
    end
    if not desc and not obj then
        Put("body", "No quest text known for this quest. Take it, and its text and rewards show up here from your quest log.", 14)
    end

    local choices, items = info.c or {}, info.r or {}
    local money = info.m or 0
    local hasRep = info.rep and #info.rep > 0
    if #choices > 0 or #items > 0 or money > 0 or info.sp or hasRep then
        Put("head", "Rewards", 16)
        if #choices > 0 then
            Put("body", "You will be able to choose one of these rewards:", 6)
            PutSlots(choices)
        end
        if #items > 0 then
            Put("body", #choices > 0 and "You will also receive:" or "You will receive:", 8)
            PutSlots(items)
        end
        if info.sp then
            local name, icon = SpellNameIcon(info.sp)
            if name then
                Put("body", "You will learn:  " .. (icon and ("|T" .. icon .. ":20:20|t ") or "") .. name, 8)
            end
        end
        if money > 0 then
            Put("body", ((#choices + #items > 0 or info.sp) and "You will also receive:  " or "You will receive:  ")
                .. RewardMoneyText(money), 8)
        end
        if hasRep then
            local parts = {}
            for _, r in ipairs(info.rep) do
                parts[#parts + 1] = string.format("%+d %s", r[2], QUEST_FACTIONS[r[1]] or ("faction " .. r[1]))
            end
            Put("small", "Reputation:  " .. table.concat(parts, ",  "), 8)
        end
    elseif q.id and QUEST_TEXT[q.id] and not live then
        Put("small", info.ru and "Rewards not known yet: take the quest to see them." or "No item or money reward.", 16)
    end
    if not live and q.id and QUEST_TEXT[q.id] then
        Put("small", "|cff3d2b12Rewards as WoW Forever lists them (foreverchanges.pro); take the quest to see the game's own.|r", 16)
    end

    HideUnused()
    page:SetHeight(y + 10)
    ScrollTo(sameQuest and scroll:GetVerticalScroll() or 0)
end

local function HideQuestInfo()
    frame:Hide()
    shownID = nil
end

-- shared with the other BossNav files
ns.HideQuestInfo = HideQuestInfo
ns.ScrollQuestInfo = ScrollQuestInfo
ns.ShowQuestInfo = ShowQuestInfo
