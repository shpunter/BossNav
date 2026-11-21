-- What the game client knows about an item: name, icon, quality, level,
-- slot. Items the client has not seen yet are asked for, and the Items view
-- redraws once they arrive (GET_ITEM_INFO_RECEIVED). Until then the English
-- name from Forever Atlas stands in.
local ADDON, ns = ...
-- from the files loaded before this one
local ITEM_NAMES             = ns.ITEM_NAMES
local IsSecret               = ns.IsSecret
local state                  = ns.state

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local QUALITY_HEX = { [0] = "9d9d9d", "ffffff", "1eff00", "0070dd", "a335ee", "ff8000", "e6cc80", "00ccff" }
local QUALITY_WORD = { [0] = "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact", "Heirloom" }

local function Readable(v)
    return v ~= nil and not (IsSecret and IsSecret(v))
end

local function ItemIcon(id)
    local ok, icon
    if C_Item and C_Item.GetItemIconByID then
        ok, icon = pcall(C_Item.GetItemIconByID, id)
        if ok and Readable(icon) then return icon end
    end
    if GetItemInfoInstant then
        local ok2, _, _, _, _, icon2 = pcall(GetItemInfoInstant, id)
        if ok2 and Readable(icon2) then return icon2 end
    end
    return QUESTION
end

-- Ask the client to load an item it does not have yet (once per item).
local asked = {}
local function Request(id)
    if asked[id] then return end
    asked[id] = true
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, id)
    end
end

-- { name, quality, ilvl, minLevel, kind, slot, icon, link, known }
local function ItemInfo(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local ok, name, link, quality, ilvl, minLevel, kind, subKind, _, equipLoc
    if get then ok, name, link, quality, ilvl, minLevel, kind, subKind, _, equipLoc = pcall(get, id) end
    local info = { icon = ItemIcon(id) }
    if ok and Readable(name) then
        info.known = true
        info.name = name
        info.link = Readable(link) and link or nil
        info.quality = Readable(quality) and quality or nil
        info.ilvl = Readable(ilvl) and ilvl or nil
        info.minLevel = Readable(minLevel) and minLevel or nil
        info.kind = Readable(subKind) and subKind ~= "" and subKind or (Readable(kind) and kind or nil)
        local slot = Readable(equipLoc) and equipLoc ~= "" and _G[equipLoc] or nil
        info.slot = type(slot) == "string" and slot or nil
    else
        info.name = ITEM_NAMES[id] or ("Item " .. id)
        Request(id)
    end
    return info
end

local function QualityHex(q)
    return QUALITY_HEX[q or 1] or "ffffff"
end

local function QualityWord(q)
    return q and QUALITY_WORD[q] or nil
end

-- Redraw the Items view (once, a moment after a burst of item data arrives).
local pending = false
local events = CreateFrame("Frame")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function()
    if pending or state.tab ~= "item" then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        if state.tab == "item" and ns.RefreshIfShown then ns.RefreshIfShown() end
    end)
end)

-- shared with the other BossNav files
ns.ItemInfo = ItemInfo
ns.ItemQualityHex = QualityHex
ns.ItemQualityWord = QualityWord
