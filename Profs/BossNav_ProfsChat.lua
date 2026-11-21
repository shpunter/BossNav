-- Profession tracker, chat fallback for teammates. This client hides the
-- spell of other players' casts (UNIT_SPELLCAST_SUCCEEDED gives a secret
-- spell ID), so their gathers and crafts are read from the group chat lines
-- instead, which are plain text:
--   "Bob receives loot: [Copper Ore]."   (CHAT_MSG_LOOT)       -> Mining
--   "Bob creates [Linen Bandage]."       (CHAT_MSG_TRADESKILLS) -> First Aid
-- The item type says the profession. Your own actions still come from your
-- casts (BossNav_Profs.lua); if a teammate's cast is ever readable, this
-- fallback switches itself off so nothing is counted twice.
local ADDON, ns = ...
-- from the files loaded before this one
local ClassOf                = ns.ClassOf
local DB                     = ns.DB
local IsSecret               = ns.IsSecret
local PlayerName             = ns.PlayerName
local Print                  = ns.Print
local ProfRecord             = ns.ProfRecord
local ShortName              = ns.ShortName
local state                  = ns.state

local GATHER_WINDOW = 3       -- seconds: ore + stone + gem from one node count as one gather

-- Global string such as "%s receives loot: %s." as a Lua pattern, nil when missing
local function Pattern(global, fallback)
    local s = _G[global]
    if type(s) ~= "string" or s == "" then s = fallback end
    if not s then return nil end
    s = s:gsub("^|HlootHistory:%%d|h%[.-%]|h:%s*", "")
    s = s:gsub("%%(%d)%$([sd])", "%%%2")
    s = s:gsub("([%(%)%.%[%]%+%-%*%?%^%$])", "%%%1")
    s = s:gsub("%%s", "(.+)")
    s = s:gsub("%%d", "(%%d+)")
    return "^" .. s .. "$"
end

-- Third-person lines only: your own ("You receive loot") come from your casts.
local LOOT_LINES = {
    Pattern("LOOT_ITEM_MULTIPLE", "%s receives loot: %sx%d."),
    Pattern("LOOT_ITEM", "%s receives loot: %s."),
}
local CRAFT_LINES = {
    Pattern("TRADESKILL_LOG_THIRDPERSON_MULTIPLE", "%s creates %sx%d."),
    Pattern("TRADESKILL_LOG_THIRDPERSON", "%s creates %s."),
}

-- Item class and subclass IDs of the game (Enum.ItemClass / subclass enums)
local CONSUMABLE, WEAPON, ARMOR, TRADEGOODS = 0, 2, 4, 7

-- A looted item that only comes from gathering: trade goods by subclass
local GATHERED = { [7] = "Mining", [9] = "Herbalism", [6] = "Skinning" }

-- A crafted item: profession by class, then subclass; "Crafting" when unclear
local CRAFTED = {
    [CONSUMABLE] = { [1] = "Alchemy", [2] = "Alchemy", [3] = "Alchemy", [5] = "Cooking", [7] = "First Aid" },
    [WEAPON]     = { [3] = "Engineering", default = "Blacksmithing" },
    [ARMOR]      = { [1] = "Tailoring", [2] = "Leatherworking", [3] = "Blacksmithing", [4] = "Blacksmithing" },
    [TRADEGOODS] = { [1] = "Engineering", [2] = "Engineering", [3] = "Engineering", [5] = "Tailoring",
                     [6] = "Leatherworking", [7] = "Mining", [12] = "Enchanting" },
}

-- name, icon, classID, subclassID of an item link; nil when the client does not tell
local function ItemInfo(link)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then return nil end
    local ok, _, _, _, _, icon, classID, subID = pcall(fn, link)
    if not ok or IsSecret(classID) or type(classID) ~= "number" then return nil end
    if IsSecret(icon) or type(icon) ~= "number" then icon = nil end
    local name = link:match("|h%[(.-)%]|h") or link
    return name, icon, classID, subID
end

-- Player name and item link of a chat line matching one of the patterns
local function Parse(msg, patterns)
    if type(msg) ~= "string" or IsSecret(msg) then return nil end
    msg = msg:gsub("^|HlootHistory:%d+|h%[.-%]|h:%s*", "")
    for _, pat in ipairs(patterns) do
        local who, rest = msg:match(pat)
        if who and rest then
            local link = rest:match("|c.-|Hitem:.-|h.-|h|r") or rest:match("|Hitem:.-|h.-|h")
            if link then return ShortName(who), link end
        end
    end
    return nil
end

-- A teammate, not you, and only while their casts are unreadable
local function Wanted(who)
    if not who or state.profOtherCasts then return false end
    return who ~= PlayerName()
end

local function Debug(who, prof, name)
    if DB().profDebug then
        Print(string.format("chat: %s %s -> %s", who, tostring(name),
            prof and ("|cff00ff00" .. prof .. "|r") or "|cff888888not a profession|r"))
    end
end

local lastGather = {}    -- "name:profession" -> time of the last counted gather

-- CHAT_MSG_LOOT: a teammate looted ore, herbs or leather
local function OnProfLootMessage(msg)
    local who, link = Parse(msg, LOOT_LINES)
    if not Wanted(who) then return end
    local name, icon, classID, subID = ItemInfo(link)
    local prof = classID == TRADEGOODS and GATHERED[subID] or nil
    -- raw fish is cooking material by type; the name tells it was fished
    if not prof and classID == TRADEGOODS and subID == 8 and name and name:find("^Raw ") then prof = "Fishing" end
    Debug(who, prof, name)
    if not prof then return end
    local key, now = who .. ":" .. prof, GetTime()
    if lastGather[key] and now - lastGather[key] < GATHER_WINDOW then return end
    lastGather[key] = now
    ProfRecord(who, ClassOf(who), prof, name, icon, false)
end

-- CHAT_MSG_TRADESKILLS: a teammate crafted something
local function OnTradeSkillMessage(msg)
    local who, link = Parse(msg, CRAFT_LINES)
    if not Wanted(who) then return end
    local name, icon, classID, subID = ItemInfo(link)
    local byClass = classID and CRAFTED[classID]
    local prof = (byClass and (byClass[subID] or byClass.default)) or "Crafting"
    Debug(who, prof, name)
    ProfRecord(who, ClassOf(who), prof, name or link, icon, false)
end

-- shared with the other BossNav files
ns.OnProfLootMessage = OnProfLootMessage
ns.OnTradeSkillMessage = OnTradeSkillMessage
