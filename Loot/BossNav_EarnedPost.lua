-- Post the gold and XP earned in this dungeon to group chat: a tiny button
-- at the right end of the top HUD bar, the "Post Gold and XP" keybind and
-- /bnav earned.
local ADDON, ns = ...
-- from the files loaded before this one
local AddCommand             = ns.AddCommand
local ChatChannel            = ns.ChatChannel
local GoldEarned             = ns.GoldEarned
local PlainMoney             = ns.PlainMoney
local Print                  = ns.Print
local RunSeconds             = ns.RunSeconds
local Thousands              = ns.Thousands
local XPEarned               = ns.XPEarned
local hud                    = ns.hud
local state                  = ns.state

-- "1h 05m", "23m 10s" or "45s".
local function Duration(sec)
    sec = math.floor(sec)
    local h, m, s = math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60
    if h > 0 then return string.format("%dh %02dm", h, m) end
    if m > 0 then return string.format("%dm %02ds", m, s) end
    return string.format("%ds", s)
end

-- One chat message per row: chat lines cannot hold a line break.
local function EarnedLines()
    local where = state.cfg and state.cfg.name or "this dungeon"
    local lines = {
        string.format("BossNav: earned in %s so far:", where),
        "Gold: " .. PlainMoney(GoldEarned()),
        "XP: " .. Thousands(XPEarned()),
    }
    local sec = RunSeconds()
    if sec then lines[#lines + 1] = "Time: " .. Duration(sec) end
    return lines
end

-- Not in a group: the lines are only printed for you.
local function PostEarned()
    if not state.cfg then Print("Enter a known dungeon first.") return end
    local lines = EarnedLines()
    local chan = ChatChannel()
    if not chan then
        Print("(not in a group, shown only to you)")
        for _, line in ipairs(lines) do Print(line) end
        return
    end
    for _, line in ipairs(lines) do
        local ok, err = pcall(SendChatMessage, line, chan)
        if not ok then Print("could not post to chat: " .. tostring(err)) return end
    end
end

function BossNav_PostEarned()
    pcall(PostEarned)
end

-- Tiny button just right of the HUD bar; it shows and hides with the bar.
local btn = CreateFrame("Button", nil, hud, "UIPanelButtonTemplate")
btn:SetSize(22, 18)
btn:SetPoint("TOPLEFT", hud, "TOPRIGHT", 2, 0)
btn:SetText("P")
btn:SetScript("OnClick", BossNav_PostEarned)
btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Post gold and XP earned here to party chat")
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

AddCommand("earned", BossNav_PostEarned, {
    "  /bnav earned          post the gold and XP earned in this dungeon to party chat (the P button on the HUD)",
})
