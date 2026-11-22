-- Where you are with a quest: already handed in ("done"), in your quest log
-- right now ("active"), or neither (nil). Asks the game each time; the
-- Quests tab and the map tooltips cross out the first two.
local ADDON, ns = ...
-- from the files loaded before this one
local IsSecret               = ns.IsSecret
local QuestLogIndex          = ns.QuestLogIndex
local QuestRealID            = ns.QuestRealID

-- Quests handed in this session. The game can be a moment late flagging a
-- quest complete, so the turn-in event is remembered here as well.
local turnedIn = {}

-- Calls the first of the named functions that exists; nil when none does,
-- it errors, or the answer is hidden from addons.
local function Ask(fns, ...)
    for _, fn in ipairs(fns) do
        if fn then
            local ok, v = pcall(fn, ...)
            if ok and not (IsSecret and IsSecret(v)) then return v end
        end
    end
    return nil
end

local QL = C_QuestLog or {}

local function IsDone(id)
    if turnedIn[id] then return true end
    return Ask({ QL.IsQuestFlaggedCompleted, IsQuestFlaggedCompleted }, id) == true
end

-- In the log: by quest ID, else by quest name (BossNav_QuestLog.lua).
local function IsActive(q)
    if Ask({ QL.IsOnQuest }, QuestRealID(q)) == true then return true end
    return QuestLogIndex(q) ~= nil
end

-- "done", "active" or nil for a quest row. The log is checked first, so a
-- name match can teach the real ID before the "done" check needs it.
local function QuestStatus(q)
    if not (q and q.id) then return nil end
    local active = IsActive(q)
    if IsDone(QuestRealID(q)) or IsDone(q.id) then return "done" end
    if active then return "active" end
    return nil
end

-- Called on QUEST_TURNED_IN with the quest ID.
local function OnQuestTurnedIn(id)
    if type(id) == "number" and not (IsSecret and IsSecret(id)) then turnedIn[id] = true end
end

-- Short words for the tag after a crossed-out quest.
local STATUS_WORD = { done = "done", active = "in log" }

-- shared with the other BossNav files
ns.OnQuestTurnedIn = OnQuestTurnedIn
ns.QuestStatus = QuestStatus
ns.QUEST_STATUS_WORD = STATUS_WORD
