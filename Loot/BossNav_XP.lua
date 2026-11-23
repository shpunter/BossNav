-- Experience earned in the current dungeon.
local ADDON, ns = ...
-- from the files loaded before this one
local IsSecret               = ns.IsSecret
local TouchProgress          = ns.TouchProgress
local state                  = ns.state

--------------------------------------------------------------------------
-- XP tracking. Every gain of experience while inside a known dungeon (kills,
-- quest turn-ins, exploration) is added to state.xp, which is saved with the
-- dungeon progress like the gold total. A level-up inside the run is
-- counted too: the rest of the old level plus what is on the new bar.
-- Reading the bar is guarded against secret values.
--------------------------------------------------------------------------
local lastXP, lastMax = nil, nil   -- last non-secret reading

local function ReadNumber(fn)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, "player")
    if not ok or IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

-- Call when the XP bar may have changed (PLAYER_XP_UPDATE) and when entering the world.
local function OnXPChanged()
    local xp, max = ReadNumber(UnitXP), ReadNumber(UnitXPMax)
    if not xp or not max then return end
    if lastXP and state.cfg and state.inInstance and not state.testMode then
        local gain = 0
        if xp > lastXP then
            gain = xp - lastXP
        elseif xp < lastXP and lastMax then
            gain = (lastMax - lastXP) + xp   -- levelled up: bar started over
        end
        if gain > 0 then
            state.xp = (state.xp or 0) + gain
            TouchProgress()
        end
    end
    lastXP, lastMax = xp, max
end

-- "12,345" for big numbers.
local function Thousands(n)
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

-- Text for the HUD line under the gold; empty when nothing was earned.
local function XPText()
    local earned = state.xp or 0
    if earned <= 0 then return "" end
    return "   XP: |cffb48cff" .. Thousands(earned) .. "|r"
end

-- shared with the other BossNav files
ns.XPText = XPText
ns.XPEarned = function() return state.xp or 0 end
ns.Thousands = Thousands
ns.OnXPChanged = OnXPChanged
