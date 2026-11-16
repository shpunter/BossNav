-- Profession tracker: how many times each group member mined, gathered herbs,
-- skinned, fished, disenchanted, picked a lock or crafted something. Counted
-- from the spell casts the game reports for group units
-- (UNIT_SPELLCAST_SUCCEEDED): every gather and every recipe is a spell cast.
-- The combat log is not used: this client blocks it for addons.
local ADDON, ns = ...
-- from the files loaded before this one
local ChatChannel            = ns.ChatChannel
local ClassOf                = ns.ClassOf
local ClassText              = ns.ClassText
local DB                     = ns.DB
local IsSecret               = ns.IsSecret
local LinkName               = ns.LinkName
local Plain                  = ns.Plain
local Print                  = ns.Print
local RefreshIfShown         = ns.RefreshIfShown
local SetTab                 = ns.SetTab
local ShortName              = ns.ShortName
local UnitNameClass          = ns.UnitNameClass
local state                  = ns.state

local MAX_POST_LINES = 10     -- members posted to group chat at most
local DOUBLE_WINDOW = 0.3     -- seconds: the same cast reported twice (e.g. as "player" and "raid3")

--------------------------------------------------------------------------
-- Which profession a spell belongs to
--------------------------------------------------------------------------
-- Gathering and secondary skills: the cast carries the skill's own name.
local SKILL_BY_NAME = {
    ["Mining"] = "Mining", ["Herb Gathering"] = "Herbalism", ["Herbalism"] = "Herbalism",
    ["Skinning"] = "Skinning", ["Fishing"] = "Fishing",
    ["Disenchant"] = "Enchanting", ["Prospecting"] = "Jewelcrafting", ["Milling"] = "Inscription",
    ["Pick Lock"] = "Lockpicking", ["Survey"] = "Archaeology",
}
-- The same skills by spell ID (every rank), used when the name cannot be read.
local SKILL_BY_ID = {}
local function Ids(prof, list) for _, id in ipairs(list) do SKILL_BY_ID[id] = prof end end
Ids("Mining",        { 2575, 2576, 3564, 10248, 29354, 50310, 74517, 102161, 158754, 195122, 265837 })
Ids("Herbalism",     { 2366, 2368, 3570, 11993, 28695, 50300, 74519, 110413, 158745, 195114, 265819 })
Ids("Skinning",      { 8613, 8617, 8618, 10768, 32678, 50305, 74522, 102216, 158756, 195125, 265856 })
Ids("Fishing",       { 7620, 7731, 7732, 18248, 33095, 51294, 88868, 110410, 158743, 195117, 271990 })
Ids("Enchanting",    { 13262 })
Ids("Jewelcrafting", { 31252 })
Ids("Inscription",   { 51005 })
Ids("Lockpicking",   { 1804 })
Ids("Archaeology",   { 80451 })

-- Crafts whose name says the profession
local NAME_RULES = {
    { "^Smelt ", "Mining" },
    { "^Enchant ", "Enchanting" },
    { " Bandage$", "First Aid" },
}

-- Profession skill lines of the game, by ID: a recipe reported under one of
-- these (or under a sub-line whose parent is one of these) is a craft.
local PROF_LINES = {
    [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering",
    [182] = "Herbalism", [773] = "Inscription", [755] = "Jewelcrafting", [165] = "Leatherworking",
    [186] = "Mining", [393] = "Skinning", [197] = "Tailoring", [185] = "Cooking",
    [129] = "First Aid", [356] = "Fishing", [794] = "Archaeology", [633] = "Lockpicking", [40] = "Poisons",
}

-- Display order of the professions in the window and in chat
local PROF_ORDER = { "Mining", "Herbalism", "Skinning", "Fishing", "Cooking", "First Aid",
    "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Leatherworking", "Tailoring",
    "Jewelcrafting", "Inscription", "Archaeology", "Lockpicking", "Poisons" }
local PROF_RANK = {}
for i, p in ipairs(PROF_ORDER) do PROF_RANK[p] = i end

-- Name and icon of a spell, nil when the client does not tell
local function SpellInfo(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" and Plain(info.name) then
            local icon = info.iconID
            if IsSecret(icon) or type(icon) ~= "number" then icon = nil end
            return info.name, icon
        end
    end
    if GetSpellInfo then
        local ok, name, _, icon = pcall(GetSpellInfo, spellID)
        if ok and Plain(name) then
            if IsSecret(icon) or type(icon) ~= "number" then icon = nil end
            return name, icon
        end
    end
    return nil
end

-- Profession of a recipe spell from the trade skill data of the client, nil
-- when the API is missing or the spell is not a recipe of a known profession.
local function TradeSkillOf(spellID)
    if not (C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLineForRecipe) then return nil end
    local ok, lineID, _, parentID = pcall(C_TradeSkillUI.GetTradeSkillLineForRecipe, spellID)
    if not ok then return nil end
    if not IsSecret(lineID) and type(lineID) == "number" and PROF_LINES[lineID] then return PROF_LINES[lineID] end
    if not IsSecret(parentID) and type(parentID) == "number" and PROF_LINES[parentID] then return PROF_LINES[parentID] end
    return nil
end

-- spellID -> { profession, spell name, icon }, or false when it is no profession spell
local classified = {}
local function Classify(spellID)
    local c = classified[spellID]
    if c == false then return nil end
    if c then return c[1], c[2], c[3] end
    local name, icon = SpellInfo(spellID)
    local prof = (name and SKILL_BY_NAME[name]) or SKILL_BY_ID[spellID]
    if not prof and name then
        for _, rule in ipairs(NAME_RULES) do
            if name:find(rule[1]) then prof = rule[2] break end
        end
    end
    if not prof then prof = TradeSkillOf(spellID) end
    if not prof then
        if name then classified[spellID] = false end   -- unnamed spells are retried: the client may know them later
        return nil
    end
    classified[spellID] = { prof, name or prof, icon }
    return prof, name or prof, icon
end

--------------------------------------------------------------------------
-- Storage: one record per member, in the order they were first seen
--   { name, class, total, profs = { Mining = 12 }, spells = { ["Smelt Copper"] = 3 } }
--------------------------------------------------------------------------
local function Members()
    local db = DB()
    db.profs = db.profs or {}
    db.profIcons = db.profIcons or {}   -- profession -> spell icon, for the window
    return db.profs
end

local function Member(name, class, create)
    local list = Members()
    for i, m in ipairs(list) do
        if m.name == name then
            if class and not m.class then m.class = class end
            return m, i
        end
    end
    if not create then return nil end
    local m = { name = name, class = class or ClassOf(name), total = 0, profs = {}, spells = {} }
    list[#list + 1] = m
    return m, #list
end

local function Record(name, class, prof, spellName, icon, isSkill)
    local m = Member(name, class, true)
    m.total = (m.total or 0) + 1
    m.profs[prof] = (m.profs[prof] or 0) + 1
    m.spells[spellName] = (m.spells[spellName] or 0) + 1
    local icons = DB().profIcons
    if icon and (isSkill or not icons[prof]) then icons[prof] = icon end
    RefreshIfShown()
end

-- Every profession anyone used, in display order
local function ProfList()
    local seen, list = {}, {}
    for _, m in ipairs(Members()) do
        for prof in pairs(m.profs) do
            if not seen[prof] then seen[prof] = true; list[#list + 1] = prof end
        end
    end
    table.sort(list, function(a, b)
        local ra, rb = PROF_RANK[a] or 99, PROF_RANK[b] or 99
        if ra ~= rb then return ra < rb end
        return a < b
    end)
    return list
end

-- Sum of all counted actions of all members
local function TotalActions()
    local n = 0
    for _, m in ipairs(Members()) do n = n + (m.total or 0) end
    return n
end

--------------------------------------------------------------------------
-- The cast event
--------------------------------------------------------------------------
local seenCasts = {}     -- castGUID -> time first seen
local seenCount = 0
local lastCast = {}      -- "name:spellID" -> time

local function Duplicate(name, spellID, castGUID)
    local now = GetTime()
    if castGUID then
        if seenCasts[castGUID] then return true end
        seenCasts[castGUID] = now
        seenCount = seenCount + 1
        if seenCount > 300 then
            for guid, t in pairs(seenCasts) do
                if now - t > 60 then seenCasts[guid] = nil end
            end
            seenCount = 0
        end
    end
    local key = name .. ":" .. spellID
    if lastCast[key] and now - lastCast[key] < DOUBLE_WINDOW then return true end
    lastCast[key] = now
    return false
end

-- UNIT_SPELLCAST_SUCCEEDED: unit, castGUID, spellID (older clients: unit, name, rank, lineID, spellID)
local function OnUnitSpellcast(unit, castGUID, spellID, _, oldSpellID)
    if IsSecret(unit) or type(unit) ~= "string" then return end
    if not (unit == "player" or unit:find("^party%d+$") or unit:find("^raid%d+$")) then return end
    if IsSecret(spellID) or type(spellID) ~= "number" then spellID = oldSpellID end
    if IsSecret(spellID) or type(spellID) ~= "number" then return end
    if IsSecret(castGUID) or type(castGUID) ~= "string" then castGUID = nil end
    local prof, spellName, icon = Classify(spellID)
    if DB().profDebug then
        local dname = UnitNameClass(unit)
        local sname = SpellInfo(spellID)
        Print(string.format("cast: %s (%s) %s [%d] -> %s", tostring(dname or "?"), unit, tostring(sname or "?"), spellID,
            prof and ("|cff00ff00" .. prof .. "|r") or "|cff888888not a profession|r"))
    end
    if not prof then return end
    local name, class = UnitNameClass(unit)
    if not name then return end
    name = ShortName(name)
    if Duplicate(name, spellID, castGUID) then return end
    Record(name, class, prof, spellName, icon, SKILL_BY_NAME[spellName] ~= nil)
end

--------------------------------------------------------------------------
-- Text output
--------------------------------------------------------------------------
-- "Mining 12, Skinning 3" for one member
local function ProfsText(m, rich)
    local parts = {}
    for _, prof in ipairs(ProfList()) do
        local n = m.profs[prof]
        if n then parts[#parts + 1] = rich and (prof .. " |cffffffff" .. n .. "|r") or (prof .. " " .. n) end
    end
    return table.concat(parts, ", ")
end

local function MemberLine(m, rich)
    if rich then return LinkName(m.name, m.class) .. ": " .. ProfsText(m, true) end
    local cls = ClassText(m.class)
    return m.name .. (cls and (" (" .. cls .. ")") or "") .. ": " .. ProfsText(m, false)
end

-- Members with the most actions first
local function Ranked()
    local list = {}
    for i, m in ipairs(Members()) do list[#list + 1] = { m = m, i = i } end
    table.sort(list, function(a, b)
        if (a.m.total or 0) ~= (b.m.total or 0) then return (a.m.total or 0) > (b.m.total or 0) end
        return a.i < b.i
    end)
    return list
end

local function ShowProfs()
    local ranked = Ranked()
    if #ranked == 0 then Print("No profession use seen yet.") return end
    Print("Professions used by the group:")
    for _, e in ipairs(ranked) do Print("  " .. MemberLine(e.m, true)) end
end

-- Details of one member: every spell they used, most used first
local function ShowMember(idx)
    local m = Members()[idx]
    if not m then Print("No member number " .. tostring(idx) .. " (see the Profs tab).") return end
    Print(string.format("%s: %d actions. %s", LinkName(m.name, m.class), m.total or 0, ProfsText(m, true)))
    local list = {}
    for spell, n in pairs(m.spells) do list[#list + 1] = { spell = spell, n = n } end
    table.sort(list, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.spell < b.spell
    end)
    for _, e in ipairs(list) do Print(string.format("    %dx %s", e.n, e.spell)) end
end

-- Post the summary to party / raid chat (or print it alone)
local function PostProfs()
    local ranked = Ranked()
    if #ranked == 0 then Print("No profession use to post.") return end
    local chan = ChatChannel()
    local lines = { "Professions this run (" .. TotalActions() .. " actions):" }
    for i, e in ipairs(ranked) do
        if i > MAX_POST_LINES then
            lines[#lines + 1] = "... and " .. (#ranked - MAX_POST_LINES) .. " more"
            break
        end
        lines[#lines + 1] = MemberLine(e.m, chan == nil)
    end
    for _, line in ipairs(lines) do
        if chan then
            local ok, err = pcall(SendChatMessage, line:sub(1, 250), chan)
            if not ok then Print("could not post to chat: " .. tostring(err)) return end
        else
            Print(line)
        end
    end
end

-- Forget every count (also called when you leave the group)
local function ClearProfs()
    local list = Members()
    for i = #list, 1, -1 do list[i] = nil end
    state.profIdx = 1
    RefreshIfShown()
end

local function ProfCommand(rest)
    rest = (rest or ""):lower()
    local n = tonumber(rest)
    if rest == "" then
        SetTab("prof")
    elseif n then
        state.profIdx = n
        SetTab("prof")
        ShowMember(n)
    elseif rest == "post" then
        PostProfs()
    elseif rest == "list" then
        ShowProfs()
    elseif rest == "clear" then
        ClearProfs()
        Print("Profession counts cleared.")
    elseif rest == "debug" then
        DB().profDebug = not DB().profDebug
        Print("Cast debug " .. (DB().profDebug and "on: every group cast is printed with its spell ID and how it was classified." or "off."))
    else
        Print("Usage: /bnav prof [n | list | post | clear | debug]")
    end
end

-- shared with the other BossNav files
ns.ClearProfs = ClearProfs
ns.OnUnitSpellcast = OnUnitSpellcast
ns.PostProfs = PostProfs
ns.ProfCommand = ProfCommand
ns.ProfList = ProfList
ns.ProfMembers = Members
ns.ProfTotalActions = TotalActions
