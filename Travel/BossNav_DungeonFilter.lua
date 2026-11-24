-- The "Available only" box under the dungeon list: ticked, the list shows
-- only the dungeons in your level range (green) that your faction can
-- enter; unticked, it shows them all. Saved in BossNavDB.availableOnly.
-- The picked dungeon is filtered like any other; only the one you are in
-- always stays in the list.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local LevelColor             = ns.LevelColor
local MAX_ROWS               = ns.MAX_ROWS
local PlayerFaction          = ns.PlayerFaction
local PlayerLevel            = ns.PlayerLevel
local Print                  = ns.Print
local ROW_H                  = ns.ROW_H
local RefreshIfShown         = ns.RefreshIfShown
local TRAVEL                 = ns.TRAVEL
local listAnchor             = ns.listAnchor
local sidebar                = ns.sidebar
local state                  = ns.state

local GREEN = LevelColor({ minLevel = 1, maxLevel = 1 }, 1)

local function AvailableOnly()
    return DB().availableOnly == true
end

-- True when dungeon i belongs in the list right now.
local function DungeonShown(i)
    if not AvailableOnly() then return true end
    local e = TRAVEL[i]
    if not e then return false end
    if state.cfg and e.cfg and e.cfg.key == state.cfg.key then return true end
    local myFaction = PlayerFaction()
    if e.faction and myFaction and e.faction ~= myFaction then return false end
    local color = LevelColor(e, PlayerLevel())
    -- level unknown: keep it rather than hide everything
    return color == nil or color == GREEN
end

-- Indexes into TRAVEL of the dungeons shown, in list order.
local function VisibleDungeons()
    local list = {}
    for i = 1, #TRAVEL do
        if DungeonShown(i) then list[#list + 1] = i end
    end
    return list
end

--------------------------------------------------------------------------
-- The box, just under the last row of the list
--------------------------------------------------------------------------
local cb = CreateFrame("CheckButton", nil, sidebar, "UICheckButtonTemplate")
cb:SetSize(24, 24)
cb:SetPoint("TOPLEFT", listAnchor, "TOPLEFT", 4, -MAX_ROWS * ROW_H - 6)
cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
cb.label:SetPoint("LEFT", cb, "RIGHT", 1, 0)
cb.label:SetText("Available only  |cff888888/bnav available|r")
cb:Hide()

local function SetAvailableOnly(on, quiet)
    DB().availableOnly = on and true or false
    cb:SetChecked(on)
    if not quiet then
        Print(on and "Dungeon list: |cffffd100available only|r (your level range)."
                  or "Dungeon list: |cffffd100all dungeons|r.")
    end
    RefreshIfShown()
end

cb:SetScript("OnClick", function(self) SetAvailableOnly(self:GetChecked()) end)

local function ShowDungeonFilter()
    cb:SetChecked(AvailableOnly())
    cb:Show()
end

local function HideDungeonFilter()
    cb:Hide()
end

-- /bnav available [on|off]: no word flips it
ns.AddCommand({ "available", "avail" }, function(rest)
    local word = (rest or ""):lower():match("^%s*(%S*)")
    if word == "on" then SetAvailableOnly(true)
    elseif word == "off" or word == "all" then SetAvailableOnly(false)
    else SetAvailableOnly(not AvailableOnly()) end
end, {
    "  /bnav available [on|off]  dungeon list: only dungeons in your level range, or all (the box under the list; no word flips it)",
})

-- shared with the other BossNav files
ns.DungeonShown = DungeonShown
ns.HideDungeonFilter = HideDungeonFilter
ns.ShowDungeonFilter = ShowDungeonFilter
ns.VisibleDungeons = VisibleDungeons
