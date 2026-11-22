-- Event wiring.
local ADDON, ns = ...
-- from the files loaded before this one
local ApplySavedBossPins     = ns.ApplySavedBossPins
local ApplySavedExtraBosses  = ns.ApplySavedExtraBosses
local ApplySavedPortraits    = ns.ApplySavedPortraits
local LearnEncounterPortraits = ns.LearnEncounterPortraits
local LearnPortrait          = ns.LearnPortrait
local CheckInstanceCopy      = ns.CheckInstanceCopy
local CheckTargetDead        = ns.CheckTargetDead
local ClearLoot              = ns.ClearLoot
local ClearProfs             = ns.ClearProfs
local ColorPlate             = ns.ColorPlate
local ColorUnitFrames        = ns.ColorUnitFrames
local DB                     = ns.DB
local DropOtherFactionBosses = ns.DropOtherFactionBosses
local EnsureNameplates       = ns.EnsureNameplates
local IsSecret               = ns.IsSecret
local OnBossKilled           = ns.OnBossKilled
local OnEncounterStart       = ns.OnEncounterStart
local OnGroupRosterChanged   = ns.OnGroupRosterChanged
local OnLootMessage          = ns.OnLootMessage
local OnLootPopup            = ns.OnLootPopup
local OnMoneyChanged         = ns.OnMoneyChanged
local OnProfLootMessage      = ns.OnProfLootMessage
local OnTradeSkillMessage    = ns.OnTradeSkillMessage
local OnQuestTurnedIn        = ns.OnQuestTurnedIn
local OnUnitSpellcast        = ns.OnUnitSpellcast
local Print                  = ns.Print
local RefreshIfShown         = ns.RefreshIfShown
local RestoreTravelTarget    = ns.RestoreTravelTarget
local SafeCall               = ns.SafeCall
local SetupWorldMapPins      = ns.SetupWorldMapPins
local TryMarkUnit            = ns.TryMarkUnit
local UpdateZone             = ns.UpdateZone
local state                  = ns.state

--------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------
-- Left the party: wipe dungeon progress, loot rolls and profession counts.
local function CheckLeftGroup()
    if not OnGroupRosterChanged() then return end
    ClearLoot()
    ClearProfs()
    Print("Left the group: dungeon progress, loot rolls and profession counts reset.")
    RefreshIfShown()
    SafeCall(BossNav_UpdateLive, true)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("ZONE_CHANGED_INDOORS")
events:RegisterEvent("ENCOUNTER_END")
events:RegisterEvent("BOSS_KILL")
events:RegisterEvent("PLAYER_MONEY")
-- Travel list: dungeons above your level are red, so a level-up redraws it.
events:RegisterEvent("PLAYER_LEVEL_UP")
-- Quests tab: taking, handing in or dropping a quest changes what is crossed out.
-- Objective progress (the "?" turns yellow when a quest is ready to hand in).
for _, ev in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "UNIT_QUEST_LOG_CHANGED" }) do
    pcall(events.RegisterEvent, events, ev)
end
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("UNIT_HEALTH")
-- Auto skull mark: a boss becomes visible through its nameplate, your target, or the encounter.
-- Class plates: a player's nameplate gets its class colour when it appears.
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
-- Class frames: the target of your target changed (target / group changes use the events above).
events:RegisterEvent("UNIT_TARGET")
events:RegisterEvent("ENCOUNTER_START")
events:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
-- Loot roll tracker: the game's own "X has selected Need for: [item]" chat lines.
events:RegisterEvent("CHAT_MSG_LOOT")
-- Profession tracker: every gather and every recipe is a spell cast of a group unit.
events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
-- ...and for teammates, whose cast spells the client hides: "Bob creates [X]."
events:RegisterEvent("CHAT_MSG_TRADESKILLS")
-- (blocked calls are reported by BossNav_BlockReport.lua)

events:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4, arg5)
    if event == "ADDON_LOADED" then
        if arg1 == "BossNav" then
            DB()
            ApplySavedExtraBosses()
            DropOtherFactionBosses()
            ApplySavedBossPins()
            ApplySavedPortraits()
            RestoreTravelTarget()
            Print("loaded. /bnav opens the map, /bnav help lists commands.")
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if event == "PLAYER_ENTERING_WORLD" then
            -- the group list can be empty for a moment right after login
            if C_Timer and C_Timer.After then C_Timer.After(3, CheckLeftGroup) else CheckLeftGroup() end
            SetupWorldMapPins()   -- the map frame may not have existed at load time
            if DB().threat then EnsureNameplates() end   -- the threat window sees mobs through them
            ColorUnitFrames()
        end
        DropOtherFactionBosses()   -- the faction may be unknown at ADDON_LOADED
        UpdateZone()
        OnMoneyChanged()   -- sets the purse baseline after a load or zone change
    elseif event == "GROUP_ROSTER_UPDATE" then
        CheckLeftGroup()
        ColorUnitFrames()
    elseif event == "UNIT_TARGET" then
        if arg1 == "target" then ColorUnitFrames() end
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        if state.cfg and state.cfg.floorBySubzone and not state.floorOverride and not state.autoFloor then
            RefreshIfShown()
        end
    elseif event == "PLAYER_MONEY" then
        OnMoneyChanged()
    elseif event == "PLAYER_LEVEL_UP" then
        RefreshIfShown()
    elseif event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED" then
        if event == "QUEST_TURNED_IN" then OnQuestTurnedIn(arg1) end
        -- the quest log settles a moment after these events
        if C_Timer and C_Timer.After then C_Timer.After(0.5, RefreshIfShown) else RefreshIfShown() end
    elseif event == "UNIT_QUEST_LOG_CHANGED" then
        if arg1 == "player" and state.tab == "quest" then
            if C_Timer and C_Timer.After then C_Timer.After(0.5, RefreshIfShown) else RefreshIfShown() end
        end
    elseif event == "ENCOUNTER_END" then
        -- encounterID, encounterName, difficultyID, groupSize, success
        if not IsSecret(arg2) and not IsSecret(arg5) and type(arg2) == "string" and (arg5 == 1 or arg5 == true) then
            OnBossKilled(arg2)
        end
    elseif event == "BOSS_KILL" then
        if not IsSecret(arg2) and type(arg2) == "string" then OnBossKilled(arg2) end
    elseif event == "PLAYER_TARGET_CHANGED" or (event == "UNIT_HEALTH" and arg1 == "target") then
        SafeCall(CheckTargetDead)
        if event == "PLAYER_TARGET_CHANGED" then
            ColorUnitFrames()
            SafeCall(CheckInstanceCopy, "target")
            SafeCall(TryMarkUnit, "target")
            SafeCall(LearnPortrait, "target")
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        SafeCall(CheckInstanceCopy, arg1)
        SafeCall(TryMarkUnit, arg1)
        SafeCall(LearnPortrait, arg1)
        SafeCall(ColorPlate, arg1)
    elseif event == "ENCOUNTER_START" then
        -- encounterID, encounterName, difficultyID, groupSize
        SafeCall(OnEncounterStart, arg2)
        SafeCall(LearnEncounterPortraits)
    elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        SafeCall(OnEncounterStart)
        SafeCall(LearnEncounterPortraits)
    elseif event == "CHAT_MSG_LOOT" then
        local ok, drop = SafeCall(OnLootMessage, arg1)
        if ok and drop then SafeCall(OnLootPopup, drop) end
        SafeCall(OnProfLootMessage, arg1)
    elseif event == "CHAT_MSG_TRADESKILLS" then
        SafeCall(OnTradeSkillMessage, arg1)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        SafeCall(OnUnitSpellcast, arg1, arg2, arg3, arg4, arg5)
    end
end)
