-- The armour type, slot, weapon type and hand filters of the Items column, next to the
-- class filter (BossNav_ItemClasses.lua). Each is a group of boxes, all
-- ticked at first; unticked boxes are saved in BossNavDB.itemFilterOff, so the
-- choice survives /reload and logout.
--
-- Like the filters of a web shop: inside a group an item needs one ticked
-- box, and it has to pass every group that applies to it.
--   Armor   armour only: Cloth, Leather, Mail, Plate, Miscellaneous (rings,
--           necks, trinkets); the client's own names, as in its auction house.
--   Gear    armour, jewellery, shields, off-hand items, relics (helm, boots,
--           ring...).
--   Other   everything that is neither armour nor a weapon, by the auction
--           house's categories: Recipe, Trade Goods, Consumable, Container...
--   Weapon  weapons only: axe, mace, sword...
--   Wield   weapons only: One-Hand, Two-Hand, Main Hand, Off Hand, Ranged.
-- An item the client cannot describe yet is shown, never hidden.
local ADDON, ns = ...
-- from the files loaded before this one
local ClassCanUse            = ns.ClassCanUse
local DB                     = ns.DB
local ItemKind               = ns.ItemKind

-- in the order of the character sheet, named the way players call them
-- (the keys stay the game's slots; the saved ticks use the keys)
local SLOTS = {
    { key = "HEAD", label = "Helm" },        { key = "NECK", label = "Neck" },
    { key = "SHOULDER", label = "Shoulders" }, { key = "BACK", label = "Cloak" },
    { key = "CHEST", label = "Chest" },      { key = "WRIST", label = "Bracers" },
    { key = "HANDS", label = "Gloves" },     { key = "WAIST", label = "Belt" },
    { key = "LEGS", label = "Legs" },        { key = "FEET", label = "Boots" },
    { key = "FINGER", label = "Ring" },      { key = "TRINKET", label = "Trinket" },
    { key = "SHIELD", label = "Shield" },    { key = "HELD", label = "Off-hand" },
    { key = "RELIC", label = "Relic" },
}
local SLOT_OF = {
    INVTYPE_HEAD = "HEAD", INVTYPE_NECK = "NECK", INVTYPE_SHOULDER = "SHOULDER",
    INVTYPE_CLOAK = "BACK", INVTYPE_CHEST = "CHEST", INVTYPE_ROBE = "CHEST",
    INVTYPE_WRIST = "WRIST", INVTYPE_HAND = "HANDS", INVTYPE_WAIST = "WAIST",
    INVTYPE_LEGS = "LEGS", INVTYPE_FEET = "FEET", INVTYPE_FINGER = "FINGER",
    INVTYPE_TRINKET = "TRINKET", INVTYPE_SHIELD = "SHIELD", INVTYPE_HOLDABLE = "HELD",
    INVTYPE_RELIC = "RELIC",
}

local WEAPONS = {
    { key = "AXE", label = "Axe" },         { key = "MACE", label = "Mace" },
    { key = "SWORD", label = "Sword" },     { key = "DAGGER", label = "Dagger" },
    { key = "FIST", label = "Fist" },       { key = "STAFF", label = "Staff" },
    { key = "POLEARM", label = "Polearm" }, { key = "BOW", label = "Bow" },
    { key = "GUN", label = "Gun" },         { key = "CROSSBOW", label = "Crossbow" },
    { key = "WAND", label = "Wand" },       { key = "THROWN", label = "Thrown" },
    { key = "MISC", label = "Other" },
}
-- weapon subclass -> box (anything else: MISC)
local WEAPON_OF = {
    [0] = "AXE", [1] = "AXE", [4] = "MACE", [5] = "MACE", [7] = "SWORD", [8] = "SWORD",
    [15] = "DAGGER", [13] = "FIST", [10] = "STAFF", [6] = "POLEARM", [2] = "BOW",
    [3] = "GUN", [18] = "CROSSBOW", [19] = "WAND", [16] = "THROWN",
}

-- armour type, as the auction house splits Armor (item class 4): the names
-- are the client's own (GetItemSubClassInfo), these are only fallbacks.
-- Shields and relics are not here: they have their own Gear boxes.
local ARMOR_TYPES = {
    { key = "CLOTH", sub = 1, label = "Cloth" },   { key = "LEATHER", sub = 2, label = "Leather" },
    { key = "MAIL", sub = 3, label = "Mail" },     { key = "PLATE", sub = 4, label = "Plate" },
    { key = "MISC", sub = 0, label = "Miscellaneous" },
}
local ARMOR_TYPE_OF = {}
for _, e in ipairs(ARMOR_TYPES) do
    ARMOR_TYPE_OF[e.sub] = e.key
    local get = (C_Item and C_Item.GetItemSubClassInfo) or GetItemSubClassInfo
    local ok, name = pcall(get or error, 4, e.sub)
    if ok and type(name) == "string" and name ~= "" and not (ns.IsSecret and ns.IsSecret(name)) then
        e.label = name
    end
end

-- the client's name of an item class (2 "Weapon", 4 "Armor"), as the
-- auction house shows its categories
local function ItemClassName(classID, fallback)
    local get = (C_Item and C_Item.GetItemClassInfo) or GetItemClassInfo
    local ok, name = pcall(get or error, classID)
    if ok and type(name) == "string" and name ~= "" and not (ns.IsSecret and ns.IsSecret(name)) then
        return name
    end
    return fallback
end

-- the auction house's other categories (item classes); labels from the
-- client, these are only fallbacks. Gems, projectiles, quivers and anything
-- else count as Miscellaneous.
local GOODS = {
    { key = "RECIPE", class = 9, label = "Recipe" },
    { key = "TRADE", class = 7, label = "Trade Goods" },
    { key = "REAGENT", class = 5, label = "Reagent" },
    { key = "CONSUMABLE", class = 0, label = "Consumable" },
    { key = "CONTAINER", class = 1, label = "Container" },
    { key = "QUEST", class = 12, label = "Quest" },
    { key = "KEY", class = 13, label = "Key" },
    { key = "MISC", class = 15, label = "Miscellaneous" },
}
local GOODS_OF = {}
for _, e in ipairs(GOODS) do
    GOODS_OF[e.class] = e.key
    e.label = ItemClassName(e.class, e.label)
end

-- worded as on an item tooltip
local HANDS = {
    { key = "ONE", label = "One-Hand" },   { key = "TWO", label = "Two-Hand" },
    { key = "MAIN", label = "Main Hand" }, { key = "OFF", label = "Off Hand" },
    { key = "RANGED", label = "Ranged" },
}
local HAND_OF = {
    INVTYPE_WEAPON = "ONE", INVTYPE_2HWEAPON = "TWO", INVTYPE_WEAPONMAINHAND = "MAIN",
    INVTYPE_WEAPONOFFHAND = "OFF", INVTYPE_RANGED = "RANGED", INVTYPE_RANGEDRIGHT = "RANGED",
    INVTYPE_THROWN = "RANGED",
}

--------------------------------------------------------------------------
-- Which class could ever use what a box stands for. The filter panel greys
-- out a box that no ticked class can use (a druid has no use for guns or
-- shields). Boxes without a rule (most gear slots) suit every class.
--------------------------------------------------------------------------
local function AnyWeapon(subs)
    return function(class)
        for _, sub in ipairs(subs) do
            if ClassCanUse(class, 2, sub) then return true end
        end
        return false
    end
end
local DUAL_WIELD = { WARRIOR = true, HUNTER = true, ROGUE = true }
local RELIC_USERS = { PALADIN = true, DRUID = true, SHAMAN = true }

local USABLE = {
    SHIELD = function(class) return ClassCanUse(class, 4, 6) end,
    RELIC = function(class) return RELIC_USERS[class] == true end,
}
for sub, key in pairs(WEAPON_OF) do
    local subs = {}
    for s2, k2 in pairs(WEAPON_OF) do if k2 == key then subs[#subs + 1] = s2 end end
    USABLE[key] = AnyWeapon(subs)
end
local HAND_USABLE = {
    ONE = AnyWeapon({ 0, 4, 7, 13, 15 }),
    MAIN = AnyWeapon({ 0, 4, 7, 13, 15 }),
    TWO = AnyWeapon({ 1, 5, 6, 8, 10 }),
    OFF = function(class) return DUAL_WIELD[class] == true end,
    RANGED = AnyWeapon({ 2, 3, 16, 18, 19 }),
}
for _, e in ipairs(SLOTS) do e.usable = USABLE[e.key] end
for _, e in ipairs(WEAPONS) do e.usable = USABLE[e.key] end
for _, e in ipairs(HANDS) do e.usable = HAND_USABLE[e.key] end
for _, e in ipairs(ARMOR_TYPES) do
    local sub = e.sub
    e.usable = function(class) return ClassCanUse(class, 4, sub) end
end

--------------------------------------------------------------------------
-- Saved ticks: itemFilterOff[group][key] = true for an unticked box
--------------------------------------------------------------------------
local function Off(group)
    local db = DB()
    db.itemFilterOff = db.itemFilterOff or {}
    db.itemFilterOff[group] = db.itemFilterOff[group] or {}
    return db.itemFilterOff[group]
end

-- one filter group: { id, title, entries, Ticked, SetTicked, SetAll, AllTicked }
local function NewGroup(id, title, entries)
    local g = { id = id, title = title, entries = entries }
    function g.Ticked(key) return not Off(id)[key] end
    function g.SetTicked(key, on) Off(id)[key] = (not on) and true or nil end
    function g.SetAll(on) for _, e in ipairs(entries) do g.SetTicked(e.key, on) end end
    function g.AllTicked()
        for _, e in ipairs(entries) do if not g.Ticked(e.key) then return false end end
        return true
    end
    -- "two" / "Two-hand" / "sh" -> the entry key
    function g.Find(word)
        word = (word or ""):lower():gsub("[%s%-]", "")
        if word == "" then return nil end
        for _, e in ipairs(entries) do
            local label = e.label:lower():gsub("[%s%-]", "")
            if label:sub(1, #word) == word or e.key:lower() == word then return e.key end
        end
        return nil
    end
    return g
end

local armorGroup = NewGroup("armor", ItemClassName(4, "Armor"), ARMOR_TYPES)
local slotGroup = NewGroup("slot", "Gear", SLOTS)
local weaponGroup = NewGroup("weapon", ItemClassName(2, "Weapon"), WEAPONS)
local handGroup = NewGroup("hand", "Wield", HANDS)
local goodsGroup = NewGroup("other", "Other", GOODS)
local ALL = { armorGroup, slotGroup, weaponGroup, handGroup, goodsGroup }

-- part of the item list's cache key: changes whenever a tick does
local function SlotFilterKey()
    local t = {}
    for _, g in ipairs(ALL) do
        for _, e in ipairs(g.entries) do
            if not g.Ticked(e.key) then t[#t + 1] = g.id .. "." .. e.key end
        end
    end
    return table.concat(t, ",")
end

local function SlotFiltersActive()
    for _, g in ipairs(ALL) do
        if not g.AllTicked() then return true end
    end
    return false
end

-- true when the item passes the armour type, slot, weapon, hand and
-- category boxes
local function ItemForTickedSlots(id)
    if not SlotFiltersActive() then return true end
    local classID, subID, equipLoc = ItemKind(id)
    if not classID then return true end
    if classID == 2 then
        return weaponGroup.Ticked(WEAPON_OF[subID] or "MISC")
            and handGroup.Ticked(HAND_OF[equipLoc] or "ONE")
    end
    if classID ~= 4 then
        return goodsGroup.Ticked(GOODS_OF[classID] or "MISC")
    end
    if ARMOR_TYPE_OF[subID] and not armorGroup.Ticked(ARMOR_TYPE_OF[subID]) then
        return false
    end
    -- a worn item without a Gear box (shirt, tabard) is always shown
    local slot = SLOT_OF[equipLoc]
    return (not slot) or slotGroup.Ticked(slot)
end

-- shared with the other BossNav files
ns.ArmorFilter = armorGroup
ns.GoodsFilter = goodsGroup
ns.HandFilter = handGroup
ns.ItemForTickedSlots = ItemForTickedSlots
ns.SlotFilter = slotGroup
ns.SlotFilterKey = SlotFilterKey
ns.SlotFiltersActive = SlotFiltersActive
ns.WeaponFilter = weaponGroup
