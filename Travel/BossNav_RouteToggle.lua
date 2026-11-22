-- The "By foot" / "Flying" choice under the map in travel mode: two boxes
-- of which exactly one is ticked, and the /bnav route command behind them.
-- Which mode means what lives in BossNav_Routes.lua (ROUTE_MODES).
local ADDON, ns = ...
-- from the files loaded before this one
local CANVAS_W               = ns.CANVAS_W
local Print                  = ns.Print
local ROUTE_MODES            = ns.ROUTE_MODES
local RefreshIfShown         = ns.RefreshIfShown
local RouteMode              = ns.RouteMode
local SetRouteMode           = ns.SetRouteMode
local helpText               = ns.helpText
local mapFrame               = ns.mapFrame

--------------------------------------------------------------------------
-- Widgets: a row in the free space below the help line
--------------------------------------------------------------------------
local row = CreateFrame("Frame", nil, mapFrame)
row:SetSize(CANVAS_W, 24)
row:SetPoint("TOPLEFT", helpText, "BOTTOMLEFT", 0, -10)
row:Hide()

local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("LEFT", row, "LEFT", 0, 0)
title:SetText("Route")

local boxes = {}

-- Tick the chosen mode and nothing else.
local function SyncBoxes()
    local current = RouteMode()
    for key, cb in pairs(boxes) do cb:SetChecked(key == current) end
end

-- Switch mode, keep the boxes in step and re-plan the leg right away.
local function ChooseRouteMode(key, quiet)
    local m = SetRouteMode(key)
    if not m then return false end
    SyncBoxes()
    if not quiet then Print(string.format("Travel route: |cffffd100%s|r (%s).", m.label:lower(), m.words)) end
    RefreshIfShown()
    pcall(BossNav_UpdateLive, true)
    return true
end

local x = 48
for _, m in ipairs(ROUTE_MODES) do
    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("LEFT", row, "LEFT", x, 0)
    cb.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 1, 0)
    cb.label:SetText(m.label)
    -- Clicking the ticked box keeps it ticked: one mode is always chosen.
    cb:SetScript("OnClick", function() ChooseRouteMode(m.key) end)
    boxes[m.key] = cb
    x = x + 24 + 1 + 68
end

local hint = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("LEFT", row, "LEFT", x + 4, 0)
hint:SetText("/bnav route foot | fly")

local function ShowRouteToggle()
    SyncBoxes()
    row:Show()
end

local function HideRouteToggle()
    row:Hide()
end

--------------------------------------------------------------------------
-- /bnav route [foot | fly]: pick a mode by word; no word flips to the other.
--------------------------------------------------------------------------
local WORDS = {
    foot = "foot", feet = "foot", walk = "foot", walking = "foot", ground = "foot",
    fly = "fly", flying = "fly", flight = "fly", taxi = "fly", air = "fly",
}

local function RouteCommand(rest)
    local word = (rest or ""):lower():match("^%s*(%S*)")
    local key
    if word == "" then
        key = (RouteMode() == "fly") and "foot" or "fly"
    else
        key = WORDS[word]
    end
    if not (key and ChooseRouteMode(key)) then
        Print("Usage: /bnav route foot | fly  (walk zone to zone, or use flight masters)")
    end
end

-- /bnav route foot|fly, and the short forms /bnav walk, foot, fly
ns.AddCommand("route", RouteCommand, {
    "  /bnav route foot|fly  outside: walk zone to zone, or use flight masters where a path is known at both ends (the boxes under the map; no word flips it)",
})
ns.AddCommand({ "walk", "foot" }, function() RouteCommand("foot") end)
ns.AddCommand("fly", function() RouteCommand("fly") end)

-- shared with the other BossNav files
ns.HideRouteToggle = HideRouteToggle
ns.ShowRouteToggle = ShowRouteToggle
