-- Reads a quest's text and rewards straight from your quest log, when you
-- have the quest. The game's own numbers win over the built-in table in
-- BossNav_QuestText.lua (WoW Forever may have changed a reward), and this is
-- the only source for the new Forever quests the table does not have.
local ADDON, ns = ...
-- from the files loaded before this one
local IsSecret               = ns.IsSecret
local QuestLogIndex          = ns.QuestLogIndex
local QuestRealID            = ns.QuestRealID

local QL = C_QuestLog or {}

-- pcall that also turns a hidden ("secret") answer into nil.
local function Pass(ok, ...)
    if not ok then return nil end
    for i = 1, select("#", ...) do
        if IsSecret and IsSecret((select(i, ...))) then return nil end
    end
    return ...
end
local function Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    return Pass(pcall(fn, ...))
end

local function ItemID(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- One list of reward items ("choice" or "reward") from the selected log line.
local function ReadItems(kind, countFn, infoFn)
    local list = {}
    local n = Safe(countFn)
    if type(n) ~= "number" then return list end
    for i = 1, n do
        local name, icon, count, quality = Safe(infoFn, i)
        if name then
            list[#list + 1] = {
                id = ItemID(Safe(GetQuestLogItemLink, kind, i)),
                name = name, icon = icon, count = count or 1, quality = quality,
            }
        end
    end
    return list
end

-- { d = description, o = objectives, c = choice items, r = items,
--   m = money } for a quest in your log; nil when it is not there or the
-- client will not say. Items here carry name and icon already.
local function ReadQuestLog(q)
    local idx = QuestLogIndex(q)
    if not idx then return nil end
    -- the quest log answers about its selected line; select, read, put back
    local old = Safe(GetQuestLogSelection)
    if SelectQuestLogEntry then Safe(SelectQuestLogEntry, idx)
    else Safe(QL.SetSelectedQuest, QuestRealID(q)) end
    local info = {}
    info.d, info.o = Safe(GetQuestLogQuestText, idx)
    if not info.d then info.d, info.o = Safe(GetQuestLogQuestText) end
    info.c = ReadItems("choice", GetNumQuestLogChoices, GetQuestLogChoiceInfo)
    info.r = ReadItems("reward", GetNumQuestLogRewards, GetQuestLogRewardInfo)
    info.m = Safe(GetQuestLogRewardMoney)
    if type(old) == "number" and old > 0 then Safe(SelectQuestLogEntry, old) end
    if not (info.d or info.o) then return nil end
    info.live = true
    return info
end

-- shared with the other BossNav files
ns.ReadQuestLog = ReadQuestLog
