-- Shows a small cup icon next to the name of a group member who is drinking.
--
-- Works on the party portrait frames and on the raid-style party / raid
-- blocks. A member counts as drinking while one of their buffs is named
-- "Drink", "Refreshment", "Food & Drink"... Inside instances the client may
-- hide buff names; a hidden name is skipped, so the icon may not show there.
-- /bnav drinkicon turns it off and on.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local Forbidden              = ns.ClassForbidden
local Plain                  = ns.ClassPlain

local ICON     = "Interface\\Icons\\INV_Drink_07"
local SIZE     = 14     -- icon size in pixels
local INTERVAL = 0.3    -- seconds between checks

-- buff names that mean "drinking" (any buff whose name holds one of these)
local DRINK_WORDS = { "Drink", "Refreshment" }

local function Enabled()
    return DB().drinkIcon ~= false
end

local function IsDrinkName(name)
    name = Plain(name)
    if type(name) ~= "string" then return false end
    for _, w in ipairs(DRINK_WORDS) do
        if name:find(w, 1, true) then return true end
    end
    return false
end

-- name of the i-th helpful buff on unit, or nil when there is none
local function BuffName(unit, i)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
        if not ok or type(Plain(aura)) ~= "table" then return nil end
        return aura.name or false   -- false: a buff whose name we cannot read
    end
    if UnitBuff then
        local ok, name = pcall(UnitBuff, unit, i)
        if not ok or name == nil then return nil end
        return name
    end
    return nil
end

local function IsDrinking(unit)
    if type(unit) ~= "string" then return false end
    local okE, exists = pcall(UnitExists, unit)
    if not okE or Plain(exists) ~= true then return false end
    for i = 1, 40 do
        local name = BuffName(unit, i)
        if name == nil then return false end
        if IsDrinkName(name) then return true end
    end
    return false
end

local icons = {}   -- frame -> its cup texture

-- the name text of a party portrait frame or a raid-style block
local function NameOf(frame, i)
    local n = frame.name or frame.Name
    if not n and i then n = _G["PartyMemberFrame" .. i .. "Name"] end
    if type(n) == "table" and n.GetObjectType then return n end
    return nil
end

local function IconFor(frame, nameText)
    local icon = icons[frame]
    if icon then return icon end
    local ok, t = pcall(frame.CreateTexture, frame, nil, "OVERLAY")
    if not ok or not t then return nil end
    t:SetSize(SIZE, SIZE)
    t:SetTexture(ICON)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    t:Hide()
    icons[frame] = t
    return t
end

-- put the cup right after the end of the name, or at the right edge of the
-- name box when the text width cannot be read
local function Place(icon, nameText)
    icon:ClearAllPoints()
    local okW, w = pcall(nameText.GetUnboundedStringWidth or nameText.GetStringWidth, nameText)
    w = okW and Plain(w)
    local okB, box = pcall(nameText.GetWidth, nameText)
    box = okB and Plain(box)
    if type(w) == "number" and type(box) == "number" and w + SIZE + 2 <= box then
        local okJ, justify = pcall(nameText.GetJustifyH, nameText)
        if okJ and Plain(justify) == "LEFT" then
            icon:SetPoint("LEFT", nameText, "LEFT", w + 2, 0)
            return
        end
    end
    icon:SetPoint("LEFT", nameText, "RIGHT", 2, 0)
end

local function Mark(frame, unit, i)
    if type(frame) ~= "table" or Forbidden(frame) or not frame.CreateTexture then return end
    local show = Enabled() and IsDrinking(unit)
    local icon = icons[frame]
    if not show then
        if icon then icon:Hide() end
        return
    end
    local nameText = NameOf(frame, i)
    if not nameText then return end
    icon = IconFor(frame, nameText)
    if not icon then return end
    Place(icon, nameText)
    icon:Show()
end

local function MarkCompact(uf)
    if type(uf) ~= "table" or Forbidden(uf) then return end
    Mark(uf, Plain(uf.displayedUnit) or Plain(uf.unit))
end

-- party portrait frames under every name the game has used
local function PartyFrame(i)
    return _G["PartyMemberFrame" .. i] or (_G.PartyFrame and _G.PartyFrame["MemberFrame" .. i])
end

local function MarkAll()
    for i = 1, 4 do Mark(PartyFrame(i), "party" .. i, i) end
    for i = 1, 5 do MarkCompact(_G["CompactPartyFrameMember" .. i]) end
    for i = 1, 40 do MarkCompact(_G["CompactRaidFrame" .. i]) end
    for g = 1, 8 do
        for m = 1, 5 do MarkCompact(_G["CompactRaidGroup" .. g .. "Member" .. m]) end
    end
end

local ticker = CreateFrame("Frame")
local elapsed = 0
ticker:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < INTERVAL then return end
    elapsed = 0
    if not (IsInGroup and IsInGroup()) and not next(icons) then return end
    pcall(MarkAll)
end)

-- /bnav drinkicon
local function ToggleDrinkIcon()
    DB().drinkIcon = not Enabled()
    pcall(MarkAll)
    return DB().drinkIcon
end

-- shared with the other BossNav files
ns.ToggleDrinkIcon = ToggleDrinkIcon
