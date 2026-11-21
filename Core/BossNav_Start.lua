-- The start point of a dungeon: where you stand after entering, drawn as a
-- green "Start" pin on the dungeon map.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local Norm                   = ns.Norm
local Place                  = ns.Place
local pinLayer               = ns.pinLayer

--------------------------------------------------------------------------
-- Built-in start spots: percent across, percent down the dungeon map, and
-- the floor. Approximate, read off the classic maps; /bnav start X Y
-- records a better one (saved) for the dungeon you are in.
--------------------------------------------------------------------------
local STARTS = {
    ["Ragefire Chasm"]     = { 70, 30, 1 },
    ["Wailing Caverns"]    = { 41, 47, 1 },
    ["The Deadmines"]      = { 38, 22, 1 },
    ["Shadowfang Keep"]    = { 60, 85, 1 },
    ["The Stockade"]       = { 85, 50, 1 },
    ["Blackfathom Deeps"]  = { 50, 10, 1 },
    ["Gnomeregan"]         = { 90, 40, 1 },
    ["Razorfen Kraul"]     = { 90, 28, 1 },
    ["Razorfen Downs"]     = { 60, 12, 1 },
    ["Uldaman"]            = { 57, 92, 1 },
    ["Zul'Farrak"]         = { 80, 88, 1 },
    ["Maraudon"]           = { 50, 95, 1 },
    ["Blackrock Depths"]   = { 50, 96, 1 },
    ["Scholomance"]        = { 80, 95, 1 },
    ["Stratholme"]         = { 87, 38, 1 },
    ["Molten Core"]        = { 47, 4, 1 },
    ["Zul'Gurub"]          = { 16, 72, 1 },
}
local START_BY_KEY = {}
for name, s in pairs(STARTS) do START_BY_KEY[Norm(name)] = s end

-- x%, y%, floor of the start of a dungeon, or nil. Your own recording wins.
local function StartPoint(cfg)
    if not cfg then return nil end
    local saved = DB().starts and DB().starts[cfg.key]
    if saved then return saved.x, saved.y, saved.floor or cfg.floors[1] end
    local s = START_BY_KEY[cfg.key]
    if s then return s[1], s[2], s[3] or cfg.floors[1] end
    return nil
end

local function SaveStart(cfg, x, y, floor)
    local db = DB()
    db.starts = db.starts or {}
    db.starts[cfg.key] = { x = x, y = y, floor = floor }
end

-- The pin
local startPin = CreateFrame("Frame", nil, pinLayer)
startPin:SetSize(16, 16)
startPin.dot = startPin:CreateTexture(nil, "ARTWORK")
startPin.dot:SetAllPoints()
startPin.dot:SetTexture("Interface\\COMMON\\Indicator-Green")
startPin.label = startPin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
startPin.label:SetPoint("BOTTOM", startPin, "TOP", 0, 0)
startPin.label:SetText("|cff40ff40Start|r")
startPin:Hide()

-- Draw the start pin when the shown floor is the start's floor.
local function DrawStartPin(cfg, floor)
    local x, y, f = StartPoint(cfg)
    if x and f == floor then
        Place(startPin, x / 100, y / 100)
        startPin:Show()
    else
        startPin:Hide()
    end
end

local function HideStartPin()
    startPin:Hide()
end

-- shared with the other BossNav files
ns.DrawStartPin = DrawStartPin
ns.HideStartPin = HideStartPin
ns.SaveStart = SaveStart
ns.StartPoint = StartPoint
