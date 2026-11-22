-- The map area while you are outside every dungeon and the Bosses column has
-- the focus: the map and boss pins of the dungeon picked in the dungeon list,
-- so you can read up on a dungeon before you walk in. (The boss column itself
-- is drawn by BossNav_Render.lua.) Kills come from the saved progress of your
-- current run there, if it is still fresh.
local ADDON, ns = ...
-- from the files loaded before this one
local DrawBossArt            = ns.DrawBossArt
local DrawBossPins           = ns.DrawBossPins
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

local previewIdx, previewCfg = 1, nil

-- The dungeon this shows: the one picked in the dungeon list.
local function PreviewCfg()
    local e = SelectedDungeon()
    local cfg = e and e.cfg or nil
    -- by table: the parts of a split dungeon share one key
    if cfg and cfg ~= previewCfg then
        previewCfg = cfg
        previewIdx = 1
    end
    return cfg
end

local function SelectPreviewBoss(idx)
    local cfg = PreviewCfg()
    if not cfg or not cfg.bosses[idx] then return false end
    previewIdx = idx
    if ns.PickItemBoss then ns.PickItemBoss(cfg, cfg.bosses[idx][1]) end
    RefreshIfShown()
    return true
end

-- step 1 / -1; false when there is no list to walk. The Trash row after the
-- last boss is one more stop.
local function CyclePreviewBoss(step)
    local cfg = PreviewCfg()
    local n = cfg and #cfg.bosses or 0
    if n == 0 then return false end
    -- start from the boss the Items column is filtered to (none after a dungeon pick)
    local cur = cfg.bosses[previewIdx] and ns.ItemBoss() == cfg.bosses[previewIdx][1] and previewIdx or nil
    local nxt = ns.StepBossColumn(cfg, cur, step)
    if nxt == "trash" then
        ns.PickTrash(cfg)
        RefreshIfShown()
        return true
    end
    return SelectPreviewBoss(nxt)
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
        noArtText:SetText("Pick a dungeon in the Dungeons column (or /bnav go name)\nand its bosses show up here.")
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

    navText:SetText("You are outside. The arrow leads you to the entrance.")
    BossNav_UpdateLive(true)
    return true
end

-- The dungeon and boss the boss column shows while you are outside.
local function PreviewState()
    return PreviewCfg(), previewIdx
end

-- shared with the other BossNav files
ns.CyclePreviewBoss = CyclePreviewBoss
ns.PreviewState = PreviewState
ns.RenderBossPreview = RenderBossPreview
ns.SelectPreviewBoss = SelectPreviewBoss
