-- Paints a health bar in the class colour of the player it shows.
--
-- Shared by BossNav_ClassPlates.lua (nameplates, raid frames) and
-- BossNav_ClassFrames.lua (target, target of target, party). A bar that
-- shows a mob, or whose class the client hides, gets the game's own colour
-- back. /bnav classplates turns all of it off and on.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local IsSecret               = ns.IsSecret

local painted    = {}   -- bar -> { r, g, b, desaturated } the game had before painting
local refreshers = {}   -- functions that repaint every bar they look after

local function Enabled()
    return DB().classPlates ~= false
end

local function Plain(v)
    if IsSecret(v) then return nil end
    return v
end

-- frames the game keeps to itself cannot be touched
local function Forbidden(f)
    if not (f and f.IsForbidden) then return false end
    local ok, forbidden = pcall(f.IsForbidden, f)
    return not ok or forbidden ~= false
end

-- r, g, b of a player unit's class; nil for mobs or when the client hides it
local function ClassColor(unit)
    local okE, exists = pcall(UnitExists, unit)
    if not okE or Plain(exists) ~= true then return nil end
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    if not okP or Plain(isPlayer) ~= true then return nil end
    local okC, _, classFile = pcall(UnitClass, unit)
    classFile = okC and Plain(classFile)
    if type(classFile) ~= "string" then return nil end
    local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
    if not c then return nil end
    return c.r, c.g, c.b
end

-- the bar's fill texture; desaturated so a green bar art takes the colour cleanly
local function Fill(bar)
    local ok, t = pcall(bar.GetStatusBarTexture, bar)
    if ok and type(t) == "table" and t.SetDesaturated then return t end
    return nil
end

-- put the game's own colour back on a bar painted earlier
local function Unpaint(bar)
    local o = painted[bar]
    if not o then return end
    painted[bar] = nil
    local r, g, b = o[1], o[2], o[3]
    -- nameplates and raid frames remember the colour the game picked last
    local cr, cg, cb = Plain(bar.r), Plain(bar.g), Plain(bar.b)
    if type(cr) == "number" and type(cg) == "number" and type(cb) == "number" then
        r, g, b = cr, cg, cb
    end
    pcall(bar.SetStatusBarColor, bar, r, g, b)
    local t = Fill(bar)
    if t then pcall(t.SetDesaturated, t, o[4] and true or false) end
end

-- bar: a health StatusBar; unit: the unit it shows ("target", "party2", "nameplate5"...)
local function PaintBar(bar, unit)
    if type(bar) ~= "table" or not bar.SetStatusBarColor or Forbidden(bar) then return end
    local r, g, b
    if Enabled() and type(unit) == "string" then r, g, b = ClassColor(unit) end
    if not r then Unpaint(bar) return end
    local t = Fill(bar)
    if not painted[bar] then
        local ok, or_, og, ob = pcall(bar.GetStatusBarColor, bar)
        local desat = false
        if t and t.IsDesaturated then
            local okD, d = pcall(t.IsDesaturated, t)
            desat = okD and Plain(d) == true
        end
        painted[bar] = {
            ok and type(Plain(or_)) == "number" and or_ or 0,
            ok and type(Plain(og)) == "number" and og or 1,
            ok and type(Plain(ob)) == "number" and ob or 0,
            desat,
        }
    end
    pcall(bar.SetStatusBarColor, bar, r, g, b)
    if t then pcall(t.SetDesaturated, t, true) end
end

-- each painter file hands in a function that repaints all of its bars
local function OnClassColorRefresh(fn)
    refreshers[#refreshers + 1] = fn
end

-- /bnav classplates
local function ToggleClassColors()
    DB().classPlates = not Enabled()
    for _, fn in ipairs(refreshers) do pcall(fn) end
    return DB().classPlates
end

-- shared with the other BossNav files
ns.ClassForbidden = Forbidden
ns.ClassPaintBar = PaintBar
ns.ClassPlain = Plain
ns.OnClassColorRefresh = OnClassColorRefresh
ns.ToggleClassColors = ToggleClassColors
