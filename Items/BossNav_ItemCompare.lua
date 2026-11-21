-- The item card's comparison with what you wear, like the game's own
-- Shift-compare: the tooltip of the item you have in that slot sits next to
-- the dropped item's tooltip (two for rings, trinkets and one-hand weapons),
-- and the dropped item's tooltip ends with what would change:
--
--   [dropped item tooltip]      Equipped
--   ...                         [your item's tooltip]
--   If you replace Worn Boots:
--   Agility      +4
--   Armor       +12
--   Spirit       -1
--
-- It follows your gear: changing equipment redraws the card.
local ADDON, ns = ...
-- from the files loaded before this one
local IsSecret               = ns.IsSecret
local ItemKind               = ns.ItemKind
local RefreshIfShown         = ns.RefreshIfShown
local state                  = ns.state

-- equip slot -> your inventory slots it would replace
local SLOTS_OF = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 },
    INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
    INVTYPE_TABARD = { 19 },
}

local function Plain(v)
    if v == nil or (IsSecret and IsSecret(v)) then return nil end
    return v
end

local function EquippedLink(slot)
    local ok, link = pcall(GetInventoryItemLink, "player", slot)
    link = ok and Plain(link)
    return type(link) == "string" and link or nil
end

-- stat key -> amount, from the game's own item stat reader
local function Stats(link)
    local get = (C_Item and C_Item.GetItemStats) or GetItemStats
    if not (get and link) then return {} end
    local ok, t = pcall(get, link)
    if not ok or type(t) ~= "table" then return {} end
    local out = {}
    for k, v in pairs(t) do
        if type(k) == "string" and type(Plain(v)) == "number" then out[k] = v end
    end
    return out
end

local function StatName(key)
    local name = _G[key]
    if type(name) ~= "string" or name == "" then return nil end
    return (name:gsub("%%s", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- { { name = "Agility", amount = "+4", up = true }, ... } sorted by name;
-- empty when nothing changes
local function Deltas(newLink, oldLink)
    local new, old = Stats(newLink), Stats(oldLink)
    local keys = {}
    for k in pairs(new) do keys[k] = true end
    for k in pairs(old) do keys[k] = true end
    local parts = {}
    for k in pairs(keys) do
        local d = (new[k] or 0) - (old[k] or 0)
        local name = StatName(k)
        if name and math.abs(d) >= 0.05 then
            local amount = (math.floor(d) == d) and string.format("%+d", d) or string.format("%+.1f", d)
            parts[#parts + 1] = { name = name, amount = amount, up = d > 0 }
        end
    end
    table.sort(parts, function(a, b) return a.name < b.name end)
    return parts
end

-- one line per stat: name on the left, change on the right (green / red)
local function AddDeltaLines(tip, deltas)
    if #deltas == 0 then
        tip:AddLine("No change in stats.", 1, 1, 1)
        return
    end
    for _, p in ipairs(deltas) do
        local r, g, b = 1, 0.13, 0.13
        if p.up then r, g, b = 0.13, 1, 0.13 end
        local name = p.name:sub(1, 1):upper() .. p.name:sub(2)
        tip:AddDoubleLine(name, p.amount, r, g, b, r, g, b)
    end
end

--------------------------------------------------------------------------
-- Widgets: up to two tooltips of your own items, each under an "Equipped" label
--------------------------------------------------------------------------
local compares = {}

local function CompareTip(i, parent)
    if compares[i] then return compares[i] end
    local t = CreateFrame("GameTooltip", "BossNavItemCompareTooltip" .. i, parent, "GameTooltipTemplate")
    t:SetClampedToScreen(false)
    t.label = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    t.label:SetPoint("BOTTOMLEFT", t, "TOPLEFT", 4, 2)
    compares[i] = t
    return t
end

local function HideItemCompare()
    for _, t in ipairs(compares) do
        t:Hide()
        t.label:Hide()
    end
end

-- tip: the dropped item's tooltip (already shown); parent: the card
local function ShowItemCompare(tip, parent, id)
    HideItemCompare()
    local _, _, equipLoc = ItemKind(id)
    local slots = equipLoc and SLOTS_OF[equipLoc]
    if not slots then return end

    local newLink = "item:" .. id
    local scale = (#slots > 1) and 0.85 or 1
    local deltaDone = false
    local anchor = tip
    for i, slot in ipairs(slots) do
        local t = CompareTip(i, parent)
        local link = EquippedLink(slot)
        t:SetOwner(parent, "ANCHOR_NONE")
        t:ClearAllPoints()
        t:SetScale(scale)
        if i == 1 then
            t:SetPoint("TOPLEFT", tip, "TOPRIGHT", 8 / scale, 0)
        else
            t:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
        end
        local shown = false
        if link then shown = pcall(t.SetInventoryItem, t, "player", slot) end
        if not shown then
            t:AddLine("Nothing equipped", 0.6, 0.6, 0.6)
        end
        t:Show()
        t.label:SetText(link and "Equipped" or "Equipped (empty slot)")
        t.label:Show()
        anchor = t

        -- what would change, against the first item you wear in that slot
        if not deltaDone then
            deltaDone = true
            local name = link and link:match("%[(.-)%]")
            tip:AddLine(" ")
            tip:AddLine(link and ("If you replace " .. (name or "your item") .. ":") or "Your slot is empty.", 1, 0.82, 0)
            if link then AddDeltaLines(tip, Deltas(newLink, link)) end
            tip:Show()   -- fit the new lines
        end
    end
end

-- your gear changed: redraw the card while it is up
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:SetScript("OnEvent", function()
    if state.tab == "item" then RefreshIfShown() end
end)

-- shared with the other BossNav files
ns.HideItemCompare = HideItemCompare
ns.ShowItemCompare = ShowItemCompare
