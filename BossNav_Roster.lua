-- Group roster helpers: who is in the group, their class, how a name is shown
-- (class icon, class colour, clickable link), and which chat channel the
-- group listens to. Shared by the loot roll tracker and the profession tracker.
local ADDON, ns = ...
-- from the files loaded before this one
local IsSecret               = ns.IsSecret

local function Plain(v)
    if not IsSecret(v) and type(v) == "string" and v ~= "" then return v end
    return nil
end

-- One spelling per person. On this server names can contain spaces and
-- hyphens: the unit API gives "Mouse-Off" while chat lines say "Mouse Off".
-- Cutting at the hyphen (the old realm strip) turned that into "Mouse", a
-- second person. So a hyphen counts as a space, and nothing is cut off.
local function ShortName(name)
    local s = tostring(name):gsub("%-", " "):gsub("%s+", " ")
    return (s:gsub("^ ", ""):gsub(" $", ""))
end

local function PlayerName()
    local ok, name, realm = pcall(UnitName, "player")
    if ok and Plain(name) then
        -- a second part, if the client splits the name, belongs to the name here
        if Plain(realm) then name = name .. " " .. realm end
        return ShortName(name)
    end
    return "You"
end

-- Unit tokens of everyone who can be in the group
local GROUP_UNITS = { "player" }
for i = 1, 4 do GROUP_UNITS[#GROUP_UNITS + 1] = "party" .. i end
for i = 1, 40 do GROUP_UNITS[#GROUP_UNITS + 1] = "raid" .. i end

-- Name and class token ("MAGE") of a group unit, trying the unit itself, then its GUID record
local function UnitNameClass(unit)
    local ok, uname = pcall(UnitName, unit)
    local name = ok and Plain(uname) or nil
    local ok2, _, uclass = pcall(UnitClass, unit)
    local class = ok2 and Plain(uclass) or nil
    if not (name and class) and GetPlayerInfoByGUID then
        local okG, guid = pcall(UnitGUID, unit)
        if okG and Plain(guid) then
            local okI, _, engClass, _, _, _, gname = pcall(GetPlayerInfoByGUID, guid)
            if okI then
                name = name or Plain(gname)
                class = class or Plain(engClass)
            end
        end
    end
    return name, class
end

-- Class token of a group member by name, from the roster; nil when unknown
local function ClassOf(name)
    name = ShortName(name)
    for _, unit in ipairs(GROUP_UNITS) do
        local uname, class = UnitNameClass(unit)
        if uname and ShortName(uname) == name then return class end
    end
    -- raid roster as a last resort (names there may carry the realm)
    if GetRaidRosterInfo and GetNumGroupMembers then
        local okN, n = pcall(GetNumGroupMembers)
        for i = 1, (okN and tonumber(n)) or 0 do
            local ok, rname, _, _, _, _, fileName = pcall(GetRaidRosterInfo, i)
            if ok and Plain(rname) and ShortName(rname) == name then return Plain(fileName) end
        end
    end
    return nil
end

-- Small round class icon as an inline texture escape, "" when the class is unknown
local CLASS_ICONS = "Interface\TargetingFrame\UI-Classes-Circles"
local function ClassIcon(class, size)
    local tc = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if not tc then return "" end
    size = size or 14
    return string.format("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t ", CLASS_ICONS, size, size,
        tc[1] * 256, tc[2] * 256, tc[3] * 256, tc[4] * 256)
end

-- "Bob" in the class colour, white when the class is unknown
local function ColoredName(name, class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c and c.colorStr then return "|c" .. c.colorStr .. name .. "|r" end
    if c then return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, name) end
    return "|cffffffff" .. name .. "|r"
end

-- Class icon plus the coloured name (no icon when the class is unknown)
local function ColorName(name, class, iconSize)
    return ClassIcon(class, iconSize) .. ColoredName(name, class)
end

-- Same, as a clickable player link for your own chat: a click opens a whisper
local function LinkName(name, class, iconSize)
    return ClassIcon(class, iconSize) .. "|Hplayer:" .. name .. "|h" .. ColoredName(name, class) .. "|h"
end

-- Localized class name ("Mage") for plain-text chat, nil when unknown
local function ClassText(class)
    if not class then return nil end
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end

-- Group chat channel to post into ("PARTY", "raid"), or nil when alone
local function ChatChannel()
    local ok, inst = pcall(function() return LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) end)
    if ok and inst == true then return "INSTANCE_CHAT", "instance" end
    local okR, raid = pcall(IsInRaid)
    if okR and raid == true then return "RAID", "raid" end
    local okG, grp = pcall(IsInGroup)
    if okG and grp == true then return "PARTY", "party" end
    return nil
end

-- shared with the other BossNav files
ns.ChatChannel = ChatChannel
ns.ClassOf = ClassOf
ns.ClassText = ClassText
ns.ColorName = ColorName
ns.GROUP_UNITS = GROUP_UNITS
ns.LinkName = LinkName
ns.Plain = Plain
ns.PlayerName = PlayerName
ns.ShortName = ShortName
ns.UnitNameClass = UnitNameClass
