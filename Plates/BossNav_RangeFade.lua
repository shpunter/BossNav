-- Fades the party and raid frames of group members farther than ~30 yards.
--
-- The game has no plain "30 yards" check, so the first test that answers wins:
--   1. a 30-yard item range check (works on any class, needs no spell)
--   2. a 30-yard friendly spell the player knows (buffs of priest, mage...)
--   3. the follow distance check (28 yards; skipped in combat, where the
--      client blocks it)
--   4. the game's own group range check (~40 yards), the last resort
-- Inside instances the answer may be a secret value; then the frame is faded
-- with SetAlphaFromBoolean, which takes a secret without reading it.
-- /bnav rangefade turns it off and on.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local Forbidden              = ns.ClassForbidden
local IsSecret               = ns.IsSecret
local Plain                  = ns.ClassPlain

local FADED    = 0.4    -- alpha of a member out of range
local INTERVAL = 0.2    -- seconds between checks

-- items with a 30-yard range on friendly units (Handful of Snowflakes); the
-- player does not need to own it
local ITEMS = { 34191 }

-- friendly 30-yard spells, by name so any rank counts
local SPELLS = {
    "Power Word: Fortitude", "Arcane Intellect", "Mark of the Wild",
    "Blessing of Might", "Blessing of Wisdom", "Unending Breath", "Water Breathing",
}

local function Enabled()
    return DB().rangeFade ~= false
end

-- result of one check: true / false, a secret boolean, or nil when it told nothing
local function Answer(ok, v)
    if not ok then return nil end
    if IsSecret(v) then return v end
    if v == true or v == 1 then return true end
    if v == false or v == 0 then return false end
    return nil
end

local function ItemCheck(unit)
    local fn = (C_Item and C_Item.IsItemInRange) or IsItemInRange
    if not fn then return nil end
    for _, id in ipairs(ITEMS) do
        local a = Answer(pcall(fn, id, unit))
        if a ~= nil then return a end
    end
    return nil
end

local function SpellCheck(unit)
    local fn = (C_Spell and C_Spell.IsSpellInRange) or IsSpellInRange
    if not fn then return nil end
    for _, name in ipairs(SPELLS) do
        local a = Answer(pcall(fn, name, unit))
        if a ~= nil then return a end
    end
    return nil
end

-- The client blocks CheckInteractDistance for addons in combat ("Interface
-- action failed because of an AddOn"); pcall does not stop that report, so
-- the check is skipped in combat and the group range check answers instead.
local function InteractCheck(unit)
    if not CheckInteractDistance then return nil end
    if InCombatLockdown and InCombatLockdown() then return nil end
    return Answer(pcall(CheckInteractDistance, unit, 4))
end

local function GroupCheck(unit)
    if not UnitInRange then return nil end
    local ok, inRange, checked = pcall(UnitInRange, unit)
    if not ok then return nil end
    if not IsSecret(checked) and checked == false then return nil end
    return Answer(true, inRange)
end

-- true / false / secret boolean / nil (unknown: leave the frame alone)
local function InRange(unit)
    if type(unit) ~= "string" then return nil end
    local okE, exists = pcall(UnitExists, unit)
    if not okE or Plain(exists) ~= true then return nil end
    local okM, isMe = pcall(UnitIsUnit, unit, "player")
    if okM and Plain(isMe) == true then return true end
    local okC, connected = pcall(UnitIsConnected, unit)
    if okC and Plain(connected) == false then return nil end   -- the game greys those already
    for _, check in ipairs({ ItemCheck, SpellCheck, InteractCheck, GroupCheck }) do
        local a = check(unit)
        if a ~= nil then return a end
    end
    return nil
end

local touched = {}   -- frame -> true once this file changed its alpha

local function Fade(frame, unit)
    if type(frame) ~= "table" or not frame.SetAlpha or Forbidden(frame) then return end
    local inRange
    if Enabled() then inRange = InRange(unit) end
    if inRange == nil then
        if touched[frame] then
            touched[frame] = nil
            pcall(frame.SetAlpha, frame, 1)
        end
        return
    end
    touched[frame] = true
    if IsSecret(inRange) then
        if frame.SetAlphaFromBoolean then
            pcall(frame.SetAlphaFromBoolean, frame, inRange, 1, FADED)
        end
    else
        pcall(frame.SetAlpha, frame, inRange and 1 or FADED)
    end
end

-- party portrait frames under every name the game has used
local function PartyFrame(i)
    return _G["PartyMemberFrame" .. i] or (_G.PartyFrame and _G.PartyFrame["MemberFrame" .. i])
end

local function FadeCompact(uf)
    if type(uf) ~= "table" or Forbidden(uf) then return end
    Fade(uf, Plain(uf.displayedUnit) or Plain(uf.unit))
end

local function FadeAll()
    for i = 1, 4 do Fade(PartyFrame(i), "party" .. i) end
    for i = 1, 5 do FadeCompact(_G["CompactPartyFrameMember" .. i]) end
    for i = 1, 40 do FadeCompact(_G["CompactRaidFrame" .. i]) end
    for g = 1, 8 do
        for m = 1, 5 do FadeCompact(_G["CompactRaidGroup" .. g .. "Member" .. m]) end
    end
end

-- the raid-style frames set their own 40-yard alpha; put ours back right after
if type(CompactUnitFrame_UpdateInRange) == "function" then
    hooksecurefunc("CompactUnitFrame_UpdateInRange", function(uf)
        if Enabled() then pcall(FadeCompact, uf) end
    end)
end

local ticker = CreateFrame("Frame")
local elapsed = 0
ticker:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < INTERVAL then return end
    elapsed = 0
    if not (IsInGroup and IsInGroup()) and not next(touched) then return end
    pcall(FadeAll)
end)

-- /bnav rangefade
local function ToggleRangeFade()
    DB().rangeFade = not Enabled()
    pcall(FadeAll)
    return DB().rangeFade
end

ns.AddCommand({ "rangefade", "range" }, function()
    ns.Print("Fading group members beyond 30 yards " .. (ToggleRangeFade() and "on" or "off") .. ".")
end, {
    "  /bnav rangefade       fade party/raid frames of group members farther than 30 yards (on/off)",
})

-- shared with the other BossNav files
