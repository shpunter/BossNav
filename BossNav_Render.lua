-- Drawing the whole map window.
local ADDON, ns = ...
-- from the files loaded before this one
local CurrentFloor           = ns.CurrentFloor
local FloorFromMapGroup      = ns.FloorFromMapGroup
local FloorName              = ns.FloorName
local GetBossPin             = ns.GetBossPin
local GetRow                 = ns.GetRow
local GetWayPin              = ns.GetWayPin
local HELP_BOSS              = ns.HELP_BOSS
local KilledCount            = ns.KilledCount
local MAX_ROWS               = ns.MAX_ROWS
local Place                  = ns.Place
local PlayerMapID            = ns.PlayerMapID
local RenderBlank            = ns.RenderBlank
local RenderBundled          = ns.RenderBundled
local RenderLegacy           = ns.RenderLegacy
local RenderNative           = ns.RenderNative
local SelectedBoss           = ns.SelectedBoss
local SetBossIcon            = ns.SetBossIcon
local UpdateTabLook          = ns.UpdateTabLook
local WaypointKey            = ns.WaypointKey
local Waypoints              = ns.Waypoints
local bossPins               = ns.bossPins
local bossRows               = ns.bossRows
local headerText             = ns.headerText
local helpText               = ns.helpText
local mapFrame               = ns.mapFrame
local navText                = ns.navText
local noArtText              = ns.noArtText
local playerPin              = ns.playerPin
local state                  = ns.state
local statusText             = ns.statusText
local wayPins                = ns.wayPins

--------------------------------------------------------------------------
-- Pieces of the boss view, shared with the outside boss list
-- (BossNav_BossPreview.lua). `killed` is a [bossName] = true table.
--------------------------------------------------------------------------
local function RefreshIfShown()
    if mapFrame:IsShown() then BossNav_RefreshMap() end
end

-- Map art of one floor. liveMap is the uiMapID you stand on (inside only).
local function DrawBossArt(cfg, floor, liveMap)
    local rendered = false
    if cfg.bundled then
        rendered = RenderBundled(cfg)
    end
    if not rendered and liveMap and (not state.autoFloor or state.autoFloor == floor) then
        rendered = RenderNative(liveMap)
    end
    if not rendered then
        rendered = RenderLegacy(cfg, floor)
    end
    if not rendered then
        RenderBlank()
        noArtText:SetText("This client exposes no map art for " .. cfg.name .. ".\nBoss pins and your waypoints are still shown.")
        noArtText:Show()
    end
end

local function DrawBossPins(cfg, floor, bossIdx, killed)
    local shown = 0
    for i, b in ipairs(cfg.bosses) do
        if b[2] and b[3] and (b[4] or cfg.floors[1]) == floor then
            shown = shown + 1
            local p = GetBossPin(shown)
            p.bossIdx = i
            Place(p, b[2] / 100, b[3] / 100)
            local dead = killed[b[1]]
            SetBossIcon(p.icon, b[1], dead)
            if i == bossIdx then
                p:SetSize(28, 28); p.ring:Show()
                p.label:SetText("|cffffd100" .. b[1] .. "|r")
                p.label:Show()
            else
                p:SetSize(22, 22); p.ring:Hide()
                p.label:Hide()
            end
            p:Show()
        end
    end
end

-- The trail to a boss. visited is a [WaypointKey] = true table.
local function DrawWaypoints(cfg, boss, floor, visited)
    local wps = Waypoints(cfg, boss)
    if not wps then return end
    for i, wp in ipairs(wps) do
        if (not wp.floor) or wp.floor == floor then
            local p = GetWayPin(i)
            Place(p, wp.x / 100, wp.y / 100)
            if visited[WaypointKey(cfg, boss, i)] then
                p.dot:SetTexture("Interface\\COMMON\\Indicator-Gray")
                p.num:SetText("|cff888888" .. i .. "|r")
            else
                p.dot:SetTexture("Interface\\COMMON\\Indicator-Yellow")
                p.num:SetText("|cffffd100" .. i .. ((wp.note and wp.note ~= "") and (" " .. wp.note) or "") .. "|r")
            end
            p:Show()
        end
    end
end

local function DrawBossRows(cfg, bossIdx, killed)
    for i, b in ipairs(cfg.bosses) do
        if i > MAX_ROWS then break end
        local r = GetRow(i)
        local dead = killed[b[1]]
        local color = dead and "|cff777777" or ((i == bossIdx) and "|cffffd100" or "|cffffffff")
        local tag = dead and " |cff777777[DEAD]|r" or ""
        if not b[2] then tag = tag .. " |cff666666(no pin)|r" end
        r.bossIdx = i
        r.travelIdx = nil
        r:SetMapButton(false)
        r.mark:SetText((i == bossIdx) and ns.SELECTED_MARK or "")
        r.mark:Show()
        SetBossIcon(r.icon, b[1], dead)
        r.text:SetText(color .. b[1] .. "|r" .. tag)
        r:Show()
    end
    if #cfg.bosses > MAX_ROWS then
        local last = GetRow(MAX_ROWS)
        last.bossIdx = nil
        last.travelIdx = nil
        last:SetMapButton(false)
        last.icon:Hide()
        last.mark:Hide()
        last.text:SetText("|cff888888... and " .. (#cfg.bosses - MAX_ROWS + 1) .. " more|r")
    end
end

--------------------------------------------------------------------------
-- Rendering the whole window
--------------------------------------------------------------------------
function BossNav_RefreshMap()
    for _, p in ipairs(bossPins) do p:Hide() end
    for _, p in ipairs(wayPins) do p:Hide() end
    for _, r in ipairs(bossRows) do r:Hide() end
    playerPin:Hide()
    noArtText:Hide()
    if ns.HideTravelWidgets then ns.HideTravelWidgets() end
    if ns.HideStartPin then ns.HideStartPin() end

    -- Loot / Profs / Quests tabs: their panel covers the map and fills the
    -- sidebar instead. All are always called so the ones not shown hide themselves.
    UpdateTabLook()
    local drewLoot = ns.RenderLootTab and ns.RenderLootTab()
    local drewProf = ns.RenderProfTab and ns.RenderProfTab()
    local drewQuest = ns.RenderQuestTab and ns.RenderQuestTab()
    if drewLoot or drewProf or drewQuest then return end

    -- Outside every dungeon: the Travel tab (your zone map and the dungeon
    -- selector) or the Bosses tab (the picked dungeon's bosses).
    helpText:SetText(HELP_BOSS)
    if ns.RenderTravelTab and ns.RenderTravelTab() then return end
    if ns.RenderBossPreview and ns.RenderBossPreview() then return end

    local cfg = state.cfg
    if not cfg then
        RenderBlank()
        headerText:SetText("|cffffd100BossNav|r")
        statusText:SetText("No boss data for: " .. tostring(state.zoneName or GetRealZoneText() or "Unknown"))
        navText:SetText("Enter a dungeon, or type |cffffd100/bnav test|r to preview Wailing Caverns.")
        noArtText:SetText("No map for this zone")
        noArtText:Show()
        return
    end

    -- Sync the player's map / floor first so the right floor is drawn
    local mapID = PlayerMapID()
    if mapID ~= state.mapID then
        state.mapID = mapID
        state.autoFloor = (mapID and state.inInstance) and FloorFromMapGroup(cfg, mapID) or nil
    end

    -- Floor + art
    local floor = CurrentFloor(cfg)
    state.shownFloor = floor
    DrawBossArt(cfg, floor, state.inInstance and state.mapID or nil)

    -- Header
    local boss = SelectedBoss()
    local floorLabel = (#cfg.floors > 1) and ("  |cff888888" .. FloorName(cfg, floor) .. "|r") or ""
    headerText:SetText(string.format("|cffffd100%s|r%s", cfg.name, floorLabel))
    if boss then
        local dead = state.killed[boss[1]]
        statusText:SetText(string.format("Target: |cff%s%s|r%s   |cff888888Killed %d/%d|r",
            dead and "888888" or "00ff00", boss[1], dead and "  [DEAD]" or "", KilledCount(cfg), #cfg.bosses))
    else
        statusText:SetText("")
    end

    DrawBossPins(cfg, floor, state.bossIdx, state.killed)
    DrawWaypoints(cfg, boss, floor, state.visited)
    DrawBossRows(cfg, state.bossIdx, state.killed)

    navText:SetText("")
    BossNav_UpdateLive(true)
end

-- shared with the other BossNav files
ns.DrawBossArt = DrawBossArt
ns.DrawBossPins = DrawBossPins
ns.DrawBossRows = DrawBossRows
ns.DrawWaypoints = DrawWaypoints
ns.RefreshIfShown = RefreshIfShown
