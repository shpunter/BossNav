-- Is the player tanking right now?
--
-- Checked in this order, the first one that says "tank" wins:
--   1. the group role picked in the group finder / role check
--   2. the talent spec role, when the client has specs
--   3. what the character is doing: Defensive Stance, Bear Form, Righteous Fury
-- The answer can be forced with /bnav threat tank (auto -> on -> off).
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local IsSecret               = ns.IsSecret

-- shapeshift form IDs that mean tanking, per class
local TANK_FORMS = {
    WARRIOR = { [18] = "Defensive Stance" },
    DRUID   = { [5] = "Bear Form", [8] = "Dire Bear Form" },
}
-- buffs that mean tanking, per class (spell ID -> name)
local TANK_AURAS = {
    PALADIN = { [25780] = "Righteous Fury" },
}

local function Plain(v)
    if IsSecret(v) then return nil end
    return v
end

local function GroupRole()
    if not UnitGroupRolesAssigned then return nil end
    local ok, role = pcall(UnitGroupRolesAssigned, "player")
    if ok and Plain(role) == "TANK" then return "group role" end
end

local function SpecRole()
    if not (GetSpecialization and GetSpecializationRole) then return nil end
    local ok, role = pcall(function() return GetSpecializationRole(GetSpecialization()) end)
    if ok and Plain(role) == "TANK" then return "talent spec" end
end

local function HasAura(spellID)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if ok and not IsSecret(aura) and aura then return true end
    end
    if UnitBuff then
        for i = 1, 40 do
            local ok, name, _, _, _, _, _, _, _, _, id = pcall(UnitBuff, "player", i)
            if not ok or Plain(name) == nil then break end
            if Plain(id) == spellID then return true end
        end
    end
    return false
end

local function Stance()
    local ok, _, class = pcall(UnitClass, "player")
    class = ok and Plain(class) or nil
    if not class then return nil end
    local forms = TANK_FORMS[class]
    if forms and GetShapeshiftFormID then
        local okF, form = pcall(GetShapeshiftFormID)
        form = okF and Plain(form) or nil
        if form and forms[form] then return forms[form] end
    end
    for id, name in pairs(TANK_AURAS[class] or {}) do
        if HasAura(id) then return name end
    end
end

-- true/false, plus why ("Defensive Stance", "forced on", ...)
local function PlayerIsTank()
    local mode = DB().threatTank or "auto"
    if mode == "on" then return true, "forced on" end
    if mode == "off" then return false, "forced off" end
    local why = GroupRole() or SpecRole() or Stance()
    return why ~= nil, why or "no tank role, stance or buff found"
end

-- /bnav threat tank: auto -> on -> off -> auto
local NEXT_MODE = { auto = "on", on = "off", off = "auto" }
local function CycleTankMode()
    local mode = NEXT_MODE[DB().threatTank or "auto"] or "auto"
    DB().threatTank = mode
    return mode
end

-- shared with the other BossNav files
ns.CycleTankMode = CycleTankMode
ns.PlayerIsTank = PlayerIsTank
