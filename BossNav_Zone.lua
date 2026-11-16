-- Zone changes.
local ADDON, ns = ...
-- from the files loaded before this one
local HideMinimapPins        = ns.HideMinimapPins
local LoadProgress           = ns.LoadProgress
local Norm                   = ns.Norm
local Print                  = ns.Print
local RefreshIfShown         = ns.RefreshIfShown
local TouchProgress          = ns.TouchProgress
local UpdateHUDVisibility    = ns.UpdateHUDVisibility
local ZONE_INDEX             = ns.ZONE_INDEX
local hud                    = ns.hud
local mmCache                = ns.mmCache
local state                  = ns.state

--------------------------------------------------------------------------
-- Zone handling
--------------------------------------------------------------------------
local function UpdateZone()
    local zone = GetRealZoneText()
    local cfg = ZONE_INDEX[Norm(zone)]
    local prevCfg = state.cfg
    state.inInstance = IsInInstance() and true or false
    if state.testMode and not cfg then
        -- keep the preview until the player actually enters a known dungeon
        UpdateHUDVisibility()
        RefreshIfShown()
        return
    end
    local wasTest = state.testMode
    state.testMode = false
    if cfg ~= state.cfg or wasTest then
        state.cfg = cfg
        state.zoneName = zone
        LoadProgress(cfg)
        state.floorOverride = nil
        state.autoFloor = nil
        state.mapID = nil
        if cfg then
            local done = 0
            for _ in pairs(state.killed) do done = done + 1 end
            local remembered = done > 0 and string.format(" %d already marked dead (/bnav reset clears).", done) or ""
            Print(string.format("%s: %d bosses.%s /bnav opens the map, /bnav boss picks the target.", cfg.name, #cfg.bosses, remembered))
        end
    else
        state.zoneName = zone
        -- Still in the same dungeon: keep the saved progress fresh.
        if cfg and state.inInstance then TouchProgress() end
    end
    UpdateHUDVisibility()
    RefreshIfShown()
    mmCache.zoom = nil   -- indoor/outdoor minimap mode may have changed
    if not state.inInstance then HideMinimapPins() end
    -- Travel mode: arriving at the chosen dungeon, or a corpse run back to it
    if ns.TravelOnZone then pcall(ns.TravelOnZone, prevCfg) end
    UpdateHUDVisibility()
    if hud:IsShown() then pcall(BossNav_UpdateLive, true) end
end

-- shared with the other BossNav files
ns.UpdateZone = UpdateZone
