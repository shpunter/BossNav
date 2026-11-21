-- Loot roll tracker: who chose Need / Greed / Pass on each group-loot item,
-- the number each one rolled, and who won. Read from the loot messages the
-- game prints in chat ("Bob has selected Need for: [item]",
-- "Need Roll - 87 for [item] by Bob", "Bob won: [item]").
-- Who is in the group and how names are shown comes from BossNav_Roster.lua.
local ADDON, ns = ...
-- from the files loaded before this one
local ClassOf                = ns.ClassOf
local ColorName              = ns.ColorName
local DB                     = ns.DB
local GROUP_UNITS            = ns.GROUP_UNITS
local IsSecret               = ns.IsSecret
local LinkName               = ns.LinkName
local PlayerName             = ns.PlayerName
local Print                  = ns.Print
local RefreshIfShown         = ns.RefreshIfShown
local ShortName              = ns.ShortName
local UnitNameClass          = ns.UnitNameClass

local MAX_ITEMS = 30          -- items kept in saved variables
local SHOW_ITEMS = 5          -- items printed by /bnav loot
local REUSE_WINDOW = 300      -- seconds: a second "selected" line for the same link within this window is the same drop
local MIN_QUALITY = 3         -- 0 grey, 1 white, 2 green, 3 blue, 4 purple: items below this are ignored

-- Item quality from the colour code at the start of the link (works even when
-- the item is not in the client's cache yet).
local LINK_QUALITY = {
    ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3,
    ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6, ["00ccff"] = 7,
}
local function Quality(link)
    -- old style "|cff1eff00|Hitem:..." : colour as hex
    local hex = link:match("^|c%x%x(%x%x%x%x%x%x)")
    if hex then
        local q = LINK_QUALITY[hex:lower()]
        if q then return q end
    end
    -- modern style "|cnIQ2:|Hitem:..." : named colour, the digit is the quality
    local named = link:match("^|cnIQ(%d+):")
    if named then return tonumber(named) end
    local ok, _, _, q = pcall(GetItemInfo, link)
    if ok and type(q) == "number" then return q end
    return nil
end

local warnedUnknownQuality = false
local function Wanted(link)
    local q = Quality(link)
    if q == nil then
        -- unknown quality: keep the item, and say so once so the link form can be fixed
        if not warnedUnknownQuality then
            warnedUnknownQuality = true
            Print("could not read the quality of " .. link .. " (kept it). Please report this line.")
        end
        return true
    end
    return q >= MIN_QUALITY
end

--------------------------------------------------------------------------
-- Chat message patterns, built from the game's own strings
--------------------------------------------------------------------------
-- Leading loot-history link of a chat line; the number is the same for every
-- line about one drop (selection, rolls, winner), so it identifies the drop.
local LOOT_PREFIX = "^|HlootHistory:(%d+)|h%[.-%]|h:%s*(.*)$"

-- Turns a global string such as "%s has selected Need for: %s" into a Lua
-- pattern with one capture per placeholder. Returns nil when the string is missing.
local function Pattern(global, fallback)
    local s = _G[global]
    if type(s) ~= "string" or s == "" then s = fallback end
    if not s then return nil end
    -- Modern clients prefix every loot line with a loot-history link,
    -- "|HlootHistory:%d|h[Loot]|h: ...". It is cut off here and from each
    -- incoming message (see LOOT_PREFIX) so the captures below line up.
    s = s:gsub("^|HlootHistory:%%d|h%[.-%]|h:%s*", "")
    s = s:gsub("%%(%d)%$([sd])", "%%%2")        -- "%1$s" -> "%s"
    s = s:gsub("([%(%)%.%[%]%+%-%*%?%^%$])", "%%%1")
    s = s:gsub("%%s", "(.+)")
    s = s:gsub("%%d", "(%%d+)")
    return "^" .. s .. "$"
end

-- { pattern, kind, order }; order says which capture is which: p=player, i=item, r=roll.
-- Specific lines come before general ones: "(.+) passed on: (.+)" would otherwise
-- also match "You passed on: ..." and "Bob automatically passed on: ... because ...".
local MESSAGES = {
    { Pattern("LOOT_ROLL_NEED_SELF",   "You have selected Need for: %s"),    "need",  "i",  self = true },
    { Pattern("LOOT_ROLL_GREED_SELF",  "You have selected Greed for: %s"),   "greed", "i",  self = true },
    { Pattern("LOOT_ROLL_DISENCHANT_SELF", "You have selected Disenchant for: %s"), "de", "i", self = true },
    { Pattern("LOOT_ROLL_PASSED_SELF_AUTO", "You automatically passed on: %s because you cannot loot that item."), "pass", "i", self = true },
    { Pattern("LOOT_ROLL_PASSED_SELF", "You passed on: %s"),                 "pass",  "i",  self = true },
    { Pattern("LOOT_ROLL_YOU_WON",     "You won: %s"),                       "won",   "i",  self = true },
    { Pattern("LOOT_ROLL_ALL_PASSED",  "Everyone passed on: %s"),            "allpass", "i" },
    { Pattern("LOOT_ROLL_NEED",        "%s has selected Need for: %s"),      "need",  "pi" },
    { Pattern("LOOT_ROLL_GREED",       "%s has selected Greed for: %s"),     "greed", "pi" },
    { Pattern("LOOT_ROLL_DISENCHANT",  "%s has selected Disenchant for: %s"),"de",    "pi" },
    { Pattern("LOOT_ROLL_PASSED_AUTO", "%s automatically passed on: %s because he cannot loot that item."), "pass", "pi" },
    { Pattern("LOOT_ROLL_PASSED_AUTO_FEMALE", "%s automatically passed on: %s because she cannot loot that item."), "pass", "pi" },
    { Pattern("LOOT_ROLL_PASSED",      "%s passed on: %s"),                  "pass",  "pi" },
    { Pattern("LOOT_ROLL_ROLLED_NEED", "Need Roll - %d for %s by %s"),       "roll",  "rip", rollKind = "need" },
    { Pattern("LOOT_ROLL_ROLLED_GREED","Greed Roll - %d for %s by %s"),      "roll",  "rip", rollKind = "greed" },
    { Pattern("LOOT_ROLL_ROLLED_DE",   "Disenchant Roll - %d for %s by %s"), "roll",  "rip", rollKind = "de" },
    { Pattern("LOOT_ROLL_WON",         "%s won: %s"),                        "won",   "pi" },
}

--------------------------------------------------------------------------
-- Storage
--------------------------------------------------------------------------
local function Items()
    local db = DB()
    db.loot = db.loot or {}
    if db.lootAnnounce == nil then db.lootAnnounce = true end
    -- drop entries whose "item" is not an item link (recorded by an older version)
    for i = #db.loot, 1, -1 do
        local key = db.loot[i].key
        if type(key) ~= "string" or not key:find("^item:") then table.remove(db.loot, i) end
    end
    return db.loot
end

local function ItemKey(link)
    return link:match("|H(item:[^|]+)|h") or link
end

-- The drop these lines belong to: matched by the loot-history ID when the
-- client gives one, otherwise the newest unresolved drop of this link.
local function Drop(link, create, rollID)
    local items = Items()
    local key = ItemKey(link)
    local now = time()
    for i = #items, 1, -1 do
        local it = items[i]
        if rollID and it.rollID then
            if it.rollID == rollID then return it end
        elseif it.key == key and not it.winner and not it.allPassed and (now - (it.time or 0)) < REUSE_WINDOW then
            return it
        end
    end
    if not create then return nil end
    local it = { key = key, link = link, time = now, rolls = {}, rollID = rollID }
    items[#items + 1] = it
    while #items > MAX_ITEMS do table.remove(items, 1) end
    return it
end

local function Entry(it, player)
    player = ShortName(player)
    if not it.rolls[player] then
        it.rolls[player] = { class = ClassOf(player) }
    end
    return it.rolls[player]
end

--------------------------------------------------------------------------
-- Formatting
--------------------------------------------------------------------------
local KIND_LABEL = { need = "Need", greed = "Greed", de = "DE", pass = "Pass" }
local KIND_COLOR = { need = "ff4040", greed = "40c040", de = "c080ff", pass = "888888" }
local KIND_ORDER = { "need", "greed", "de", "pass" }

local function SortedRolls(it, kind)
    local list = {}
    for name, r in pairs(it.rolls) do
        if r.kind == kind then
            if not r.class then r.class = ClassOf(name) end   -- retry: the roster may answer now
            list[#list + 1] = { name = name, roll = r.roll, class = r.class }
        end
    end
    table.sort(list, function(a, b)
        if (a.roll or -1) ~= (b.roll or -1) then return (a.roll or -1) > (b.roll or -1) end
        return a.name < b.name
    end)
    return list
end

local function RollsLine(it)
    local parts = {}
    for _, kind in ipairs(KIND_ORDER) do
        local list = SortedRolls(it, kind)
        if #list > 0 then
            local names = {}
            for _, r in ipairs(list) do
                local won = r.name == it.winner
                names[#names + 1] = LinkName(r.name, r.class) .. (r.roll and (" " .. r.roll) or "") .. (won and " |cffffd100(won)|r" or "")
            end
            parts[#parts + 1] = string.format("|cff%s%s:|r %s", KIND_COLOR[kind], KIND_LABEL[kind], table.concat(names, ", "))
        end
    end
    if #parts == 0 then return "|cff888888no rolls yet|r" end
    return table.concat(parts, "   ")
end

-- Class of the winner, looked up again when it was unknown at the time of the win
local function WinnerClass(it)
    if not it.winner then return nil end
    if not it.winnerClass then
        local e = it.rolls[it.winner]
        it.winnerClass = (e and e.class) or ClassOf(it.winner)
    end
    return it.winnerClass
end

local function PrintDrop(it)
    local status
    if it.winner then
        status = "  |cffffd100won by|r " .. LinkName(it.winner, WinnerClass(it))
    elseif it.allPassed then
        status = "  |cff888888everyone passed|r"
    else
        status = "  |cff888888rolling...|r"
    end
    Print(it.link .. status)
    Print("    " .. RollsLine(it))
end

local function ShowLoot(count)
    local items = Items()
    count = count or SHOW_ITEMS
    if #items == 0 then Print("No loot rolls seen yet.") return end
    Print(string.format("Last %d loot rolls (newest first):", math.min(count, #items)))
    for i = #items, math.max(1, #items - count + 1), -1 do
        PrintDrop(items[i])
    end
end

--------------------------------------------------------------------------
-- Message handling
--------------------------------------------------------------------------
local function OnLootMessage(msg)
    if type(msg) ~= "string" or IsSecret(msg) then return end
    -- cut the "|HlootHistory:123|h[Loot]|h: " prefix, keeping its ID
    local rollID, body = msg:match(LOOT_PREFIX)
    if body then msg = body end
    for _, m in ipairs(MESSAGES) do
        local pat, kind, order = m[1], m[2], m[3]
        if pat then
            local a, b, c = msg:match(pat)
            if a then
                local caps = { a, b, c }
                local player, link, roll
                for i = 1, #order do
                    local ch = order:sub(i, i)
                    if ch == "p" then player = caps[i]
                    elseif ch == "i" then link = caps[i]
                    elseif ch == "r" then roll = tonumber(caps[i]) end
                end
                if m.self then player = PlayerName() end
                if not link or not Wanted(link) then return end

                local it = Drop(link, true, rollID)
                if kind == "won" then
                    it.winner = ShortName(player)
                    local e = it.rolls[it.winner]
                    it.winnerClass = (e and e.class) or ClassOf(player)
                    if DB().lootAnnounce then PrintDrop(it) end
                elseif kind == "allpass" then
                    it.allPassed = true
                elseif kind == "roll" then
                    local e = Entry(it, player)
                    e.roll = roll
                    e.kind = m.rollKind or e.kind
                else
                    local e = Entry(it, player)
                    e.kind = kind
                end
                RefreshIfShown()   -- the Loot tab, if open, shows the new roll at once
                return it          -- the drop this line was about (the roll popup shows it)
            end
        end
    end
end

-- Forget every recorded roll (also called when you leave the group)
local function ClearLoot()
    local items = Items()
    for i = #items, 1, -1 do items[i] = nil end
    RefreshIfShown()
end

local function LootCommand(rest)
    rest = (rest or ""):lower()
    if rest == "clear" then
        ClearLoot()
        Print("Loot roll history cleared.")
    elseif rest == "auto" then
        DB().lootAnnounce = not DB().lootAnnounce
        Print("Loot roll summary after each win " .. (DB().lootAnnounce and "on" or "off") .. ".")
    elseif rest == "who" then
        -- diagnostics: how the group roster looks to the addon
        Print("Group as seen by BossNav:")
        local any = false
        for _, unit in ipairs(GROUP_UNITS) do
            local okE, exists = pcall(UnitExists, unit)
            if okE and exists == true then
                any = true
                local name, class = UnitNameClass(unit)
                Print(string.format("  %s: %s  %s", unit, name or "|cffff4444name hidden|r",
                    class and ColorName(name or "?", class) or "|cffff4444class hidden|r"))
            end
        end
        if not any then Print("  not in a group") end
    elseif rest == "all" then
        ShowLoot(MAX_ITEMS)
    else
        ShowLoot(tonumber(rest) or SHOW_ITEMS)
    end
end

-- shared with the other BossNav files
ns.ClearLoot = ClearLoot
ns.LOOT_KIND_COLOR = KIND_COLOR
ns.LOOT_KIND_LABEL = KIND_LABEL
ns.LOOT_KIND_ORDER = KIND_ORDER
ns.LootCommand = LootCommand
ns.LootItems = Items
ns.LootSortedRolls = SortedRolls
ns.LootWinnerClass = WinnerClass
ns.OnLootMessage = OnLootMessage
