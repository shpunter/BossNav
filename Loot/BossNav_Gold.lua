-- Gold earned in the current dungeon.
local ADDON, ns = ...
-- from the files loaded before this one
local IsSecret               = ns.IsSecret
local TouchProgress          = ns.TouchProgress
local state                  = ns.state

--------------------------------------------------------------------------
-- Money tracking. Every increase of the purse while inside a known dungeon
-- (loot, vendoring, quest turn-ins) is added to state.gold, which is saved
-- with the dungeon progress so a death, relog or crash keeps the total.
-- Spending (repairs, vendors) is not subtracted: the number is what the run
-- brought in. Reading the purse is guarded against secret values.
--------------------------------------------------------------------------
local lastMoney = nil   -- copper, last non-secret reading

local function ReadMoney()
    if type(GetMoney) ~= "function" then return nil end
    local ok, m = pcall(GetMoney)
    if not ok or IsSecret(m) or type(m) ~= "number" then return nil end
    return m
end

-- Call when the purse may have changed (PLAYER_MONEY) and when entering the world.
local function OnMoneyChanged()
    local m = ReadMoney()
    if not m then return end
    if lastMoney and m > lastMoney and state.cfg and state.inInstance and not state.testMode then
        state.gold = (state.gold or 0) + (m - lastMoney)
        TouchProgress()
    end
    lastMoney = m
end

local function GoldEarned()
    return state.gold or 0
end

-- Coin icons, the same built-in textures the game's money frame and AtlasLoot
-- use. ":0" sizes the icon to the line height of whatever font shows it.
local GOLD_ICON   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:0|t"

-- "12[gold] 34[silver] 56[copper]" with the usual coin colours and a coin icon
-- after each number; copper is dropped once gold is reached.
local function MoneyText(copper)
    copper = math.floor(copper or 0)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = string.format("|cffffd700%d|r%s", g, GOLD_ICON) end
    if s > 0 or g > 0 then parts[#parts + 1] = string.format("|cffc7c7cf%d|r%s", s, SILVER_ICON) end
    if g == 0 then parts[#parts + 1] = string.format("|cffeda55f%d|r%s", c, COPPER_ICON) end
    return table.concat(parts, " ")
end

local function GoldText()
    local earned = GoldEarned()
    if earned <= 0 then return "No gold earned here yet." end
    return "Gold earned here: " .. MoneyText(earned)
end

-- shared with the other BossNav files
ns.GoldText = GoldText
ns.OnMoneyChanged = OnMoneyChanged
