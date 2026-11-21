-- Map art renderers.
local ADDON, ns = ...
-- from the files loaded before this one
local CANVAS_H               = ns.CANVAS_H
local CANVAS_W               = ns.CANVAS_W
local FitRect                = ns.FitRect
local GetTile                = ns.GetTile
local HideTilesFrom          = ns.HideTilesFrom
local LEGACY_ASPECT          = ns.LEGACY_ASPECT
local SetDrawRect            = ns.SetDrawRect
local canvas                 = ns.canvas

--------------------------------------------------------------------------
-- Map art renderers
--------------------------------------------------------------------------
local function RenderNative(mapID)
    if not (mapID and C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then return false end
    local ok, layers = pcall(C_Map.GetMapArtLayers, mapID)
    if not ok or type(layers) ~= "table" or not layers[1] then return false end
    local layer = layers[1]
    local ok2, textures = pcall(C_Map.GetMapArtLayerTextures, mapID, 1)
    if not ok2 or type(textures) ~= "table" or #textures == 0 then return false end

    local layerW, layerH = layer.layerWidth or 0, layer.layerHeight or 0
    local tileW, tileH = layer.tileWidth or 256, layer.tileHeight or 256
    if layerW <= 0 or layerH <= 0 or tileW <= 0 or tileH <= 0 then return false end

    local cols = math.ceil(layerW / tileW)
    local scale = math.min(CANVAS_W / layerW, CANVAS_H / layerH)
    local w, h = layerW * scale, layerH * scale
    SetDrawRect((CANVAS_W - w) * 0.5, (CANVAS_H - h) * 0.5, w, h)

    for i, fileID in ipairs(textures) do
        local tile = GetTile(i)
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local px, py = col * tileW, row * tileH
        local vw, vh = math.min(tileW, layerW - px), math.min(tileH, layerH - py)
        if vw > 0 and vh > 0 then
            tile:ClearAllPoints()
            tile:SetSize(vw * scale, vh * scale)
            tile:SetPoint("TOPLEFT", canvas, "TOPLEFT", ns.drawX + px * scale, -(ns.drawY + py * scale))
            tile:SetTexCoord(0, vw / tileW, 0, vh / tileH)
            tile:SetTexture(fileID)
            tile:Show()
        else
            tile:Hide()
        end
    end
    HideTilesFrom(#textures + 1)
    ns.renderedMapID = mapID
    return true
end

local function RenderLegacy(cfg, floor)
    if not cfg.folder then return false end
    local x0, y0, w, h = FitRect(LEGACY_ASPECT)
    SetDrawRect(x0, y0, w, h)
    local tw, th = w / 4, h / 3
    for i = 1, 12 do
        local tile = GetTile(i)
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local file = cfg.special and (cfg.folder .. i) or (cfg.folder .. tostring(floor) .. "_" .. i)
        tile:ClearAllPoints()
        tile:SetSize(tw, th)
        tile:SetPoint("TOPLEFT", canvas, "TOPLEFT", x0 + col * tw, -(y0 + row * th))
        tile:SetTexCoord(0, 1, 0, 1)
        local okTex = tile:SetTexture("Interface\\Worldmap\\" .. cfg.folder .. "\\" .. file)
        if i == 1 and okTex == false then return false end
        tile:Show()
    end
    HideTilesFrom(13)
    ns.renderedMapID = nil
    return true
end

local function RenderBundled(cfg)
    if not cfg.bundled then return false end
    local x0, y0, w, h = FitRect(cfg.bundledAspect or 1)
    SetDrawRect(x0, y0, w, h)
    local tile = GetTile(1)
    tile:ClearAllPoints()
    tile:SetSize(w, h)
    tile:SetPoint("TOPLEFT", canvas, "TOPLEFT", x0, -y0)
    tile:SetTexCoord(0, 1, 0, 1)
    tile:SetTexture(cfg.bundled)
    tile:Show()
    HideTilesFrom(2)
    ns.renderedMapID = nil
    return true
end

local function RenderBlank()
    HideTilesFrom(1)
    SetDrawRect(0, 0, CANVAS_W, CANVAS_H)
    ns.renderedMapID = nil
end

-- shared with the other BossNav files
ns.RenderBlank = RenderBlank
ns.RenderBundled = RenderBundled
ns.RenderLegacy = RenderLegacy
ns.RenderNative = RenderNative
