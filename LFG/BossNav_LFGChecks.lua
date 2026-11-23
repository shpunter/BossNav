-- Tank / Heal / DD checkboxes in a small bar above the Looking For Group
-- window. The bar is a child of the window, so it shows and hides with it.
-- Ticking a box is the same as /bnav lfg tank|heal|dps.
local ADDON, ns = ...
-- from the files loaded before this one
local LFGIsChecked           = ns.LFGIsChecked
local LFGToggleRole          = ns.LFGToggleRole

-- the window's frame name differs between client styles; the first one found wins
local HOSTS = { "LFGBrowseFrame", "LFGParentFrame", "LFGListFrame", "PVEFrame" }
local BOXES = {
    { role = "tank",   label = "Tank" },
    { role = "healer", label = "Heal" },
    { role = "dps",    label = "DD" },
}

local bar, host
local checks = {}

local function RefreshLFGChecks()
    for role, cb in pairs(checks) do cb:SetChecked(LFGIsChecked(role)) end
end

local function Build(parent)
    bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(250, 28)
    bar:SetPoint("BOTTOM", parent, "TOP", 0, 2)
    bar:SetFrameStrata("HIGH")
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.75)

    local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("LEFT", 8, 0)
    title:SetText("Roles:")

    local prev = title
    for _, b in ipairs(BOXES) do
        local cb = CreateFrame("CheckButton", nil, bar, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("LEFT", prev, "RIGHT", prev == title and 6 or 36, 0)
        local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", cb, "RIGHT", 0, 1)
        text:SetText(b.label)
        cb:SetScript("OnClick", function() LFGToggleRole(b.role) end)
        checks[b.role] = cb
        prev = cb
    end
    RefreshLFGChecks()
end

local function TryAttach()
    if bar then return end
    for _, name in ipairs(HOSTS) do
        local f = _G[name]
        if type(f) == "table" and f.GetObjectType then
            host = name
            Build(f)
            return
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", TryAttach)

-- shared with the other BossNav files
ns.LFGChecksHost = function() TryAttach() return host end
ns.RefreshLFGChecks = RefreshLFGChecks
