-- Periodic live update.
local ADDON, ns = ...
-- from the files loaded before this one
local AreaWord               = ns.AreaWord
local DirectionWord          = ns.DirectionWord
local FloorFromMapGroup      = ns.FloorFromMapGroup
local FloorName              = ns.FloorName
local GoldText               = ns.GoldText
local XPText                 = ns.XPText
local HideMinimapPins        = ns.HideMinimapPins
local KilledCount            = ns.KilledCount
local MapWorldSize           = ns.MapWorldSize
local Place                  = ns.Place
local PlayerFacing           = ns.PlayerFacing
local PlayerMapID            = ns.PlayerMapID
local PlayerPos              = ns.PlayerPos
local RefreshIfShown         = ns.RefreshIfShown
local SafeCall               = ns.SafeCall
local SelectedBoss           = ns.SelectedBoss
local SetBossIcon            = ns.SetBossIcon
local TouchProgress          = ns.TouchProgress
local UpdateMinimapPins      = ns.UpdateMinimapPins
local WAYPOINT_RADIUS        = ns.WAYPOINT_RADIUS
local WaypointKey            = ns.WaypointKey
local Waypoints              = ns.Waypoints
local atan2                  = ns.atan2
local hud                    = ns.hud
local mapFrame               = ns.mapFrame
local navText                = ns.navText
local playerPin              = ns.playerPin
local state                  = ns.state

--------------------------------------------------------------------------
-- Live update: player marker, HUD arrow, waypoint progress, floor changes
--------------------------------------------------------------------------
local function UpdateLive(skipRefresh)
    -- Outside every dungeon the travel arrow runs instead (BossNav_Travel.lua).
    if ns.TravelMode and ns.TravelMode() then
        ns.UpdateTravelLive(skipRefresh)
        return
    end
    local cfg = state.cfg
    local mapID = PlayerMapID()
    if mapID ~= state.mapID then
        state.mapID = mapID
        state.autoFloor = nil
        if cfg and mapID and state.inInstance then
            state.autoFloor = FloorFromMapGroup(cfg, mapID)
        end
        if not skipRefresh then RefreshIfShown() return end
    end
    if not cfg then
        playerPin:Hide()
        HideMinimapPins()
        return
    end

    local px, py
    if mapID and state.inInstance then px, py = PlayerPos(mapID) end
    local facing = PlayerFacing()
    local boss = SelectedBoss()
    local playerFloor = state.autoFloor or state.shownFloor
    local bossFloor = boss and (boss[4] or cfg.floors[1]) or nil

    pcall(UpdateMinimapPins, mapID, px, py, facing)

    -- Player marker on the map
    if mapFrame:IsShown() then
        local onShownMap = px and (ns.renderedMapID == nil or ns.renderedMapID == mapID)
            and (not state.autoFloor or state.autoFloor == state.shownFloor)
        if onShownMap then
            Place(playerPin, px, py)
            if facing and playerPin.arrow.SetRotation then playerPin.arrow:SetRotation(facing) end
            playerPin:Show()
        else
            playerPin:Hide()
        end

        -- Waypoint progress: dots you walk over turn grey
        local wps = Waypoints(cfg, boss)
        if px and wps then
            for i, wp in ipairs(wps) do
                local key = WaypointKey(cfg, boss, i)
                if not state.visited[key] and ((not wp.floor) or wp.floor == playerFloor) then
                    local dx, dy = wp.x / 100 - px, wp.y / 100 - py
                    if dx * dx + dy * dy < WAYPOINT_RADIUS * WAYPOINT_RADIUS then
                        state.visited[key] = true
                        TouchProgress()
                        if not skipRefresh then RefreshIfShown() return end
                    end
                end
            end
        end
    end

    -- Direction text + HUD
    if not boss then
        hud.main:SetText("|cffffd100" .. cfg.name .. "|r")
        hud.sub:SetText("No boss selected. /bnav boss")
        hud.arrow:Hide()
        hud.icon:Hide()
        navText:SetText("")
        return
    end

    local dead = state.killed[boss[1]]
    SetBossIcon(hud.icon, boss[1], dead)
    hud.icon:SetSize(34, 34)   -- the travel HUD shrinks it for a quest icon
    hud.main:SetText(string.format("|cff%s%s|r  |cff888888Killed %d/%d|r",
        dead and "888888" or "ffd100", boss[1], KilledCount(cfg)))

    if dead then
        hud.arrow:Hide()
        hud.sub:SetText("|cff00ff00Defeated.|r Next target: /bnav boss")
        navText:SetText("|cff00ff00" .. boss[1] .. " is dead.|r  /bnav boss selects the next one.")
        return
    end

    if not boss[2] then
        hud.arrow:Hide()
        -- the earnings stay on the bar; the markboss hint is on the map window
        hud.sub:SetText(GoldText() .. XPText() .. "  |cff888888(no pin yet)|r")
        navText:SetText("No map pin for " .. boss[1] .. ". Stand at the boss and type |cffffd100/bnav markboss|r to record it.")
        return
    end

    if bossFloor and playerFloor and bossFloor ~= playerFloor and state.autoFloor then
        hud.arrow:Hide()
        hud.sub:SetText("On " .. FloorName(cfg, bossFloor) .. ". You are on " .. FloorName(cfg, playerFloor) .. ".")
        navText:SetText(boss[1] .. " is on |cffffd100" .. FloorName(cfg, bossFloor) .. "|r. /bnav floor switches the map floor.")
        return
    end

    if not px then
        hud.arrow:Hide()
        local where = AreaWord(boss[2], boss[3])
        local floorHint = (#cfg.floors > 1) and (", " .. FloorName(cfg, bossFloor)) or ""
        hud.sub:SetText(GoldText() .. XPText())
        navText:SetText(string.format("|cffffd100%s|r is in %s%s. This client hides your position in dungeons, so follow the pin on the map.",
            boss[1], where, floorHint))
        return
    end

    -- Bearing from player to boss. Map x grows east, y grows south.
    -- WoW facing is radians counter-clockwise from north, as is SetRotation.
    local dx, dy = boss[2] / 100 - px, boss[3] / 100 - py
    local bearing = atan2(-dx, -dy)
    local rel = bearing - (facing or 0)
    if hud.arrow.SetRotation then hud.arrow:SetRotation(rel) end
    hud.arrow:Show()

    local distText = ""
    local ww, wh = MapWorldSize(mapID)
    if ww then
        local yards = math.sqrt((dx * ww) ^ 2 + (dy * wh) ^ 2)
        distText = string.format("%d yd, ", math.floor(yards))
    end
    local dir = facing and DirectionWord(rel) or "see map"
    local sub = GetSubZoneText()
    hud.sub:SetText(distText .. dir .. ((sub and sub ~= "") and ("  |cff888888" .. sub .. "|r") or ""))
    navText:SetText(string.format("|cffffd100%s|r: %s%s", boss[1], distText, dir))
end

-- Every path above writes the HUD lines, so the bar is refitted once here.
function BossNav_UpdateLive(skipRefresh)
    UpdateLive(skipRefresh)
    ns.FitHUD()
end

local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.1 then return end
    acc = 0
    local minimapActive = state.inInstance and state.cfg and BossNavDB.minimap
    local travelActive = ns.TravelActive and ns.TravelActive()
    if mapFrame:IsShown() or hud:IsShown() or minimapActive or travelActive then
        SafeCall(BossNav_UpdateLive)
    end
end)
