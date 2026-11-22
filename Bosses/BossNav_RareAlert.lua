-- Rare alert: says in chat when a rare mob comes into view inside a dungeon.
--
-- The game cannot tell whether a rare spawned somewhere in the dungeon (no
-- rare markers inside instances on this client), but it does say whether a
-- unit you can see is rare (UnitClassification "rare" / "rareelite"). So a
-- rare is announced the moment its nameplate appears or you target it.
-- Each mob is announced once, by its GUID (new every run).
local ADDON, ns = ...
-- from the files loaded before this one
local IsSecret               = ns.IsSecret
local Print                  = ns.Print
local RarePingKey            = ns.RarePingKey
local SetRarePingTarget      = ns.SetRarePingTarget
local SkullUnit              = ns.SkullUnit
local state                  = ns.state

local RARE = { rare = "Rare", rareelite = "Rare elite" }
local announced = {}   -- GUID -> true

-- value of a unit call, or nil when it fails or is hidden
local function Read(fn, unit)
    local ok, v = pcall(fn, unit)
    if not ok or v == nil or IsSecret(v) then return nil end
    return v
end

-- Call when a unit appears (nameplate, target).
local function CheckRare(unit)
    if not state.inInstance then return end
    local kind = RARE[Read(UnitClassification, unit) or ""]
    if not kind then return end
    if Read(UnitIsDead, unit) then return end
    local guid = Read(UnitGUID, unit)
    if guid then
        if announced[guid] then return end
        announced[guid] = true
    end
    local name = Read(UnitName, unit)
    -- a skull the whole group sees, no key press needed
    local skulled = SkullUnit(unit)
    local hint = skulled and " Skull on it." or ""
    if name then
        SetRarePingTarget(name)
        local key = RarePingKey()
        hint = hint .. (key and (" Press " .. key .. " to ping it for the group.")
                    or " /bnav rarekey <key> sets a key to ping it for the group.")
    end
    Print("|cffffd100" .. kind .. " in view:|r " .. (name or "unknown name") .. "." .. hint)
    if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
        pcall(PlaySound, SOUNDKIT.RAID_WARNING)
    end
end

-- shared with the other BossNav files
ns.CheckRare = CheckRare
