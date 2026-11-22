-- Finds a quest row (from BossNav_QuestData.lua) in your quest log. Looks by
-- quest ID first, then by quest name: the IDs of the new Forever quests were
-- typed in from a guide and some do not match the game's. When the name finds
-- it, the game's real ID is remembered in BossNavDB.questIDs, so "done" and
-- the turn-in check work for that quest from then on.
local ADDON, ns = ...
-- from the files loaded before this one
local IsSecret               = ns.IsSecret
local DB                     = ns.DB

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

local function Plain(name)
    if type(name) ~= "string" then return nil end
    return (name:lower():gsub("^%s+", ""):gsub("%s+$", ""))
end

-- title, questID, isHeader of one quest log line (classic or modern API).
local function LogLine(i)
    if GetQuestLogTitle then
        local title, _, _, isHeader, _, _, _, qid = Safe(GetQuestLogTitle, i)
        if title then return title, qid, isHeader end
    end
    local info = Safe(QL.GetInfo, i)
    if type(info) == "table" then return info.title, info.questID, info.isHeader end
    return nil
end

local function NumLines()
    local n = Safe(GetNumQuestLogEntries)
    if type(n) ~= "number" then n = Safe(QL.GetNumQuestLogEntries) end
    return type(n) == "number" and n or 0
end

-- The game's ID for a quest row: the learned one, else the one in the data.
local function RealID(q)
    local learned = DB().questIDs
    return learned and learned[q.id] or q.id
end

-- Quest log line of a quest row, or nil when it is not in your log.
local function LogIndex(q)
    if not (q and q.id) then return nil end
    local id = RealID(q)
    local idx = Safe(QL.GetLogIndexForQuestID, id)
    if type(idx) == "number" and idx > 0 then return idx end
    local want = Plain(q.name)
    for i = 1, NumLines() do
        local title, qid, isHeader = LogLine(i)
        if not isHeader then
            if qid == id then return i end
            if want and Plain(title) == want then
                if type(qid) == "number" and qid ~= q.id then
                    local db = DB()
                    db.questIDs = db.questIDs or {}
                    db.questIDs[q.id] = qid
                end
                return i
            end
        end
    end
    return nil
end

-- True when a quest in your log has all its objectives done (ready to hand
-- in); false when not, or when it is not in your log.
local function LogComplete(q)
    local done = Safe(QL.IsComplete, RealID(q))
    if done == true then return true end
    local idx = LogIndex(q)
    if not idx then return false end
    if GetQuestLogTitle then
        local _, _, _, _, _, isComplete = Safe(GetQuestLogTitle, idx)
        if isComplete == 1 or isComplete == true then return true end
    end
    local info = Safe(QL.GetInfo, idx)
    return type(info) == "table" and info.isComplete == true
end

-- shared with the other BossNav files
ns.QuestLogComplete = LogComplete
ns.QuestLogIndex = LogIndex
ns.QuestRealID = RealID
