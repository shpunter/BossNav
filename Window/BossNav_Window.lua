-- Map window frames, sidebar rows, pins.
local ADDON, ns = ...
-- from the files loaded before this one
local BOSS_DISPLAY           = ns.BOSS_DISPLAY
local CANVAS_H               = ns.CANVAS_H
local CANVAS_W               = ns.CANVAS_W
local SIDEBAR_W              = ns.SIDEBAR_W
local SKULL_TEX              = ns.SKULL_TEX

-- Draw rectangle of the map art inside the canvas (set by the renderers)
ns.drawX, ns.drawY = 0, 0
local drawW, drawH = CANVAS_W, CANVAS_H
ns.renderedMapID = nil   -- uiMapID when native art is shown, else nil

--------------------------------------------------------------------------
-- Map window
--------------------------------------------------------------------------
local mapFrame = CreateFrame("Frame", "BossNavMapFrame", UIParent)
-- FILTER_H: room under the map for the item filters (BossNav_FilterPanel.lua)
-- and for a tall item card with its comparison (BossNav_ItemsPanel.lua)
local FILTER_H = 140
mapFrame:SetSize(12 + CANVAS_W + 10 + SIDEBAR_W + 12, CANVAS_H + 246 + FILTER_H)
mapFrame:SetPoint("CENTER")
mapFrame:SetFrameStrata("HIGH")
mapFrame:SetClampedToScreen(true)
mapFrame:Hide()
tinsert(UISpecialFrames, "BossNavMapFrame")   -- Esc closes the window

local border = mapFrame:CreateTexture(nil, "BACKGROUND")
border:SetPoint("TOPLEFT", -1, 1)
border:SetPoint("BOTTOMRIGHT", 1, -1)
border:SetColorTexture(0.45, 0.40, 0.25, 0.9)
local bg = mapFrame:CreateTexture(nil, "BORDER")
bg:SetAllPoints()
bg:SetColorTexture(0.03, 0.03, 0.04, 0.96)

local headerText = mapFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
headerText:SetPoint("TOPLEFT", mapFrame, "TOPLEFT", 12, -10)
headerText:SetJustifyH("LEFT")

local statusText = mapFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
statusText:SetPoint("TOPLEFT", headerText, "BOTTOMLEFT", 0, -3)
statusText:SetJustifyH("LEFT")

local canvas = CreateFrame("Frame", "BossNavCanvas", mapFrame)
canvas:SetSize(CANVAS_W, CANVAS_H)
canvas:SetPoint("TOPLEFT", mapFrame, "TOPLEFT", 12, -50)

local canvasBg = canvas:CreateTexture(nil, "BACKGROUND")
canvasBg:SetAllPoints()
canvasBg:SetColorTexture(0, 0, 0, 1)

local noArtText = canvas:CreateFontString(nil, "OVERLAY", "GameFontDisable")
noArtText:SetPoint("CENTER")
noArtText:SetWidth(CANVAS_W - 40)
noArtText:SetJustifyH("CENTER")
noArtText:Hide()

local navText = mapFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
navText:SetPoint("TOPLEFT", canvas, "BOTTOMLEFT", 0, -8)
navText:SetJustifyH("LEFT")
navText:SetWidth(CANVAS_W)   -- keep the footer text off the sidebar

local helpText = mapFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
helpText:SetPoint("TOPLEFT", navText, "BOTTOMLEFT", 0, -4)
helpText:SetJustifyH("LEFT")
helpText:SetWidth(CANVAS_W)
local HELP_BOSS = "/bnav boss | /bnav prev | /bnav floor | /bnav kill | /bnav mark X Y note | /bnav hud | /bnav help"
helpText:SetText(HELP_BOSS)

-- Sidebar boss list
local sidebar = CreateFrame("Frame", nil, mapFrame)
sidebar:SetSize(SIDEBAR_W, CANVAS_H + 184 + FILTER_H)   -- runs down to the window bottom so 20 tall rows fit under the tab rows
sidebar:SetPoint("TOPLEFT", canvas, "TOPRIGHT", 10, 0)
local sidebarBg = sidebar:CreateTexture(nil, "BACKGROUND")
sidebarBg:SetAllPoints()
sidebarBg:SetColorTexture(0.06, 0.06, 0.08, 1)
-- The Dungeons section shows three columns side by side: the dungeon list
-- (the sidebar itself), then the picked dungeon's bosses, then their loot.
-- The two extra columns, and the wider window they need, show only there.
--
--   +-- canvas --------+ +- sidebar -+ +- bossCol -+ +- itemCol -+
--   | map or item card | | Dungeons  | | Bosses    | | Items     |
local BOSS_COL_W, ITEM_COL_W, COL_GAP = 210, 270, 4
local NARROW_W = 12 + CANVAS_W + 10 + SIDEBAR_W + 12
local WIDE_W = NARROW_W + COL_GAP + BOSS_COL_W + COL_GAP + ITEM_COL_W

local function NewColumn(width, leftOf)
    local col = CreateFrame("Frame", nil, mapFrame)
    col:SetSize(width, CANVAS_H + 184 + FILTER_H)
    col:SetPoint("TOPLEFT", leftOf, "TOPRIGHT", COL_GAP, 0)
    local colBg = col:CreateTexture(nil, "BACKGROUND")
    colBg:SetAllPoints()
    colBg:SetColorTexture(0.06, 0.06, 0.08, 1)
    col:Hide()
    return col
end
local bossCol = NewColumn(BOSS_COL_W, sidebar)
local itemCol = NewColumn(ITEM_COL_W, bossCol)

-- Wide window with all three columns (Dungeons section) or the narrow one.
-- The left edge stays where it is, so the map does not jump.
local function SetWide(on)
    local w = on and WIDE_W or NARROW_W
    bossCol:SetShown(on)
    itemCol:SetShown(on)
    if math.abs(mapFrame:GetWidth() - w) < 1 then return end
    local left, top = mapFrame:GetLeft(), mapFrame:GetTop()
    mapFrame:SetWidth(w)
    if left and top then
        mapFrame:ClearAllPoints()
        mapFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
end

-- The tab rows at the top of the sidebar live in BossNav_Tabs.lua. Every
-- list hangs from its column's anchor, which the tabs move up or down
-- (SetListTop) since the sections have different rows above their lists.
local function NewListAnchor(col)
    local a = CreateFrame("Frame", nil, col)
    a:SetHeight(1)
    return a
end
local listAnchor = NewListAnchor(sidebar)
local bossAnchor = NewListAnchor(bossCol)
local itemAnchor = NewListAnchor(itemCol)
local function SetListTop(y)
    for col, a in pairs({ [sidebar] = listAnchor, [bossCol] = bossAnchor, [itemCol] = itemAnchor }) do
        a:ClearAllPoints()
        a:SetPoint("TOPLEFT", col, "TOPLEFT", 0, y)
        a:SetPoint("TOPRIGHT", col, "TOPRIGHT", 0, y)
    end
end
SetListTop(-28)

-- Clip a square portrait texture to a circle (modern clients only; older
-- ones have no mask textures and simply keep the square portrait).
local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local function RoundIcon(tex)
    if not (tex and tex.AddMaskTexture) then return end
    local parent = tex:GetParent()
    if not parent or not parent.CreateMaskTexture then return end
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
end

local bossRows = {}
local MAX_ROWS = 20
local ROW_H = 24
-- Row padding, as in CSS: the icon sits PAD_X from the row's left edge and
-- PAD_Y from its top and bottom (so it is ROW_H - 2 * PAD_Y tall).
local PAD_X, PAD_Y = 6, 4
local ICON_SIZE = ROW_H - 2 * PAD_Y
local NAME_FONT_SIZE = 14
local MARK_W = PAD_X   -- the old ">" marker column, now just the left padding

-- The selected row of a list, styled like the active item of a web page menu:
-- a soft gold box with rounded corners and a thin gold outline. The rounding
-- comes from the game's tooltip border art. Works on any list row (the box is
-- made on first use) and clears the old ">" marker.
local ACTIVE_BACKDROP = {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
}
-- A gold box with rounded corners behind a row; fillA / edgeA: how strong
-- the fill and the outline are.
local function NewRoundBox(r, fillA, edgeA)
    local box = CreateFrame("Frame", nil, r, BackdropTemplateMixin and "BackdropTemplate" or nil)
    box:SetAllPoints()
    -- under the row's icon and text (a child frame is drawn above them otherwise)
    box:SetFrameLevel(math.max(0, r:GetFrameLevel() - 1))
    -- The gold fill, kept inside the rounded corners. It is drawn by the row
    -- itself (bottom layer, under the icon and text), not by the box: the box
    -- sits one level down, level with the column's dark background, and the
    -- game may draw that background over anything of the box but its outline.
    local fill = r:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", r, "TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -3, 3)
    fill:SetColorTexture(1, 0.82, 0, fillA)
    fill:Hide()
    box.fill = fill
    if box.SetBackdrop then
        box:SetBackdrop(ACTIVE_BACKDROP)
        box:SetBackdropBorderColor(1, 0.82, 0, edgeA)
    end
    box:Hide()
    return box
end

-- outline and fill together
local function ShowRoundBox(box, on)
    if on then box:Show() box.fill:Show() else box:Hide() box.fill:Hide() end
end

-- Mouse-over look of a list row: the same rounded box, fainter than the
-- selected one. Replaces the square highlight a row used to have.
local function AddRoundHover(r)
    r.hoverBg = NewRoundBox(r, 0.10, 0.35)
    r:HookScript("OnEnter", function(self) ShowRoundBox(self.hoverBg, true) end)
    r:HookScript("OnLeave", function(self) ShowRoundBox(self.hoverBg, false) end)
    r:HookScript("OnHide", function(self) ShowRoundBox(self.hoverBg, false) end)
end

local function SetRowActive(r, on)
    if on and not r.activeBg then r.activeBg = NewRoundBox(r, 0.32, 0.95) end
    if r.activeBg then ShowRoundBox(r.activeBg, on and true or false) end
    if r.mark and r.mark.SetText then r.mark:SetText("") end
end

-- Bump a font string to a given point size, keeping its face and outline.
local function SetFontSize(fs, size)
    local face, _, flags = fs:GetFont()
    if face then fs:SetFont(face, size, flags) end
end
-- One list row: ">" | round icon | name, plus a map button at the right end
-- (dungeon rows only). Clicking picks the row's dungeon or boss.
local function NewRow(col, anchor, colW, i)
    local b = CreateFrame("Button", nil, col)
    b:SetSize(colW - 8, ROW_H)
    b:SetPoint("TOPLEFT", anchor, "TOPLEFT", 4, -(i - 1) * ROW_H)
    AddRoundHover(b)
    -- layout: ">" | portrait | name
    b.mark = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    -- pushed right so the ">" sits just in front of what it points at
    b.mark:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.mark:SetWidth(MARK_W)
    b.mark:SetJustifyH("RIGHT")
    b.mark:SetWordWrap(false)
    SetFontSize(b.mark, NAME_FONT_SIZE)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(ICON_SIZE, ICON_SIZE)
    b.icon:SetPoint("LEFT", b, "LEFT", PAD_X, 0)
    RoundIcon(b.icon)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("LEFT", b, "LEFT", PAD_X + ICON_SIZE + 6, 0)
    local textW = colW - 8 - (PAD_X + ICON_SIZE + 6) - PAD_X
    b.text:SetWidth(textW)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    SetFontSize(b.text, NAME_FONT_SIZE)
    -- "Show on the map" button at the right end of a dungeon row (like
    -- the Quests tab rows); boss rows have none
    local m = CreateFrame("Button", nil, b)
    m:SetSize(18, 18)
    m:SetPoint("RIGHT", b, "RIGHT", -2, 0)
    m:SetFrameLevel(b:GetFrameLevel() + 2)
    m:SetNormalTexture("Interface\\Icons\\INV_Misc_Map_01")
    m:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    m:SetScript("OnClick", function()
        if b.travelIdx and ns.ShowDungeonOnWorldMap then
            ns.ShowDungeonOnWorldMap(b.travelIdx)
        end
    end)
    m:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Show on the map", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    m:Hide()
    b.mapBtn = m
    -- show or hide the map button, leaving the name room for it
    function b:SetMapButton(on)
        if on then
            self.mapBtn:Show()
            self.text:SetWidth(textW - 22)
        else
            self.mapBtn:Hide()
            self.text:SetWidth(textW)
        end
    end
    -- picks the dungeon (focus unchanged) or the boss (Bosses column focused)
    b:SetScript("OnClick", function(self)
        if self.travelIdx then
            -- only a filter for the Bosses and Items columns: the map area
            -- stays as it is (the map button on the row shows the map)
            BossNav_SelectDungeon(self.travelIdx)
        elseif self.bossIdx then
            BossNav_SelectBoss(self.bossIdx)
            if ns.SetTab then ns.SetTab("boss") end
        elseif self.trashCfg and ns.PickTrash then
            ns.PickTrash(self.trashCfg)
            if ns.SetTab then ns.SetTab("boss") end
        end
    end)
    return b
end

-- Rows of the dungeon list (the sidebar) and of the boss column.
local bossColRows = {}
local function GetRow(i)
    bossRows[i] = bossRows[i] or NewRow(sidebar, listAnchor, SIDEBAR_W, i)
    return bossRows[i]
end
local function GetBossRow(i)
    bossColRows[i] = bossColRows[i] or NewRow(bossCol, bossAnchor, BOSS_COL_W, i)
    return bossColRows[i]
end

-- Map tiles
local tiles = {}
local function GetTile(i)
    if not tiles[i] then
        tiles[i] = canvas:CreateTexture(nil, "ARTWORK")
    end
    return tiles[i]
end
local function HideTilesFrom(i)
    for j = i, #tiles do tiles[j]:Hide() end
end

-- Pin layer (above tiles)
local pinLayer = CreateFrame("Frame", nil, canvas)
pinLayer:SetAllPoints()
pinLayer:SetFrameLevel(canvas:GetFrameLevel() + 2)

local bossPins = {}
local function GetBossPin(i)
    if not bossPins[i] then
        local p = CreateFrame("Button", nil, pinLayer)
        p:SetSize(18, 18)
        p:SetScript("OnClick", function(self)
            if self.bossIdx then BossNav_SelectBoss(self.bossIdx) end
        end)
        p.icon = p:CreateTexture(nil, "ARTWORK")
        p.icon:SetAllPoints()
        RoundIcon(p.icon)
        p.ring = p:CreateTexture(nil, "BORDER")
        p.ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        p.ring:SetBlendMode("ADD")
        p.ring:SetVertexColor(1.0, 0.72, 0.10, 0.95)
        p.ring:SetPoint("CENTER")
        p.ring:SetSize(44, 44)
        p.label = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        p.label:SetPoint("TOP", p, "BOTTOM", 0, 1)
        bossPins[i] = p
    end
    return bossPins[i]
end

local wayPins = {}
local function GetWayPin(i)
    if not wayPins[i] then
        local p = CreateFrame("Frame", nil, pinLayer)
        p:SetSize(14, 14)
        p.dot = p:CreateTexture(nil, "ARTWORK")
        p.dot:SetAllPoints()
        p.dot:SetTexture("Interface\\COMMON\\Indicator-Yellow")
        p.num = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        p.num:SetPoint("BOTTOM", p, "TOP", 0, 0)
        wayPins[i] = p
    end
    return wayPins[i]
end

local playerPin = CreateFrame("Frame", nil, pinLayer)
playerPin:SetSize(22, 22)
playerPin:SetFrameLevel(pinLayer:GetFrameLevel() + 3)
playerPin.arrow = playerPin:CreateTexture(nil, "OVERLAY")
playerPin.arrow:SetAllPoints()
playerPin.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
playerPin:Hide()

local function FitRect(aspect)
    if not aspect or aspect <= 0 then return 0, 0, CANVAS_W, CANVAS_H end
    local w, h
    if (CANVAS_W / CANVAS_H) > aspect then
        h = CANVAS_H; w = h * aspect
    else
        w = CANVAS_W; h = w / aspect
    end
    return (CANVAS_W - w) * 0.5, (CANVAS_H - h) * 0.5, w, h
end

local function SetDrawRect(x, y, w, h)
    ns.drawX, ns.drawY, drawW, drawH = x, y, w, h
end

-- px, py are 0..1 fractions of the drawn map
local function Place(region, px, py)
    region:ClearAllPoints()
    region:SetPoint("CENTER", canvas, "TOPLEFT", ns.drawX + px * drawW, -(ns.drawY + py * drawH))
end

-- Draw the boss portrait (from its creature display ID) into a texture, or a
-- skull when no ID is known or the client cannot render creature portraits.
local CROSS_TEX = "Interface\\RaidFrame\\ReadyCheck-NotReady"   -- red X

local function SetBossIcon(tex, name, dead)
    if not tex then return end
    local displayID = name and BOSS_DISPLAY[name]
    local ok = false
    if displayID and SetPortraitTextureFromCreatureDisplayID then
        ok = pcall(SetPortraitTextureFromCreatureDisplayID, tex, displayID)
        if ok then tex:SetTexCoord(0, 1, 0, 1) end
    end
    if not ok then
        tex:SetTexture(SKULL_TEX)
        tex:SetTexCoord(0.75, 1, 0.25, 0.5)
    end
    if tex.SetDesaturated then pcall(tex.SetDesaturated, tex, dead and true or false) end
    tex:SetAlpha(dead and 0.6 or 1)
    tex:Show()
    -- red cross over a dead boss (created on first use, sized to the icon)
    if dead and not tex.cross then
        local parent = tex:GetParent()
        if parent then
            tex.cross = parent:CreateTexture(nil, "OVERLAY")
            tex.cross:SetTexture(CROSS_TEX)
            tex.cross:SetPoint("TOPLEFT", tex, "TOPLEFT", -1, 1)
            tex.cross:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", 1, -1)
        end
    end
    if tex.cross then
        if dead then tex.cross:Show() else tex.cross:Hide() end
    end
end

-- shared with the other BossNav files
ns.FitRect = FitRect
ns.GetBossPin = GetBossPin
ns.GetRow = GetRow
ns.GetBossRow = GetBossRow
ns.SetWide = SetWide
ns.BOSS_COL_W = BOSS_COL_W
ns.ITEM_COL_W = ITEM_COL_W
ns.bossCol = bossCol
ns.bossColRows = bossColRows
ns.itemAnchor = itemAnchor
ns.itemCol = itemCol
ns.GetTile = GetTile
ns.GetWayPin = GetWayPin
ns.HELP_BOSS = HELP_BOSS
ns.HideTilesFrom = HideTilesFrom
ns.MARK_W = MARK_W
ns.SetListTop = SetListTop
ns.listAnchor = listAnchor
ns.MAX_ROWS = MAX_ROWS
ns.NAME_FONT_SIZE = NAME_FONT_SIZE
ns.ROW_H = ROW_H
ns.Place = Place
ns.RoundIcon = RoundIcon
ns.SetRowActive = SetRowActive
ns.AddRoundHover = AddRoundHover
ns.SetBossIcon = SetBossIcon
ns.SetDrawRect = SetDrawRect
ns.SetFontSize = SetFontSize
ns.bossPins = bossPins
ns.bossRows = bossRows
ns.canvas = canvas
ns.headerText = headerText
ns.helpText = helpText
ns.mapFrame = mapFrame
ns.navText = navText
ns.noArtText = noArtText
ns.pinLayer = pinLayer
ns.playerPin = playerPin
ns.sidebar = sidebar
ns.statusText = statusText
ns.wayPins = wayPins
