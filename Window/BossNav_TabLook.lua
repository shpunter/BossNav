-- The look of a tab button, shared by the section tabs (BossNav_Tabs.lua)
-- and the item filter tabs (BossNav_FilterPanel.lua): rounded top corners,
-- and on the open tab a gold outline on top, left and right that runs into
-- the gold line the tabs sit on.
--
--    .--------.          the open tab: the panel's colour, one pixel taller
--   /  Open    \  ____   than the others so it covers the line below
--   |          | / Idle\
--  -'          '--------'---
--
-- Textures have no border radius: a tab is drawn as a few one-pixel rows
-- that start further in at the top (the rounded corners) over a body.
local ADDON, ns = ...

local EDGE = { 0.75, 0.62, 0.20, 1 }    -- the gold line the tabs sit on
local PANEL = { 0.06, 0.06, 0.08, 1 }   -- the open tab: the window's dark colour
local IDLE = { 0.13, 0.13, 0.16, 1 }    -- a closed tab
local CORNER = { 3, 2, 1 }              -- per row from the top: how far in it starts
local BORDER = 2                        -- gold outline of the open tab

local function RoundedTop(b, layer, sub)
    local s = { rows = {} }
    for i = 1, #CORNER do
        s.rows[i] = b:CreateTexture(nil, layer, nil, sub)
        s.rows[i]:SetHeight(1)
    end
    s.body = b:CreateTexture(nil, layer, nil, sub)
    return s
end

-- inset: room left free at the top, left and right (the bottom stays flush)
local function PlaceRounded(s, b, inset)
    for i, t in ipairs(s.rows) do
        local x, y = inset + CORNER[i], -(inset + i - 1)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", b, "TOPLEFT", x, y)
        t:SetPoint("TOPRIGHT", b, "TOPRIGHT", -x, y)
    end
    s.body:ClearAllPoints()
    s.body:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -(inset + #CORNER))
    s.body:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, 0)
end

local function ColorRounded(s, r, g, b, a)
    for _, t in ipairs(s.rows) do t:SetColorTexture(r, g, b, a) end
    s.body:SetColorTexture(r, g, b, a)
end

local function ShowRounded(s, shown)
    for _, t in ipairs(s.rows) do t:SetShown(shown) end
    s.body:SetShown(shown)
end

-- Gives a tab button its background, outline and mouse-over glow.
local function StyleTab(b)
    -- gold shape under the fill: shows as the open tab's outline
    b.border = RoundedTop(b, "BACKGROUND", 0)
    PlaceRounded(b.border, b, 0)
    ColorRounded(b.border, unpack(EDGE))
    b.bg = RoundedTop(b, "BACKGROUND", 1)
    b.hl = RoundedTop(b, "HIGHLIGHT")
    PlaceRounded(b.hl, b, 0)
    ColorRounded(b.hl, 1, 0.82, 0, 0.12)
end

-- Open or closed look. height: the tab's normal height; the open tab is one
-- pixel taller, so it covers the gold line and runs into the panel below.
local function PaintTab(b, open, height)
    PlaceRounded(b.bg, b, open and BORDER or 0)
    ColorRounded(b.bg, unpack(open and PANEL or IDLE))
    ShowRounded(b.border, open)
    b:SetHeight(open and height + 1 or height)
end

-- shared with the other BossNav files
ns.TAB_EDGE = EDGE
ns.StyleTab = StyleTab
ns.PaintTab = PaintTab
