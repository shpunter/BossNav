-- Experience a quest gives you, from its full XP (BossNav_QuestXP.lua) and
-- your level. WoW Forever's rule, as Questie works it out: the full amount
-- up to 5 levels above the quest, then 80%, 60% and at least 50%; nothing
-- at the top level. Rounded the way the game rounds it.
local ADDON, ns = ...
-- from the files loaded before this one
local PlayerLevel            = ns.PlayerLevel
local QUEST_XP               = ns.QUEST_XP
local Thousands              = ns.Thousands

local function Round(xp)
    if xp <= 100 then return 5 * math.floor((xp + 2) / 5) end
    if xp <= 500 then return 10 * math.floor((xp + 5) / 10) end
    if xp <= 1000 then return 25 * math.floor((xp + 12) / 25) end
    return 50 * math.floor((xp + 25) / 50)
end

local function MaxLevel()
    local ok, n = pcall(GetMaxPlayerLevel)
    return ok and type(n) == "number" and n or 60
end

-- XP the quest gives at your level (its full XP when the client will not
-- say your level); nil when the data has no XP for it.
local function QuestRewardXP(q)
    local entry = q and q.id and QUEST_XP[q.id]
    if not entry then return nil end
    local qlevel, xp = entry[1], entry[2]
    local myLevel = PlayerLevel()
    if not myLevel then return xp end
    if myLevel >= MaxLevel() then return 0 end
    local mult = math.max(5, math.min(10, 2 * (qlevel - myLevel) + 20))
    return Round(xp * mult / 10)
end

-- "8,450 XP" for the quest at your level, nil when unknown or none.
local function QuestXPText(q)
    local xp = QuestRewardXP(q)
    if not xp or xp <= 0 then return nil end
    return Thousands(xp) .. " XP"
end

-- shared with the other BossNav files
ns.QuestRewardXP = QuestRewardXP
ns.QuestXPText = QuestXPText
