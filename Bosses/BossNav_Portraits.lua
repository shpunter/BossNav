-- Boss portraits learned in game.
--
-- Bosses new in WoW Forever have no published creature display ID, so the
-- built-in table (BOSS_DISPLAY in BossNav_Data.lua) cannot give them a
-- portrait. The game knows it, though: when a boss of the current dungeon is
-- your target, shows its nameplate or joins an encounter, its model is loaded
-- into a hidden model frame and the display ID read back from it. The ID is
-- saved, so the portrait stays from then on (all characters).
--
-- Built-in portraits always win; only bosses without one are learned.
-- /bnav portrait          learn from your current target and say what happened
-- /bnav portrait list     how many portraits were learned, and which
-- /bnav portrait clear    forget every learned portrait
local ADDON, ns = ...
-- from the files loaded before this one
local BOSS_DISPLAY           = ns.BOSS_DISPLAY
local DB                     = ns.DB
local IdentifyBoss           = ns.IdentifyBoss
local IsSecret               = ns.IsSecret
local Print                  = ns.Print

local learned = {}   -- [bossName] = true for portraits that came from the saved table

-- A 1x1 invisible model frame, kept shown so the client really loads models into it.
local probe = CreateFrame("PlayerModel", nil, UIParent)
probe:SetSize(1, 1)
probe:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 10, -10)
probe:SetAlpha(0)
probe:EnableMouse(false)

local pending   -- boss whose model was requested but had not finished loading

local function ReadDisplayID()
    if not probe.GetDisplayInfo then return nil end
    local ok, id = pcall(probe.GetDisplayInfo, probe)
    if not ok or IsSecret(id) or type(id) ~= "number" or id <= 0 then return nil end
    return id
end

local function Save(name, id)
    BOSS_DISPLAY[name] = id
    learned[name] = true
    local db = DB()
    db.bossDisplay = db.bossDisplay or {}
    db.bossDisplay[name] = id
    Print("|cff888888portrait learned for " .. name .. ".|r")
    if ns.RefreshIfShown then pcall(ns.RefreshIfShown) end
end

pcall(probe.SetScript, probe, "OnModelLoaded", function()
    if not pending then return end
    local name = pending
    pending = nil
    local id = ReadDisplayID()
    if id and not BOSS_DISPLAY[name] then Save(name, id) end
end)

-- Learn the portrait of `unit` if it is a boss of this dungeon without one.
-- Returns a short reason (shown by /bnav portrait).
local function LearnPortrait(unit)
    if type(unit) ~= "string" then return "no unit" end
    local boss = IdentifyBoss(unit)
    if not boss then return "not recognised as a boss of this dungeon" end
    local name = boss[1]
    if BOSS_DISPLAY[name] then return name .. " already has a portrait" end
    if not (probe.SetUnit and probe.GetDisplayInfo) then return "this client cannot read creature models" end
    local ok = pcall(probe.SetUnit, probe, unit)
    if not ok then return "the client refused to load " .. name .. "'s model" end
    local id = ReadDisplayID()
    if id then
        Save(name, id)
        return "learned"
    end
    pending = name
    return name .. "'s model is still loading (or its ID is hidden); try again in a moment"
end

-- The encounter began: the game exposes the bosses as boss1..boss5.
local function LearnEncounterPortraits()
    for i = 1, 5 do pcall(LearnPortrait, "boss" .. i) end
end

-- Put the saved portraits back at login.
local function ApplySavedPortraits()
    local saved = DB().bossDisplay
    if type(saved) ~= "table" then return end
    for name, id in pairs(saved) do
        if BOSS_DISPLAY[name] == nil and type(id) == "number" then
            BOSS_DISPLAY[name] = id
            learned[name] = true
        end
    end
end

local function PortraitCommand(rest)
    rest = (rest or ""):lower()
    if rest == "clear" then
        for name in pairs(learned) do BOSS_DISPLAY[name] = nil end
        wipe(learned)
        DB().bossDisplay = {}
        Print("Learned boss portraits forgotten.")
        if ns.RefreshIfShown then pcall(ns.RefreshIfShown) end
    elseif rest == "list" then
        local names = {}
        for name in pairs(learned) do names[#names + 1] = name end
        table.sort(names)
        Print(#names .. " learned boss portraits" .. (#names > 0 and (": " .. table.concat(names, ", ")) or "."))
    else
        Print("portrait: " .. tostring(LearnPortrait("target")))
    end
end

-- /bnav portrait [list|clear]
ns.AddCommand({ "portrait", "portraits", "icon", "icons" }, PortraitCommand, {
    "  /bnav portrait        learn the portrait of the boss you target (also happens by itself)",
    "  /bnav portrait list   which boss portraits were learned in game; 'clear' forgets them",
})

-- shared with the other BossNav files
ns.ApplySavedPortraits = ApplySavedPortraits
ns.LearnEncounterPortraits = LearnEncounterPortraits
ns.LearnPortrait = LearnPortrait
