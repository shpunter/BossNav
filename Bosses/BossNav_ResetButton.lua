-- "Reset Kills" button on the map window, plus the "Reset Kill Marks" keybind.
--
-- The game tells only the player who reset a dungeon, and some dungeons hide
-- the mob IDs that would show it, so a party member clears the kill marks
-- by hand after the leader resets.
local ADDON, ns = ...
-- from the files loaded before this one
local ClearProgress          = ns.ClearProgress
local Print                  = ns.Print
local RefreshIfShown         = ns.RefreshIfShown
local mapFrame               = ns.mapFrame
local canvas                 = ns.canvas
local state                  = ns.state

local function ResetKills()
    if not state.cfg then Print("Enter a known dungeon first.") return end
    ClearProgress(state.cfg)
    Print(state.cfg.name .. ": kill marks cleared, every boss is alive again.")
    RefreshIfShown()
    pcall(BossNav_UpdateLive, true)   -- the HUD's Killed n/m
end

function BossNav_ResetKills()
    pcall(ResetKills)
end

local btn = CreateFrame("Button", nil, mapFrame, "UIPanelButtonTemplate")
btn:SetSize(96, 22)
btn:SetPoint("BOTTOMRIGHT", canvas, "TOPRIGHT", 0, 4)
btn:SetText("Reset Kills")
btn:SetScript("OnClick", BossNav_ResetKills)
