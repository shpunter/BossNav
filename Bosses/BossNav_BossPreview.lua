-- The Bosses tab while you are outside every dungeon: the map, boss pins and
-- boss list of the dungeon picked on the Travel tab, so you can read up on a
-- dungeon before you walk in. Kills come from the saved progress of your
-- current run there, if it is still fresh.
local ADDON, ns = ...
-- from the files loaded before this one
local DrawBossArt            = ns.DrawBossArt
local DrawBossPins           = ns.DrawBossPins
local DrawBossRows           = ns.DrawBossRows
local DrawWaypoints          = ns.DrawWaypoints
local FloorName              = ns.FloorName
local RefreshIfShown         = ns.RefreshIfShown
local RenderBlank            = ns.RenderBlank
local SavedKilled            = ns.SavedKilled
local SelectedDungeon        = ns.SelectedDungeon
local TravelMode             = ns.TravelMode
local headerText             = ns.headerText
local helpText               = ns.helpText
local navText                = ns.navText
local noArtText              = ns.noArtText
local state                  = ns.state
local statusText             = ns.statusText

local HELP_PREVIEW = "Select Next / Previous Boss keys walk the list | /bnav tab travel picks another dungeon | /bnav go name"
local NO_VISITS = {}

local previewIdx, previewKey = 1, nil

-- The dungeon this tab shows: the one picked on the Travel tab.
local function PreviewCfg()
    local e = SelectedDungeon()
    local cfg = e and e.cfg or nil
    if cfg and cfg.key ~= previewKey then
        previewKey = cfg.key
        previewIdx = 1
    end
    return cfg
end

local function SelectPreviewBoss(idx)
    local cfg = PreviewCfg()
    if not cfg or not cfg.bosses[idx] then return false end
    previewIdx = idx
    RefreshIfShown()
    return true
end

-- step 1 / -1; false when there is no list to walk
local function CyclePreviewBoss(step)
    local cfg = PreviewCfg()
    local n = cfg and #cfg.bosses or 0
    if n == 0 then return false end
    return SelectPreviewBoss(((previewIdx - 1 + step) % n) + 1)
end

-- Draws the whole window; false inside a dungeon or on another tab.
local function RenderBossPreview()
    if not TravelMode() or state.tab ~= "boss" then return false end
    helpText:SetText(HELP_PREVIEW)

    local cfg = PreviewCfg()
    if not cfg then
        RenderBlank()
        headerText:SetText("|cffffd100Bosses|r")
        statusText:SetText("")
        navText:SetText("")
        noArtText:SetText("Pick a dungeon on the Travel tab (or /bnav go name)\nand its bosses show up here.")
        noArtText:Show()
        return true
    end

    local boss = cfg.bosses[previewIdx]
    local floor = (boss and boss[4]) or cfg.floors[1]
    state.shownFloor = floor
    DrawBossArt(cfg, floor, nil)

    local killed = SavedKilled(cfg)
    local done = 0
    for _, b in ipairs(cfg.bosses) do
        if killed[b[1]] then done = done + 1 end
    end
    local floorLabel = (#cfg.floors > 1) and ("  |cff888888" .. FloorName(cfg, floor) .. "|r") or ""
    headerText:SetText(string.format("|cffffd100%s|r%s  |cff888888(outside)|r", cfg.name, floorLabel))
    if boss then
        statusText:SetText(string.format("Boss: |cffffd100%s|r   |cff888888Killed %d/%d|r", boss[1], done, #cfg.bosses))
    else
        statusText:SetText("")
    end

    DrawBossPins(cfg, floor, previewIdx, killed)
    DrawWaypoints(cfg, boss, floor, NO_VISITS)
    DrawBossRows(cfg, previewIdx, killed)

    navText:SetText("You are outside. The Travel tab leads you to the entrance.")
    BossNav_UpdateLive(true)
    return true
end

-- shared with the other BossNav files
ns.CyclePreviewBoss = CyclePreviewBoss
ns.RenderBossPreview = RenderBossPreview
ns.SelectPreviewBoss = SelectPreviewBoss
