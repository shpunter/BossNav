-- Top-of-screen direction HUD.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local RoundIcon              = ns.RoundIcon
local state                  = ns.state

--------------------------------------------------------------------------
-- HUD (direction arrow toward the selected boss)
--------------------------------------------------------------------------
local hud = CreateFrame("Frame", "BossNavHUD", UIParent)
hud:SetSize(340, 46)
hud:SetPoint("TOP", UIParent, "TOP", 0, -30)
hud:SetFrameStrata("MEDIUM")
hud:Hide()
local hudBg = hud:CreateTexture(nil, "BACKGROUND")
hudBg:SetAllPoints()
hudBg:SetColorTexture(0, 0, 0, 0.6)
hud.arrow = hud:CreateTexture(nil, "ARTWORK")
hud.arrow:SetSize(30, 30)
hud.arrow:SetPoint("LEFT", hud, "LEFT", 10, 0)
hud.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
hud.icon = hud:CreateTexture(nil, "ARTWORK")
hud.icon:SetSize(34, 34)
hud.icon:SetPoint("LEFT", hud, "LEFT", 46, 0)
RoundIcon(hud.icon)
hud.main = hud:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hud.main:SetPoint("TOPLEFT", hud, "TOPLEFT", 86, -7)
hud.main:SetWidth(247)
hud.main:SetJustifyH("LEFT")
hud.main:SetWordWrap(false)
hud.sub = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hud.sub:SetPoint("TOPLEFT", hud.main, "BOTTOMLEFT", 0, -2)
hud.sub:SetWidth(285)
hud.sub:SetJustifyH("LEFT")
hud.sub:SetWordWrap(false)

local function UpdateHUDVisibility()
    local inDungeon = state.cfg and (state.inInstance or state.testMode)
    local travelling = ns.TravelActive and ns.TravelActive()
    if DB().hud and (inDungeon or travelling) then
        hud:Show()
    else
        hud:Hide()
    end
end

-- Rough location of a pin in words, for when the client hides your position.
local function AreaWord(x, y)
    local ns = (y < 35 and "north") or (y > 65 and "south") or ""
    local ew = (x < 35 and "west") or (x > 65 and "east") or ""
    if ns == "" and ew == "" then return "the middle of the map" end
    if ns ~= "" and ew ~= "" then return "the " .. ns .. "-" .. ew .. " part of the map" end
    return "the " .. ns .. ew .. " part of the map"
end

local function DirectionWord(rel)
    local deg = math.deg(rel)
    while deg > 180 do deg = deg - 360 end
    while deg < -180 do deg = deg + 360 end
    local a = math.abs(deg)
    local side = deg > 0 and "left" or "right"
    if a < 20 then return "straight ahead"
    elseif a < 70 then return "ahead-" .. side
    elseif a < 110 then return side
    elseif a < 160 then return "behind-" .. side
    else return "behind you" end
end

-- shared with the other BossNav files
ns.AreaWord = AreaWord
ns.DirectionWord = DirectionWord
ns.UpdateHUDVisibility = UpdateHUDVisibility
ns.hud = hud
