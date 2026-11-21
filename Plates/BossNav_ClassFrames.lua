-- Class colour on the target, target-of-target and party portrait frames.
--
-- The game names these bars differently from version to version, so each is
-- looked up by every known name. A bar is repainted whenever its value
-- changes (the game may recolour it then) and when the target or group
-- changes.
local ADDON, ns = ...
-- from the files loaded before this one
local Forbidden              = ns.ClassForbidden
local OnClassColorRefresh    = ns.OnClassColorRefresh
local PaintBar               = ns.ClassPaintBar
local Plain                  = ns.ClassPlain

-- t[k1][k2]... or nil
local function Path(t, ...)
    for i = 1, select("#", ...) do
        if type(t) ~= "table" then return nil end
        t = t[select(i, ...)]
    end
    return t
end

-- first candidate that is a status bar
local function First(...)
    for i = 1, select("#", ...) do
        local b = select(i, ...)
        if type(b) == "table" and b.SetStatusBarColor then return b end
    end
    return nil
end

local function TargetBar()
    local tf = _G.TargetFrame
    return First(Path(tf, "healthbar"), _G.TargetFrameHealthBar,
        Path(tf, "TargetFrameContent", "TargetFrameContentMain", "HealthBarsContainer", "HealthBar"),
        Path(tf, "TargetFrameContent", "TargetFrameContentMain", "HealthBar"))
end

local function ToTBar()
    local tot = _G.TargetFrameToT or Path(_G.TargetFrame, "totFrame")
    return First(Path(tot, "healthbar"), _G.TargetFrameToTHealthBar, Path(tot, "HealthBar"),
        Path(tot, "HealthBarsContainer", "HealthBar"))
end

local function PartyBar(i)
    local old = _G["PartyMemberFrame" .. i]
    local new = Path(_G.PartyFrame, "MemberFrame" .. i)
    return First(Path(old, "healthbar"), _G["PartyMemberFrame" .. i .. "HealthBar"],
        Path(new, "healthbar"), Path(new, "HealthBarContainer", "HealthBar"), Path(new, "HealthBar"))
end

-- { find = function returning the bar, unit = the unit it shows }
local FRAMES = {
    { find = TargetBar, unit = "target" },
    { find = ToTBar,    unit = "targettarget" },
}
for i = 1, 4 do
    FRAMES[#FRAMES + 1] = { find = function() return PartyBar(i) end, unit = "party" .. i }
end

local unitOf = {}   -- bar -> unit it shows

local function UnitOf(bar)
    local u = Plain(bar.unit)
    if type(u) == "string" and u ~= "" then return u end
    return unitOf[bar]
end

local function Repaint(bar)
    pcall(PaintBar, bar, UnitOf(bar))
end

-- find the bars (they may appear late) and hook each one once
local function RepaintAll()
    for _, f in ipairs(FRAMES) do
        local ok, bar = pcall(f.find)
        if ok and bar and not Forbidden(bar) then
            if not unitOf[bar] then
                unitOf[bar] = f.unit
                pcall(bar.HookScript, bar, "OnValueChanged", Repaint)
            end
            Repaint(bar)
        end
    end
end
OnClassColorRefresh(RepaintAll)

-- the game's own repaint functions, where this version has them
local function HookRepaint(name)
    if type(_G[name]) ~= "function" then return end
    hooksecurefunc(name, function(bar)
        if type(bar) == "table" and unitOf[bar] then Repaint(bar) end
    end)
end
HookRepaint("UnitFrameHealthBar_Update")
HookRepaint("HealthBar_OnValueChanged")

-- target, target of target or group changed: repaint once the game has
-- finished drawing the new unit
local function ColorUnitFrames()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, RepaintAll)
    else
        RepaintAll()
    end
end

-- shared with the other BossNav files
ns.ColorUnitFrames = ColorUnitFrames
