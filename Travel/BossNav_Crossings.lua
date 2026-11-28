-- Learns zone exits as you walk: when you step from one zone into the next,
-- the last spot in the old zone and the first in the new one are saved as
-- that border's crossing (DB().crossings). The router (BossNav_Routes.lua)
-- then uses these exact spots instead of its built-in guesses.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local IsRouteZone            = ns.IsRouteZone
local Norm                   = ns.Norm
local ResolveMapIDByName     = ns.ResolveMapIDByName

local SAMPLE_EVERY = 0.5   -- seconds between position samples
local MAX_GAP_TIME = 3     -- seconds: older last spot = you did not walk over
local MAX_GAP_YARDS = 80   -- farther apart = a teleport, hearth or loading screen
local SAME_SPOT_YARDS = 300 -- a new crossing this close to a saved one replaces it
local MAX_PER_BORDER = 3   -- different bridges / roads kept for one pair of zones

-- Where you stand now: zone key and name, x, y (percent of the zone's own
-- map), world position and continent. nil when the game will not say.
local function Sample()
    if IsInInstance() then return nil end
    if UnitOnTaxi and UnitOnTaxi("player") then return nil end
    local name = GetRealZoneText()
    local key = Norm(name)
    if not IsRouteZone(key) then return nil end
    local mapID = ResolveMapIDByName(name)
    if not (mapID and C_Map and C_Map.GetPlayerMapPosition) then return nil end
    local s
    pcall(function()
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        local x, y = pos:GetXY()
        if type(x) ~= "number" or type(y) ~= "number" or (x == 0 and y == 0) then return end
        local cont, world = C_Map.GetWorldPosFromMapPos(mapID, pos)
        local wx, wy = world:GetXY()
        if type(cont) ~= "number" or type(wx) ~= "number" then return end
        s = { key = key, name = name, x = x * 100, y = y * 100, cont = cont, wx = wx, wy = wy, t = GetTime() }
    end)
    return s
end

local function Round(v) return math.floor(v * 10 + 0.5) / 10 end

-- Save one direction of a crossing: from zone a (spot ax, ay) into zone b.
local function Save(a, b)
    local all = DB()
    all.crossings = all.crossings or {}
    all.crossings[a.key] = all.crossings[a.key] or {}
    local spots = all.crossings[a.key][b.key] or {}
    all.crossings[a.key][b.key] = spots
    local new = { zone = b.name, x = Round(a.x), y = Round(a.y), tx = Round(b.x), ty = Round(b.y) }
    for i, c in ipairs(spots) do
        local dx, dy = c.x - new.x, c.y - new.y
        -- percent to yards, roughly: classic zones are a few thousand yards wide
        if math.sqrt(dx * dx + dy * dy) * 30 < SAME_SPOT_YARDS then
            spots[i] = new
            return
        end
    end
    table.insert(spots, 1, new)
    while #spots > MAX_PER_BORDER do table.remove(spots) end
end

local last
local function Tick()
    local now = Sample()
    if not now then last = nil return end
    if last and last.key ~= now.key and last.cont == now.cont
        and now.t - last.t <= MAX_GAP_TIME then
        local dx, dy = now.wx - last.wx, now.wy - last.wy
        if math.sqrt(dx * dx + dy * dy) <= MAX_GAP_YARDS then
            Save(last, now)
            Save(now, last)
            if ns.Print then
                ns.Print(string.format("Learned the exit %s (%.1f, %.1f) -> %s (%.1f, %.1f)",
                    last.name, last.x, last.y, now.name, now.x, now.y))
            end
        end
    end
    last = now
end

if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(SAMPLE_EVERY, function() pcall(Tick) end)
end
