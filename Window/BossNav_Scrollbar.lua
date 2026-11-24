-- A thin scrollbar for the lists of the window: a dark track at the right
-- edge of the list and a gold thumb showing which part is in view. Only a
-- picture; the lists scroll with the mouse wheel and the keys themselves.
local ADDON, ns = ...

-- parent: the column frame; anchor: the list's top anchor; rows, rowH:
-- how many rows fit and how tall each one is.
local function NewScrollbar(parent, anchor, rows, rowH)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetWidth(5)
    bar:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -1, 0)
    bar:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", -1, -rows * rowH)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.15, 0.15, 0.18, 1)
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetWidth(5)
    thumb:SetColorTexture(0.75, 0.62, 0.20, 1)
    bar:Hide()

    -- first: list position of the top row; n: rows in the whole list.
    -- Hidden when everything fits.
    function bar:Draw(first, n)
        if n <= rows then self:Hide() return end
        local trackH = rows * rowH
        local thumbH = math.max(12, trackH * rows / n)
        local offset = (first - 1) / (n - rows) * (trackH - thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", self, "TOP", 0, -offset)
        thumb:SetHeight(thumbH)
        self:Show()
    end

    return bar
end

-- shared with the other BossNav files
ns.NewScrollbar = NewScrollbar
