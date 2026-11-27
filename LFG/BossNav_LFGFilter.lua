-- Group finder role filter: keep only the players who listed one of the
-- checked roles (tank, healer, dps). A player who listed several roles stays
-- when any of them is checked; nothing checked shows everyone. A single
-- player's roles come from C_LFGList.GetSearchResultLeaderInfo (.lfgRoles);
-- a group stays only when a member already plays a checked role
-- (C_LFGList.GetSearchResultMemberCounts).
-- Keyboard use: /bnav lfg [tank|heal|dps|off], /bnav lfg list, invite, whisper.
local ADDON, ns = ...
-- from the files loaded before this one
local AddCommand             = ns.AddCommand
local DB                     = ns.DB
local IsSecret               = ns.IsSecret
local Print                  = ns.Print

local ROLES  = { "tank", "healer", "dps" }
local LABEL  = { tank = "Tank", healer = "Healer", dps = "DPS" }
local PLURAL = { tank = "tanks", healer = "healers", dps = "DPS" }
local WORDS  = {
    tank = "tank", tanks = "tank",
    heal = "healer", heals = "healer", healer = "healer", healers = "healer",
    dps = "dps", damage = "dps", dd = "dps",
}

BINDING_NAME_BOSSNAV_LFG_ROLE = "Group Finder Role Filter: Off / Tank / Healer / DPS"

local function Plain(v)
    if IsSecret(v) then return nil end
    return v
end

-- the checked roles, saved: { tank = true, healer = true, ... }
local function Checked()
    local db = DB()
    if type(db.lfgRoles) ~= "table" then
        db.lfgRoles = {}
        if db.lfgRole then db.lfgRoles[db.lfgRole] = true end   -- earlier single-role setting
        db.lfgRole = nil
    end
    return db.lfgRoles
end

-- true while at least one role is checked
local function Wanted()
    return next(Checked()) ~= nil
end

local function IsChecked(role)
    return Checked()[role] == true
end

local function LeaderInfo(resultID)
    if not (C_LFGList and C_LFGList.GetSearchResultLeaderInfo) then return nil end
    local ok, info = pcall(C_LFGList.GetSearchResultLeaderInfo, resultID)
    if ok and type(info) == "table" then return info end
end

local function MemberCount(resultID)
    if not (C_LFGList and C_LFGList.GetSearchResultInfo) then return 1 end
    local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
    return ok and type(info) == "table" and Plain(info.numMembers) or 1
end

-- the game's member-count key for each role
local COUNT_KEY = { tank = "TANK", healer = "HEALER", dps = "DAMAGER" }

-- for a group: true / false when a member does / does not play that role,
-- nil when the game does not say
local function GroupHas(resultID, role)
    if not (C_LFGList and C_LFGList.GetSearchResultMemberCounts) then return nil end
    local ok, counts = pcall(C_LFGList.GetSearchResultMemberCounts, resultID)
    if not (ok and type(counts) == "table") then return nil end
    local have = Plain(counts[COUNT_KEY[role]])
    if type(have) == "number" then return have > 0 end
    return nil
end

-- true when the listing should stay visible under the current filter.
-- A group stays when one of its members plays a checked role (Heal ticked ->
-- groups that already have a healer); a single player stays when they listed
-- one of the checked roles. Anything that cannot be read stays visible.
local function Matches(resultID)
    if not Wanted() then return true end
    if MemberCount(resultID) > 1 then
        local unknown = false
        for role in pairs(Checked()) do
            local has = GroupHas(resultID, role)
            if has == true then return true end
            if has == nil then unknown = true end
        end
        if not unknown then return false end
    end
    local info = LeaderInfo(resultID)
    local roles = info and info.lfgRoles
    if type(roles) ~= "table" then return true end
    for role in pairs(Checked()) do
        if Plain(roles[role]) == true then return true end
    end
    return false
end

local function RoleText(roles)
    local t = {}
    for _, r in ipairs(ROLES) do
        if type(roles) == "table" and Plain(roles[r]) == true then t[#t + 1] = LABEL[r] end
    end
    return #t > 0 and table.concat(t, "/") or "?"
end

local function FilterText()
    local t = {}
    for _, r in ipairs(ROLES) do
        if IsChecked(r) then t[#t + 1] = PLURAL[r] end
    end
    return #t > 0 and table.concat(t, " + ") or "everyone"
end

local function SearchResults()
    if not (C_LFGList and C_LFGList.GetSearchResults) then return {} end
    local ok, _, results = pcall(C_LFGList.GetSearchResults)
    return ok and type(results) == "table" and results or {}
end

-- the last printed list, so "/bnav lfg invite 3" means line 3 of it
local shown = {}

local function CollectMatches()
    wipe(shown)
    local total = 0
    for _, id in ipairs(SearchResults()) do
        total = total + 1
        if Matches(id) then
            local info = LeaderInfo(id)
            local name = info and Plain(info.name)
            if name then
                shown[#shown + 1] = {
                    name = name, level = info and Plain(info.level),
                    roles = info and info.lfgRoles, members = MemberCount(id),
                }
            end
        end
    end
    return total
end

local function ListMatches()
    local total = CollectMatches()
    if total == 0 then
        Print("No group finder results yet. Open Looking For Group and search a dungeon first.")
        return
    end
    Print(string.format("Group finder (%s): %d of %d listings.", FilterText(), #shown, total))
    for i, e in ipairs(shown) do
        Print(string.format("  %d. |cffffd100%s|r%s  %s%s", i, e.name,
            e.level and (" lvl " .. e.level) or "", RoleText(e.roles),
            (e.members or 1) > 1 and string.format("  (group of %d)", e.members) or ""))
    end
    Print("  /bnav lfg invite N  or  /bnav lfg w N message")
end

-- after any change: redraw the window and the checkboxes, say what is shown
local function Changed()
    Print("Group finder shows: " .. FilterText() .. ".")
    if ns.RefreshLFGWindow then ns.RefreshLFGWindow() end
    if ns.RefreshLFGChecks then ns.RefreshLFGChecks() end
end

local function ToggleRole(role)
    local checked = Checked()
    checked[role] = (not checked[role]) or nil
    Changed()
end

local function ClearRoles()
    wipe(Checked())
    Changed()
end

-- keybind: off -> only tanks -> only healers -> only DPS -> off
function BossNav_CycleLFGRole()
    local checked = Checked()
    local cur
    for _, r in ipairs(ROLES) do
        if checked[r] then cur = r break end
    end
    local nxt = not cur and ROLES[1] or nil
    for i, r in ipairs(ROLES) do
        if r == cur then nxt = ROLES[i + 1] end
    end
    wipe(checked)
    if nxt then checked[nxt] = true end
    Changed()
end

-- "3" -> name on line 3 of the last list; anything else is taken as a name
local function PickName(arg)
    local n = tonumber(arg)
    if n then
        if #shown == 0 then CollectMatches() end
        return shown[n] and shown[n].name
    end
    return arg ~= "" and arg or nil
end

local function Invite(arg)
    local name = PickName(arg)
    if not name then Print("Usage: /bnav lfg invite N (line N of /bnav lfg list) or a name.") return end
    local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    local ok, err = pcall(invite, name)
    Print(ok and ("Invited " .. name .. ".") or ("Invite failed: " .. tostring(err)))
end

local function Whisper(arg)
    local who, msg = arg:match("^(%S+)%s+(.+)$")
    local name = who and PickName(who)
    if not (name and msg) then Print("Usage: /bnav lfg w N your message") return end
    SendChatMessage(msg, "WHISPER", nil, name)
end

local function LFGCommand(rest)
    local word, arg = rest:match("^(%S*)%s*(.-)$")
    word = (word or ""):lower()
    if word == "" then
        BossNav_CycleLFGRole()
    elseif WORDS[word] then
        ToggleRole(WORDS[word])
    elseif word == "off" or word == "all" or word == "none" then
        ClearRoles()
    elseif word == "list" or word == "ls" then
        ListMatches()
    elseif word == "invite" or word == "inv" then
        Invite(arg)
    elseif word == "w" or word == "whisper" then
        Whisper(arg)
    elseif word == "window" then
        if ns.LFGWindowReport then ns.LFGWindowReport() end
    else
        Print("Group finder shows: " .. FilterText() .. ". Try /bnav lfg heal, /bnav lfg list.")
    end
end

AddCommand({ "lfg", "lfr", "role" }, LFGCommand, {
    "  /bnav lfg             group finder role filter: off -> tanks -> healers -> DPS -> off (also a keybind)",
    "  /bnav lfg tank|heal|dps  tick / untick that role (same as the checkboxes); /bnav lfg off shows everyone",
    "  /bnav lfg list        print the matching players, numbered",
    "  /bnav lfg invite N    invite line N of that list; /bnav lfg w N text whispers them",
})

-- after each search, say how many match, so no clicking is needed to know
local events = CreateFrame("Frame")
pcall(events.RegisterEvent, events, "LFG_LIST_SEARCH_RESULTS_RECEIVED")
events:SetScript("OnEvent", function()
    if not Wanted() then return end
    local total = CollectMatches()
    if total > 0 then
        Print(string.format("Group finder: %d of %d listings are %s (/bnav lfg list).",
            #shown, total, FilterText()))
    end
end)

-- shared with the other BossNav files
ns.LFGIsChecked = IsChecked
ns.LFGMatches = Matches
ns.LFGRoleWanted = Wanted
ns.LFGToggleRole = ToggleRole
