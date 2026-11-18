-- Threat label under each enemy nameplate's health bar.
--
-- The threat window (BossNav_Threat.lua) scans the mobs and hands them here
-- every refresh. Each mob in combat gets a short coloured label centred under
-- its health bar, in the same colours as the window:
--   normal:  "72%"            your threat on it
--   tank:    "next 87%"       a mob you hold: how close the next one is
--            "LOOSE 12%"      a mob on someone else: your threat on it
-- "?" when the client hides the numbers. /bnav threat plates turns it off.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local IsSecret               = ns.IsSecret

-- threat status 0..3 -> colour (also used by the threat window)
local STATUS_COLOR = {
    [0] = { 0.7, 0.7, 0.7 },   -- grey   low on its list
    [1] = { 1.0, 1.0, 0.3 },   -- yellow above the tank, about to pull it
    [2] = { 1.0, 0.6, 0.0 },   -- orange on you, someone is close
    [3] = { 1.0, 0.2, 0.2 },   -- red    on you and stays
}
local LOOSE_COLOR = { 1.0, 0.3, 1.0 }   -- tank mode: a mob that is not on you

local labels = {}   -- nameplate frame -> label frame

local function PlateOf(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or IsSecret(plate) or type(plate) ~= "table" then return nil end
    -- plates the game keeps to itself cannot carry addon frames
    if plate.IsForbidden then
        local okF, forbidden = pcall(plate.IsForbidden, plate)
        if not okF or forbidden ~= false then return nil end
    end
    return plate
end

-- the plate's health bar, else the plate itself
local function Anchor(plate)
    local uf = plate.UnitFrame
    local bar = uf and (uf.healthBar or uf.HealthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar))
    return bar or plate
end

local function LabelFor(plate)
    local l = labels[plate]
    if l then return l end
    l = CreateFrame("Frame", nil, plate)
    l:SetSize(90, 14)
    -- under the health bar, centred, clear of the game's level badge on the right
    l:SetPoint("TOP", Anchor(plate), "BOTTOM", 0, -2)
    l:SetFrameLevel((plate:GetFrameLevel() or 0) + 10)
    l.text = l:CreateFontString(nil, "OVERLAY")
    l.text:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    l.text:SetPoint("TOP", l, "TOP", 0, 0)
    l.text:SetJustifyH("CENTER")
    labels[plate] = l
    return l
end

local function Pct(v)
    return string.format("%d%%", math.floor(v + 0.5))
end

-- text and colour for one mob
local function LabelText(t, tank)
    local status = t.myStatus
    if tank then
        if (status or 0) >= 2 then
            return "next " .. (t.nextPct and Pct(t.nextPct) or "-"), STATUS_COLOR[status]
        end
        if status or t.holder or t.onList then
            return "LOOSE " .. (t.myPct and Pct(t.myPct) or "0%"), LOOSE_COLOR
        end
    else
        if t.myPct then return Pct(t.myPct), STATUS_COLOR[status] end
        if status then return "-", STATUS_COLOR[status] end
    end
    if t.unknown then return "?", STATUS_COLOR[0] end
    return nil
end

local function HideAll()
    for _, l in pairs(labels) do l:Hide() end
end

-- mobs: the threat window's list; tank: tank mode on
local function UpdateThreatPlates(mobs, tank)
    HideAll()
    if DB().threatPlates == false then return end
    for _, t in ipairs(mobs or {}) do
        local plate = PlateOf(t.unit)
        if plate then
            local text, c = LabelText(t, tank)
            if text then
                local l = LabelFor(plate)
                c = c or STATUS_COLOR[0]
                l.text:SetText(text)
                l.text:SetTextColor(c[1], c[2], c[3])
                l:Show()
            end
        end
    end
end

-- /bnav threat plates
local function ToggleThreatPlates()
    DB().threatPlates = (DB().threatPlates == false)
    if not DB().threatPlates then HideAll() end
    return DB().threatPlates
end

-- shared with the other BossNav files
ns.HideThreatPlates = HideAll
ns.THREAT_LOOSE_COLOR = LOOSE_COLOR
ns.THREAT_STATUS_COLOR = STATUS_COLOR
ns.ToggleThreatPlates = ToggleThreatPlates
ns.UpdateThreatPlates = UpdateThreatPlates
