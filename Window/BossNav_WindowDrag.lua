-- Drag the main window (BossNavMapFrame) with the left mouse button.
-- Grab it by any spot that is not a button or list row, such as the header
-- at the top. The spot is saved and restored after a reload.
--
-- The position is kept as the window's top-left corner, the same anchor
-- SetWide (BossNav_Window.lua) uses when the window grows or shrinks.
local ADDON, ns = ...
-- from the files loaded before this one
local DB       = ns.DB
local mapFrame = ns.mapFrame

local function SavePosition()
    local left, top = mapFrame:GetLeft(), mapFrame:GetTop()
    if not (left and top) then return end
    DB().windowPos = { left, top }
end

local function RestorePosition()
    local p = DB().windowPos
    if type(p) ~= "table" or not (p[1] and p[2]) then return end
    mapFrame:ClearAllPoints()
    mapFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[1], p[2])
end

mapFrame:SetMovable(true)
mapFrame:EnableMouse(true)
mapFrame:RegisterForDrag("LeftButton")
mapFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
mapFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- BossNav saves the spot itself; keep the game's own layout cache out of it
    if self.SetUserPlaced then self:SetUserPlaced(false) end
    SavePosition()
end)

-- saved settings exist only once the addon has finished loading
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    pcall(RestorePosition)
    self:UnregisterEvent("ADDON_LOADED")
end)
