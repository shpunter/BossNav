-- Minimap boss icons.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local MapWorldSize           = ns.MapWorldSize
local RoundIcon              = ns.RoundIcon
local SetBossIcon            = ns.SetBossIcon
local state                  = ns.state

--------------------------------------------------------------------------
-- Minimap boss icons
--------------------------------------------------------------------------
-- Yards shown across the minimap at each zoom level (indoor / outdoor sets).
local MINIMAP_DIAMETER = {
    indoor  = { 300, 240, 180, 120, 80, 50 },
    outdoor = { 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 },
}
local mmCache = { zoom = nil, mode = "indoor" }
local minimapPins = {}

local function GetMinimapPin(i)
    if not minimapPins[i] then
        local p = CreateFrame("Frame", nil, Minimap)
        p:SetSize(12, 12)
        p:SetFrameLevel(Minimap:GetFrameLevel() + 5)
        p.icon = p:CreateTexture(nil, "OVERLAY")
        p.icon:SetAllPoints()
        RoundIcon(p.icon)
        p.ring = p:CreateTexture(nil, "ARTWORK")
        p.ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        p.ring:SetBlendMode("ADD")
        p.ring:SetVertexColor(1.0, 0.72, 0.10, 0.9)
        p.ring:SetPoint("CENTER")
        p.ring:SetSize(30, 30)
        p:Hide()
        minimapPins[i] = p
    end
    return minimapPins[i]
end

local function HideMinimapPinsFrom(i)
    for j = i, #minimapPins do minimapPins[j]:Hide() end
end

local function HideMinimapPins()
    HideMinimapPinsFrom(1)
end

-- Minimap zoom index is shared by indoor and outdoor modes; the cvars tell
-- which set is active (nudge trick used by HereBeDragons / TomTom).
local function MinimapDiameterYards()
    local zoom = Minimap:GetZoom()
    if zoom ~= mmCache.zoom then
        mmCache.zoom = zoom
        pcall(function()
            if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
                Minimap:SetZoom(zoom < 2 and zoom + 1 or zoom - 1)
            end
            mmCache.mode = (tonumber(GetCVar("minimapZoom")) == Minimap:GetZoom()) and "outdoor" or "indoor"
            Minimap:SetZoom(zoom)
        end)
    end
    local t = MINIMAP_DIAMETER[mmCache.mode]
    return t[zoom + 1] or t[1]
end

-- Anchor a pin on the minimap at an offset of dxY yards east and dyY yards
-- south of the player (screen up = north, or your facing when the minimap
-- rotates). Returns true when the spot is off the minimap and the pin was
-- pulled in to its edge.
local function PlaceMinimapPin(p, dxY, dyY, facing)
    local diameter = MinimapDiameterYards()
    local mw, mh = Minimap:GetWidth(), Minimap:GetHeight()
    local radius = math.min(mw, mh) * 0.5 - 5
    local sx, sy = dxY / diameter * mw, -dyY / diameter * mh
    if facing and GetCVar and GetCVar("rotateMinimap") == "1" then
        local c, s = math.cos(facing), math.sin(facing)
        sx, sy = sx * c + sy * s, -sx * s + sy * c
    end
    local dist = math.sqrt(sx * sx + sy * sy)
    local clamped = dist > radius
    if clamped and dist > 0 then
        sx, sy = sx / dist * radius, sy / dist * radius
    end
    p:ClearAllPoints()
    p:SetPoint("CENTER", Minimap, "CENTER", sx, sy)
    return clamped
end

local function UpdateMinimapPins(mapID, px, py, facing)
    local cfg = state.cfg
    if not (DB().minimap and cfg and state.inInstance and px and mapID) then
        HideMinimapPins()
        return
    end
    local ww, wh = MapWorldSize(mapID)
    if not ww then HideMinimapPins() return end

    local playerFloor = state.autoFloor
    local shown = 0

    for i, b in ipairs(cfg.bosses) do
        local onFloor = (not playerFloor) or ((b[4] or cfg.floors[1]) == playerFloor)
        if b[2] and onFloor and not state.killed[b[1]] then
            shown = shown + 1
            local p = GetMinimapPin(shown)
            local selected = (i == state.bossIdx)
            local clamped = PlaceMinimapPin(p, (b[2] / 100 - px) * ww, (b[3] / 100 - py) * wh, facing)
            p:SetSize(selected and 18 or 13, selected and 18 or 13)
            SetBossIcon(p.icon, b[1], false)
            p.icon:SetAlpha(clamped and 0.55 or 1)
            if selected then p.ring:Show() else p.ring:Hide() end
            p:Show()
        end
    end
    HideMinimapPinsFrom(shown + 1)
end

-- /bnav minimap
ns.AddCommand("minimap", function()
    DB().minimap = not DB().minimap
    ns.Print("Minimap boss icons " .. (DB().minimap and "on" or "off") .. ".")
    if not DB().minimap then HideMinimapPins() end
end, {
    "  /bnav minimap         toggle minimap icons (needs a position; this client hides it)",
})

-- shared with the other BossNav files
ns.GetMinimapPin = GetMinimapPin
ns.HideMinimapPins = HideMinimapPins
ns.HideMinimapPinsFrom = HideMinimapPinsFrom
ns.PlaceMinimapPin = PlaceMinimapPin
ns.UpdateMinimapPins = UpdateMinimapPins
ns.mmCache = mmCache
