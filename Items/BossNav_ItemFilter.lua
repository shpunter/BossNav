-- Which items the Items view lists. Filters today:
--   dungeon  the dungeon you are in, else the one picked in the Dungeons column
--            (no pick: every dungeon)
--   boss     the boss you last picked in the Bosses column (a click, the
--            Select Next / Previous Boss keys or /bnav boss). Picking another
--            dungeon drops it; /bnav items all drops it by hand. The Trash
--            row under the bosses (or /bnav items trash) picks every
--            non-boss source instead: trash, rares, mini-bosses.
-- More filters go here later: each is one more test in Passes().
local ADDON, ns = ...
-- from the files loaded before this one
local DUNGEONS               = ns.DUNGEONS
local ITEM_SOURCES           = ns.ITEM_SOURCES
local SelectedDungeon        = ns.SelectedDungeon
local TravelMode             = ns.TravelMode
local state                  = ns.state

-- state.itemBoss = { dungeon = "Wailing Caverns", boss = "Kresh" } or nil

-- The dungeon the Items view is about, or nil for every dungeon.
local function ItemDungeon()
    if not TravelMode() then return state.cfg end
    local e = SelectedDungeon and SelectedDungeon()
    return e and e.cfg or nil
end

-- The boss filter, or nil when it belongs to another dungeon than the one shown.
local function ItemBoss()
    local f = state.itemBoss
    local cfg = ItemDungeon()
    if not (f and cfg and f.dungeon == cfg.name) then return nil end
    return f.boss
end

-- Called when you pick a boss on the Bosses view.
local function PickItemBoss(cfg, bossName)
    if not (cfg and bossName) then return end
    state.itemBoss = { dungeon = cfg.name, boss = bossName }
    state.itemIdx = 1
end

local function ClearItemBoss()
    state.itemBoss = nil
    state.itemIdx = 1
end

-- The "Trash" row at the bottom of the Bosses column: every source that is not
-- a regular boss (trash, rares, mini-bosses and the like).
local TRASH = "Trash"

local function HasTrash(cfg)
    for _, src in ipairs(cfg and ITEM_SOURCES[cfg.name] or {}) do
        if src.extra then return true end
    end
    return false
end

local function TrashPicked(cfg)
    local f = state.itemBoss
    return (f and cfg and f.dungeon == cfg.name and f.boss == TRASH) and true or false
end

local function PickTrash(cfg)
    PickItemBoss(cfg, TRASH)
end

-- Where a Next / Previous key press lands in the Bosses column: a boss index,
-- or "trash" for the Trash row after the last boss. idx is the current boss.
local function StepBossColumn(cfg, idx, step)
    local n = #cfg.bosses
    local slots = n + (HasTrash(cfg) and 1 or 0)
    if slots == 0 then return nil end
    local pos = TrashPicked(cfg) and (n + 1) or (idx or 1)
    local nxt = ((pos - 1 + step) % slots) + 1
    if nxt > n then return "trash" end
    return nxt
end

local function Passes(src, boss)
    if boss == TRASH then return src.extra and true or false end
    if boss and src.boss ~= boss then return false end
    return true
end

-- One list entry per item and source: { id, boss, dungeon, chance, extra }.
-- Order: dungeons as in the dungeon list, bosses in kill order, then rares,
-- trash and other sources.
local function AddDungeon(list, cfg, boss)
    for _, src in ipairs(ITEM_SOURCES[cfg.name] or {}) do
        if Passes(src, boss) then
            for i, id in ipairs(src.items) do
                local chance = src.chance[i]
                list[#list + 1] = {
                    id = id, boss = src.boss, dungeon = cfg.name, extra = src.extra,
                    chance = (chance and chance > 0) and chance or nil,
                }
            end
        end
    end
end

local cache = { key = nil, list = nil }
local function FilteredItems()
    local cfg = ItemDungeon()
    local boss = ItemBoss()
    local key = (cfg and cfg.name or "*") .. "|" .. (boss or "*")
    if cache.key == key then return cache.list, cfg, boss end
    local list = {}
    if cfg then
        AddDungeon(list, cfg, boss)
    else
        for _, d in ipairs(DUNGEONS) do AddDungeon(list, d, nil) end
    end
    cache.key, cache.list = key, list
    return list, cfg, boss
end

-- shared with the other BossNav files
ns.ClearItemBoss = ClearItemBoss
ns.FilteredItems = FilteredItems
ns.HasTrash = HasTrash
ns.ItemBoss = ItemBoss
ns.ItemDungeon = ItemDungeon
ns.PickItemBoss = PickItemBoss
ns.PickTrash = PickTrash
ns.StepBossColumn = StepBossColumn
ns.TRASH = TRASH
ns.TrashPicked = TrashPicked
