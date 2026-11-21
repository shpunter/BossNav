-- Where you are with a quest: already handed in ("done"), in your quest log
-- right now ("active"), or neither (nil). Asks the game each time; the
-- Quests tab and the map tooltips cross out the first two.
local ADDON, ns = ...
-- from the files loaded before this one
local IsSecret               = ns.IsSecret

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

-- In the log: the modern lookup by quest ID, else walk the classic log.
local function IsActive(id)
    local idx = Ask({ QL.GetLogIndexForQuestID }, id)
    if type(idx) == "number" and idx > 0 then return true end
    if Ask({ QL.IsOnQuest }, id) == true then return true end
    if GetNumQuestLogEntries and GetQuestLogTitle then
        local ok, n = pcall(GetNumQuestLogEntries)
        if ok and type(n) == "number" then
            for i = 1, n do
                local ok2, _, _, _, isHeader, _, _, _, qid = pcall(GetQuestLogTitle, i)
                if ok2 and not isHeader and qid == id then return true end
            end
        end
    end
    return false
end

-- "done", "active" or nil for a quest row.
local function QuestStatus(q)
    if not (q and q.id) then return nil end
    if IsDone(q.id) then return "done" end
    if IsActive(q.id) then return "active" end
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
