-- Dungeon reset detection.
--
-- When anyone in the group resets the dungeon, the server makes a new copy
-- of it and every boss is alive again, but the kill marks saved for the old
-- copy would still say [DEAD]. Every mob's GUID names the copy it lives in:
--   Creature-0-<server>-<mapID>-<copyID>-<npcID>-<spawnID>
-- The copy ID of the first mob seen (nameplate or target) is saved with the
-- dungeon's progress; a mob from the same map with a different copy ID means
-- the dungeon was reset, so the kill marks are cleared.
--
-- Copy IDs are kept per map ID, so a dungeon whose wings are separate maps
-- (Scarlet Monastery on some servers) is not mistaken for a reset when you
-- walk from one wing into the next.
local ADDON, ns = ...
-- from the files loaded before this one
local ClearProgress          = ns.ClearProgress
local DB                     = ns.DB
local IsSecret               = ns.IsSecret
local Print                  = ns.Print
local RefreshIfShown         = ns.RefreshIfShown
local state                  = ns.state

-- map ID and copy ID of a creature unit, or nil
local function CopyOf(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or guid == nil or IsSecret(guid) or type(guid) ~= "string" then return nil end
    local kind, mapID, copyID = guid:match("^(%a+)%-%d+%-%d+%-(%d+)%-(%d+)%-")
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return mapID, copyID
end

-- Call when a unit appears (nameplate, target).
local function CheckInstanceCopy(unit)
    local cfg = state.cfg
    if not cfg or state.testMode or not state.inInstance then return end
    local mapID, copyID = CopyOf(unit)
    if not mapID then return end
    local rec = DB().progress[cfg.key]
    if not rec then return end
    rec.copies = rec.copies or {}
    local known = rec.copies[mapID]
    if known == copyID then return end
    if known == nil then
        rec.copies[mapID] = copyID      -- first mob of this run on this map
        return
    end
    -- Same map, new copy: the dungeon was reset.
    ClearProgress(cfg)
    local fresh = DB().progress[cfg.key]
    if fresh then fresh.copies = { [mapID] = copyID } end
    Print(cfg.name .. " was reset: kill marks cleared.")
    RefreshIfShown()
    pcall(BossNav_UpdateLive, true)
end

-- The game's "Scarlet Monastery has been reset." chat line. Mob GUIDs are
-- secret in some dungeons (Scarlet Monastery, 2026-11-22), so this is the
-- signal that always works; the game shows it to whoever did the reset.
local resetPattern
local function ResetPattern()
    if resetPattern then return resetPattern end
    local s = type(INSTANCE_RESET_SUCCESS) == "string" and INSTANCE_RESET_SUCCESS or "%s has been reset."
    s = s:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", "(.+)")
    resetPattern = "^" .. s .. "$"
    return resetPattern
end

local function OnResetMessage(msg)
    if type(msg) ~= "string" or IsSecret(msg) then return end
    local name = msg:match(ResetPattern())
    if not name then return end
    local cfg = ns.ZONE_INDEX[ns.Norm(name)]
    if not cfg then return end
    if state.cfg == cfg then
        ClearProgress(cfg)
        local fresh = DB().progress[cfg.key]
        if fresh then fresh.copies = nil end   -- a new copy: note it afresh
        RefreshIfShown()
        pcall(BossNav_UpdateLive, true)
    else
        DB().progress[cfg.key] = nil
    end
    Print(cfg.name .. " was reset: kill marks cleared.")
end

-- /bnav copy: what the reset check knows (target a mob inside first)
local function CopyTest()
    local cfg = state.cfg
    Print("copy test: dungeon=" .. (cfg and cfg.name or "none") ..
          "  inside=" .. tostring(state.inInstance) .. "  preview=" .. tostring(state.testMode))
    local ok, guid = pcall(UnitGUID, "target")
    local shown = not ok and "read failed" or guid == nil and "nil (no target?)"
               or IsSecret(guid) and "SECRET" or tostring(guid)
    Print("  target GUID: " .. shown)
    local mapID, copyID = CopyOf("target")
    Print("  target map=" .. tostring(mapID) .. "  copy=" .. tostring(copyID))
    local rec = cfg and DB().progress[cfg.key]
    if not rec then Print("  no saved progress for this dungeon") return end
    local any = false
    for m, c in pairs(rec.copies or {}) do
        Print("  saved: map " .. m .. " copy " .. c)
        any = true
    end
    if not any then Print("  saved: no copy noted yet (the next mob seen is taken as this run's)") end
    local dead = 0
    for _ in pairs(state.killed) do dead = dead + 1 end
    Print("  marked dead: " .. dead)
end

ns.AddCommand("copy", CopyTest, {
    "  /bnav copy            test the dungeon reset check (target a mob inside)",
})

-- shared with the other BossNav files
ns.CheckInstanceCopy = CheckInstanceCopy
ns.OnResetMessage = OnResetMessage
