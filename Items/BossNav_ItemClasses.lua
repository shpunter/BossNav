-- Which classes can use an item, and which classes the Items column is
-- filtered to. A class is ticked unless you untick it; the unticked ones are
-- saved in BossNavDB.itemClassOff, so the choice survives /reload and logout.
--
-- "Can use" follows the armour and weapon skills each class can learn
-- (mail for hunters and shamans and plate for paladins come at level 40,
-- but count from the start). Anything else - rings, necklaces, trinkets,
-- cloaks, quest items, recipes - is usable by every class. An item the
-- client cannot describe yet is shown, never hidden.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local IsSecret               = ns.IsSecret

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

local ENGLISH = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
    SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}

-- item class 4 (armour): subclass -> classes that wear it (missing: everyone)
local ARMOR = {
    [2] = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, SHAMAN = true, DRUID = true }, -- leather
    [3] = { WARRIOR = true, PALADIN = true, HUNTER = true, SHAMAN = true },                             -- mail
    [4] = { WARRIOR = true, PALADIN = true },                                                           -- plate
    [6] = { WARRIOR = true, PALADIN = true, SHAMAN = true },                                            -- shield
    [7] = { PALADIN = true },                                                                           -- libram
    [8] = { DRUID = true },                                                                             -- idol
    [9] = { SHAMAN = true },                                                                            -- totem
}

-- item class 2 (weapons): subclass -> classes that can learn it (missing: everyone)
local function Set(...)
    local t = {}
    for i = 1, select("#", ...) do t[select(i, ...)] = true end
    return t
end
local WEAPON_SKILLS = {
    WARRIOR = Set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
    PALADIN = Set(0, 1, 4, 5, 6, 7, 8),
    HUNTER  = Set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18),
    ROGUE   = Set(2, 3, 4, 7, 13, 15, 16, 18),
    PRIEST  = Set(4, 10, 15, 19),
    SHAMAN  = Set(0, 1, 4, 5, 10, 13, 15),
    MAGE    = Set(7, 10, 15, 19),
    WARLOCK = Set(7, 10, 15, 19),
    DRUID   = Set(4, 5, 10, 13, 15),
}
-- 14 miscellaneous, 20 fishing pole: anyone
local ANY_WEAPON = Set(14, 20)

local function Plain(v)
    if v == nil or (IsSecret and IsSecret(v)) then return nil end
    return v
end

-- item class, subclass and equip slot ("INVTYPE_HEAD"...) from the client's
-- own item table (no server trip)
local function ItemKind(id)
    local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not get then return nil end
    local ok, _, _, _, equipLoc, _, classID, subID = pcall(get, id)
    if not ok then return nil end
    return Plain(classID), Plain(subID), Plain(equipLoc)
end

local function ClassCanUse(class, classID, subID)
    if classID == 4 then
        local who = ARMOR[subID]
        return (not who) or who[class] == true
    elseif classID == 2 then
        if ANY_WEAPON[subID] then return true end
        local skills = WEAPON_SKILLS[class]
        return (not skills) or skills[subID] == true
    end
    return true
end

--------------------------------------------------------------------------
-- The saved choice
--------------------------------------------------------------------------
local function Off()
    local db = DB()
    db.itemClassOff = db.itemClassOff or {}
    return db.itemClassOff
end

local function ClassTicked(class)
    return not Off()[class]
end

local function SetClassTicked(class, on)
    Off()[class] = (not on) and true or nil
end

local function SetAllClasses(on)
    for _, c in ipairs(CLASSES) do SetClassTicked(c, on) end
end

-- only your own class ticked
local function OnlyMyClass()
    local ok, _, mine = pcall(UnitClass, "player")
    mine = ok and Plain(mine)
    if not (type(mine) == "string" and ENGLISH[mine]) then return nil end
    for _, c in ipairs(CLASSES) do SetClassTicked(c, c == mine) end
    return mine
end

local function TickedCount()
    local n = 0
    for _, c in ipairs(CLASSES) do if ClassTicked(c) then n = n + 1 end end
    return n
end

-- part of the item list's cache key: changes whenever the ticks do
local function ClassFilterKey()
    local t = {}
    for _, c in ipairs(CLASSES) do if not ClassTicked(c) then t[#t + 1] = c end end
    return table.concat(t, ",")
end

-- true when fn(class) holds for at least one ticked class
local function AnyTickedClass(fn)
    for _, c in ipairs(CLASSES) do
        if ClassTicked(c) and fn(c) then return true end
    end
    return false
end

-- true when at least one ticked class can use the item
local function ItemForTickedClasses(id)
    if TickedCount() == #CLASSES then return true end
    local classID, subID = ItemKind(id)
    if not classID then return true end
    for _, c in ipairs(CLASSES) do
        if ClassTicked(c) and ClassCanUse(c, classID, subID) then return true end
    end
    return false
end

local function ClassName(class)
    local n = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]
    return (type(n) == "string" and n ~= "") and n or ENGLISH[class]
end

local function ClassHex(class)
    local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if not c then return "ffffff" end
    return string.format("%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
end

-- "priest" / "Priest" / "pri" -> "PRIEST"
local function FindClass(word)
    word = (word or ""):lower()
    if word == "" then return nil end
    for _, c in ipairs(CLASSES) do
        if ENGLISH[c]:lower():sub(1, #word) == word or ClassName(c):lower():sub(1, #word) == word then
            return c
        end
    end
    return nil
end

-- shared with the other BossNav files
ns.AnyTickedClass = AnyTickedClass
ns.ClassCanUse = ClassCanUse
ns.ITEM_CLASSES = CLASSES
ns.ClassFilterKey = ClassFilterKey
ns.ClassHex = ClassHex
ns.ClassName = ClassName
ns.ClassTicked = ClassTicked
ns.FindClass = FindClass
ns.ItemForTickedClasses = ItemForTickedClasses
ns.ItemKind = ItemKind
ns.OnlyMyClass = OnlyMyClass
ns.SetAllClasses = SetAllClasses
ns.SetClassTicked = SetClassTicked
ns.TickedCount = TickedCount
