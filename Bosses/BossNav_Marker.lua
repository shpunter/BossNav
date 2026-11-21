-- Skull raid mark on a boss as soon as it is seen.
--
-- A boss can be noticed in three ways, each handled by the same TryMarkUnit:
--   * its nameplate appears      (NAME_PLATE_UNIT_ADDED, needs enemy nameplates on)
--   * you target it              (PLAYER_TARGET_CHANGED)
--   * the encounter starts       (ENCOUNTER_START / INSTANCE_ENCOUNTER_ENGAGE_UNIT;
--                                 the game then exposes the boss as "boss1".."boss5")
-- The unit is recognised by name, or by the creature ID inside its GUID when
-- the client hides the name as a secret value. Every unit read is guarded.
local ADDON, ns = ...
-- from the files loaded before this one
local BOSS_NPC               = ns.BOSS_NPC
local DB                     = ns.DB
local IsSecret               = ns.IsSecret
local NamesMatch             = ns.NamesMatch
local Print                  = ns.Print
local state                  = ns.state

local SKULL = 8                -- raid target index of the skull
local REMARK_AFTER = 30        -- seconds before the same boss may be marked again
local lastMarked = {}          -- [bossName] = GetTime() of the last mark

-- Anyone may mark solo or in a party; in a raid only the leader or an assistant.
local function CanMark()
    if IsInRaid and IsInRaid() then
        return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
    end
    return true
end

-- Creature ID from a GUID like "Creature-0-1234-56-789-NPCID-SPAWNID".
local function NpcID(guid)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return tonumber(id)
end

local function HasNpc(entry, npc)
    if type(entry) == "number" then return entry == npc end
    if type(entry) == "table" then
        for _, id in ipairs(entry) do if id == npc then return true end end
    end
    return false
end

local function BossByName(cfg, name)
    for _, b in ipairs(cfg.bosses) do
        if NamesMatch(b[1], name) then return b end
    end
end

local function BossByNpc(cfg, npc)
    for _, b in ipairs(cfg.bosses) do
        if HasNpc(BOSS_NPC[b[1]], npc) then return b end
    end
end

-- Which boss of the current dungeon is this unit? Returns the boss row and
-- how it was recognised ("encounter", "name" or "id"), or nil.
local function IdentifyBoss(unit, knownName)
    local cfg = state.cfg
    if not cfg then return nil end
    if type(knownName) == "string" and not IsSecret(knownName) then
        local b = BossByName(cfg, knownName)
        if b then return b, "encounter" end
    end
    local ok, name, guid = pcall(function() return UnitName(unit), UnitGUID(unit) end)
    if not ok then return nil end
    if type(name) == "string" and not IsSecret(name) then
        local b = BossByName(cfg, name)
        if b then return b, "name" end
    end
    if not IsSecret(guid) then
        local npc = NpcID(guid)
        if npc then
            local b = BossByNpc(cfg, npc)
            if b then return b, "id" end
        end
    end
    return nil
end

-- Put a skull on `unit` if it is a living, unmarked boss of this dungeon.
-- Returns a short reason describing what happened (used by /bnav skull test).
-- `force` skips the 30 second throttle.
local function TryMarkUnit(unit, knownName, force)
    if type(unit) ~= "string" then return "no unit" end
    if not DB().skull then return "auto skull is off (/bnav skull)" end
    if not state.cfg then return "not in a known dungeon" end
    if state.testMode then return "preview mode" end
    local ok, exists, player, dead = pcall(function()
        return UnitExists(unit), UnitIsPlayer(unit), UnitIsDead(unit)
    end)
    if not ok then return "unit read failed: " .. tostring(exists) end
    -- a secret boolean cannot be tested, so only a plain `false` stops us here
    if not IsSecret(exists) and not exists then return "unit does not exist" end
    if not IsSecret(player) and player then return "unit is a player" end
    if not IsSecret(dead) and dead then return "unit is dead" end

    local boss, how = IdentifyBoss(unit, knownName)
    if not boss then return "not recognised as a boss of " .. state.cfg.name end
    if state.killed[boss[1]] then return boss[1] .. " is marked [DEAD]" end
    local now = GetTime()
    if not force and lastMarked[boss[1]] and now - lastMarked[boss[1]] < REMARK_AFTER then
        return boss[1] .. " was marked less than " .. REMARK_AFTER .. "s ago"
    end

    -- leave a mark that someone (or we) already placed alone
    local okIdx, idx = pcall(GetRaidTargetIndex, unit)
    if okIdx and not IsSecret(idx) and idx then
        lastMarked[boss[1]] = now
        return boss[1] .. " already has mark " .. tostring(idx)
    end
    if not CanMark() then return "in a raid only the leader or an assistant may mark" end
    local okSet, err = pcall(SetRaidTarget, unit, SKULL)
    if not okSet then return "SetRaidTarget failed: " .. tostring(err) end
    lastMarked[boss[1]] = now
    Print("|cff888888skull on " .. boss[1] .. " (" .. how .. ").|r")
    return "marked"
end

-- The encounter began: the game exposes the boss as boss1..boss5.
-- The bosses recognised here are remembered, so the kill still counts when
-- the encounter's end names the boss differently (BossNav_Kills.lua).
local function OnEncounterStart(encounterName)
    state.encounterBosses = state.encounterBosses or {}
    for i = 1, 5 do
        local unit = "boss" .. i
        pcall(TryMarkUnit, unit, encounterName)
        local ok, boss = pcall(IdentifyBoss, unit)
        if ok and boss then state.encounterBosses[boss[1]] = true end
    end
end

-- /bnav skull test: show what the client lets us read about the target,
-- then try to mark it and say why it did or did not work.
local function SkullTest()
    local function show(v) if IsSecret(v) then return "|cffff4444SECRET|r" end return tostring(v) end
    local ok, exists, name, guid, idx, dead = pcall(function()
        return UnitExists("target"), UnitName("target"), UnitGUID("target"),
               GetRaidTargetIndex("target"), UnitIsDead("target")
    end)
    if not ok then Print("skull test: reading the target failed: " .. tostring(exists)) return end
    if not IsSecret(exists) and not exists then Print("skull test: target something first.") return end
    Print(string.format("skull test: exists=%s  name=%s  guid=%s  mark=%s  dead=%s",
        show(exists), show(name), show(guid), show(idx), show(dead)))
    local npc = (not IsSecret(guid)) and NpcID(guid) or nil
    local boss, how = IdentifyBoss("target")
    Print(string.format("  creature id=%s  boss=%s  via=%s  dungeon=%s  can mark=%s  auto=%s",
        tostring(npc), boss and boss[1] or "none", tostring(how),
        state.cfg and state.cfg.name or "none", tostring(CanMark()), tostring(DB().skull)))
    Print("  mark attempt: " .. tostring(TryMarkUnit("target", nil, true)))
end

-- /bnav skull now, or the "Mark Nearby Boss" keybind: mark a boss without
-- targeting it. The client only exposes nearby enemies through their
-- nameplates (and boss1..5 during a fight), so those are scanned in order.
local function MarkNearbyBoss()
    if not state.cfg then Print("Not in a known dungeon.") return end
    if not DB().skull then Print("Auto skull is off; /bnav skull turns it on.") return end
    -- nameplates must be shown for nearby units to be visible to the addon
    local okCv, shown = pcall(GetCVar, "nameplateShowEnemies")
    if okCv and (shown == "0" or shown == 0) then
        if pcall(SetCVar, "nameplateShowEnemies", "1") then
            Print("Enemy nameplates turned on (the addon sees nearby enemies through them).")
        end
    end
    local units = { "target" }
    for i = 1, 5 do units[#units + 1] = "boss" .. i end
    for i = 1, 40 do units[#units + 1] = "nameplate" .. i end
    local seen = 0
    for _, u in ipairs(units) do
        local ok, exists = pcall(UnitExists, u)
        if ok and (IsSecret(exists) or exists) then
            seen = seen + 1
            local r = TryMarkUnit(u, nil, true)
            if r == "marked" then return end
            if r:find("already has mark", 1, true) or r:find("DEAD", 1, true) then Print(r .. ".") return end
        end
    end
    if seen <= 1 then
        Print("No enemy nameplates in view. Get closer, or press V to show enemy nameplates.")
    else
        Print(string.format("No boss among the %d units in view.", seen))
    end
end

function BossNav_MarkNearbyBoss()
    pcall(MarkNearbyBoss)
end

-- /bnav skull [test]
local function SkullCommand(rest)
    if rest == "now" then
        MarkNearbyBoss()
        return
    end
    if rest == "test" then
        SkullTest()
        return
    end
    DB().skull = not DB().skull
    Print("Auto skull mark on bosses " .. (DB().skull and "on" or "off") .. ".")
end

-- shared with the other BossNav files
ns.IdentifyBoss = IdentifyBoss
ns.MarkNearbyBoss = MarkNearbyBoss
ns.OnEncounterStart = OnEncounterStart
ns.SkullCommand = SkullCommand
ns.TryMarkUnit = TryMarkUnit
