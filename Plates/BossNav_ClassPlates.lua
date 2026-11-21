-- Class colour on nameplates and on the party / raid blocks.
--
-- Nameplates and the raid-style party/raid frames are the same kind of game
-- frame, and the game repaints both through CompactUnitFrame_UpdateHealthColor,
-- so the class colour is put back right after every repaint.
local ADDON, ns = ...
-- from the files loaded before this one
local Forbidden              = ns.ClassForbidden
local IsSecret               = ns.IsSecret
local OnClassColorRefresh    = ns.OnClassColorRefresh
local PaintBar               = ns.ClassPaintBar
local Plain                  = ns.ClassPlain

-- the health bar inside a nameplate or raid frame
local function BarOf(uf)
    return uf and (uf.healthBar or uf.HealthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar))
end

local function PaintFrame(uf)
    if type(uf) ~= "table" or Forbidden(uf) then return end
    local unit = Plain(uf.displayedUnit) or Plain(uf.unit)
    PaintBar(BarOf(uf), unit)
end

-- after the game repaints a bar, put the class colour back
if type(CompactUnitFrame_UpdateHealthColor) == "function" then
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(uf)
        pcall(PaintFrame, uf)
    end)
end

-- NAME_PLATE_UNIT_ADDED: a plate came into view
local function ColorPlate(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or IsSecret(plate) or type(plate) ~= "table" or Forbidden(plate) then return end
    PaintFrame(plate.UnitFrame)
end

-- every nameplate and raid block now in view (used when the toggle flips)
local function RepaintAll()
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, list = pcall(C_NamePlate.GetNamePlates)
        if ok and not IsSecret(list) and type(list) == "table" then
            for _, plate in ipairs(list) do
                if not Forbidden(plate) then PaintFrame(plate.UnitFrame) end
            end
        end
    end
    for i = 1, 5 do PaintFrame(_G["CompactPartyFrameMember" .. i]) end
    for i = 1, 40 do PaintFrame(_G["CompactRaidFrame" .. i]) end
    for g = 1, 8 do
        for m = 1, 5 do PaintFrame(_G["CompactRaidGroup" .. g .. "Member" .. m]) end
    end
end
OnClassColorRefresh(RepaintAll)

-- shared with the other BossNav files
ns.ColorPlate = ColorPlate
