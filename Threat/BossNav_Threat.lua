-- Threat window: one row per enemy that is in combat near you.
--
-- Each row starts with your own threat on the mob in percent, then its raid
-- mark, level ("L30"), name and health, and who it is attacking (the group
-- member at the top of its threat list, else its current target). The row is
-- coloured by the game's threat status:
--   grey   you are low on its list
--   yellow you are above the tank and about to pull it
--   orange it is attacking you but someone is close to taking it
--   red    it is attacking you and stays on you
-- Mobs that attack you come first, then the ones you are closest to pulling.
--
-- Tank mode (switches on by itself when you tank, see BossNav_Role.lua):
-- loose mobs that attack someone else come first, lowest threat on top, then
-- the mobs you hold, shakiest first. On a mob you hold, the row shows who is
-- next in line and how close they are to pulling it, instead of your 100%.
--
-- Nearby enemies are only visible to addons through their nameplates, so
-- enemy nameplates are switched on. Every unit read is guarded: whatever the
-- client hides as a secret value is shown as "?" instead of breaking.
local ADDON, ns = ...
-- from the files loaded before this one
local CheckAggroLoss         = ns.CheckAggroLoss
local ColorName              = ns.ColorName
local DB                     = ns.DB
local IsSecret               = ns.IsSecret
local CycleTankMode          = ns.CycleTankMode
local HideThreatPlates       = ns.HideThreatPlates
local LOOSE_COLOR            = ns.THREAT_LOOSE_COLOR
local PlayerIsTank           = ns.PlayerIsTank
local Print                  = ns.Print
local STATUS_COLOR           = ns.THREAT_STATUS_COLOR
local ToggleAggroAlert       = ns.ToggleAggroAlert
local ToggleThreatPlates     = ns.ToggleThreatPlates
local UnitNameClass          = ns.UnitNameClass
local UpdateThreatPlates     = ns.UpdateThreatPlates

local MAX_ROWS = 10
local ROW_H = 18
local WIDTH = 350
local UPDATE_EVERY = 0.2       -- seconds between refreshes
local MARK_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

local function Known(v)
    if IsSecret(v) then return nil end
    return v
end

--------------------------------------------------------------------------
-- Frame
--------------------------------------------------------------------------
local win = CreateFrame("Frame", "BossNavThreat", UIParent)
win:SetSize(WIDTH, 22)
win:SetPoint("LEFT", UIParent, "CENTER", 220, 80)
win:SetFrameStrata("MEDIUM")
win:SetClampedToScreen(true)
win:Hide()

-- Drag with the left mouse button; the spot is saved and restored after a reload.
win:SetMovable(true)
win:EnableMouse(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart", function(self) self:StartMoving() end)
win:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint(1)
    DB().threatPos = { point, relPoint, x, y }
end)

local function RestorePosition()
    local p = DB().threatPos
    if type(p) ~= "table" or not p[1] then return end
    win:ClearAllPoints()
    win:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end
local bg = win:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.55)
win.title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
win.title:SetPoint("TOPLEFT", win, "TOPLEFT", 6, -4)
win.title:SetText("Threat")

local rows = {}
for i = 1, MAX_ROWS do
    local r = CreateFrame("Frame", nil, win)
    r:SetSize(WIDTH - 8, ROW_H)
    r:SetPoint("TOPLEFT", win, "TOPLEFT", 4, -18 - (i - 1) * (ROW_H + 2))
    -- row background tinted by your threat status (grey / yellow / orange / red)
    r.tint = r:CreateTexture(nil, "BACKGROUND")
    r.tint:SetAllPoints()
    r.tint:SetColorTexture(0.15, 0.15, 0.15, 0.6)
    -- mob health: a thin line along the bottom of the row, in the threat colour
    r.hp = CreateFrame("StatusBar", nil, r)
    r.hp:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
    r.hp:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
    r.hp:SetHeight(2)
    r.hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    r.hp:SetStatusBarColor(0.2, 0.9, 0.2, 0.9)
    r.hp:SetMinMaxValues(0, 1)
    r.hp:SetValue(1)
    -- first column: the threat number, in the threat colour
    r.num = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.num:SetPoint("LEFT", r, "LEFT", 2, 0)
    r.num:SetWidth(34)
    r.num:SetJustifyH("RIGHT")
    r.mark = r:CreateTexture(nil, "OVERLAY")
    r.mark:SetSize(14, 14)
    r.mark:SetPoint("LEFT", r, "LEFT", 40, 0)
    r.mark:SetTexture(MARK_TEX)
    -- mob level, coloured like the game's con colours (grey/green/yellow/orange/red)
    r.level = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.level:SetPoint("LEFT", r, "LEFT", 57, 0)
    r.level:SetWidth(26)
    r.level:SetJustifyH("LEFT")
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.name:SetPoint("LEFT", r, "LEFT", 84, 0)
    r.name:SetWidth(100)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.holder = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.holder:SetPoint("LEFT", r.name, "RIGHT", 4, 0)
    r.holder:SetWidth(110)
    r.holder:SetJustifyH("LEFT")
    r.holder:SetWordWrap(false)
    r.pct = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.pct:SetPoint("RIGHT", r, "RIGHT", -3, 0)
    r.pct:SetJustifyH("RIGHT")
    r:Hide()
    rows[i] = r
end

--------------------------------------------------------------------------
-- Reading the mobs
--------------------------------------------------------------------------
-- Group units whose threat is checked: you, plus party or raid members
local function GroupUnits()
    local list = {}
    local okR, raid = pcall(IsInRaid)
    if okR and raid == true then
        for i = 1, 40 do list[#list + 1] = "raid" .. i end
    else
        list[1] = "player"
        for i = 1, 4 do list[#list + 1] = "party" .. i end
    end
    return list
end

-- Who is on the mob's threat list, who it is attacking, and your own threat
local function ReadThreat(mob, members)
    local t = { onList = false, unknown = false }
    for _, m in ipairs(members) do
        local okE, exists = pcall(UnitExists, m)
        if okE and Known(exists) then
            local ok, tanking, status, scaled = pcall(UnitDetailedThreatSituation, m, mob)
            if not ok or IsSecret(tanking) or IsSecret(status) then
                t.unknown = true
            elseif status ~= nil then
                t.onList = true
                if tanking then t.holder = m end
                local okMe, isMe = pcall(UnitIsUnit, m, "player")
                if okMe and Known(isMe) then
                    t.myStatus = status
                    t.myPct = Known(scaled)
                elseif okMe and Known(isMe) == false then
                    -- the group member closest to pulling it (for tank mode)
                    local pct = Known(scaled)
                    if pct and not tanking and pct > (t.nextPct or -1) then
                        t.nextPct, t.nextUnit = pct, m
                    end
                end
            end
        end
    end
    -- the short threat call: sometimes readable when the detailed one is hidden
    if t.myStatus == nil then
        local ok, status = pcall(UnitThreatSituation, "player", mob)
        if ok and type(Known(status)) == "number" then
            t.myStatus = status
            t.onList = true
        end
    end
    -- last resort: whoever the mob has targeted (its target is who it hits)
    if not t.holder then
        for _, m in ipairs(members) do
            local okE, exists = pcall(UnitExists, m)
            if okE and Known(exists) then
                local ok, same = pcall(UnitIsUnit, mob .. "target", m)
                if ok and Known(same) == true then
                    t.holder = m
                    t.onList = true
                    local okMe, isMe = pcall(UnitIsUnit, m, "player")
                    if okMe and Known(isMe) and t.myStatus == nil then t.myStatus = 3 end
                    break
                end
            end
        end
    end
    return t
end

local function InCombatMob(unit)
    local ok, can = pcall(UnitCanAttack, "player", unit)
    if ok and Known(can) == false then return false end
    local okD, dead = pcall(UnitIsDead, unit)
    if okD and Known(dead) == true then return false end
    local okC, combat = pcall(UnitAffectingCombat, unit)
    if okC and not IsSecret(combat) then return combat == true, true end
    return nil  -- the client hides it
end

-- attacking you first, then whoever you are closest to pulling
local function NormalOrder(a, b)
    local sa, sb = a.myStatus or -1, b.myStatus or -1
    if (sa >= 2) ~= (sb >= 2) then return sa >= 2 end
    return (a.myPct or -1) > (b.myPct or -1)
end

-- Tank: 0 loose and you are low, 1 loose but you are about to take it,
-- 2 yours but someone is close, 3 yours and safe, 4 nothing known
local function TankRank(t)
    if t.myStatus then return t.myStatus end
    if t.holder or t.onList then return 0 end
    return 4
end

local function TankOrder(a, b)
    local ra, rb = TankRank(a), TankRank(b)
    if ra ~= rb then return ra < rb end
    if ra <= 1 then return (a.myPct or 0) < (b.myPct or 0) end   -- least threat first
    return (a.nextPct or -1) > (b.nextPct or -1)                -- closest pull first
end

local function CollectMobs(tank)
    local members = GroupUnits()
    local mobs = {}
    for i = 1, 40 do
        local unit = "nameplate" .. i
        local ok, exists = pcall(UnitExists, unit)
        if ok and (IsSecret(exists) or exists) then
            local combat = InCombatMob(unit)
            if combat ~= false then
                local t = ReadThreat(unit, members)
                -- unknown combat state: keep it only when someone is (or may be) on its list
                if combat == true or t.onList or t.unknown then
                    t.unit = unit
                    mobs[#mobs + 1] = t
                end
            end
        end
    end
    table.sort(mobs, tank and TankOrder or NormalOrder)
    return mobs
end

--------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------
local function SetMark(tex, idx)
    idx = tonumber(Known(idx))
    if not idx or idx < 1 or idx > 8 then tex:Hide() return end
    local n = idx - 1
    local col, row = n % 4, math.floor(n / 4)
    tex:SetTexCoord(col / 4, (col + 1) / 4, row / 4, (row + 1) / 4)
    tex:Show()
end

-- "32" in the con colour, "??" (red) for a boss or a mob far above you
local function SetLevel(fs, level)
    level = tonumber(Known(level))
    if not level then fs:SetText("") return end
    if level < 0 then
        fs:SetText("L??")
        fs:SetTextColor(1.0, 0.1, 0.1)
        return
    end
    fs:SetText("L" .. tostring(level))
    local okC, c = pcall(GetCreatureDifficultyColor or GetQuestDifficultyColor, level)
    if okC and type(c) == "table" and c.r then
        fs:SetTextColor(c.r, c.g, c.b)
    else
        fs:SetTextColor(1, 1, 1)
    end
end

local function HolderText(r, t, tank)
    if t.holder then
        local okMe, isMe = pcall(UnitIsUnit, t.holder, "player")
        if okMe and Known(isMe) then
            local name, class
            if tank and t.nextUnit then name, class = UnitNameClass(t.nextUnit) end
            if name then
                r.holder:SetText("|cffff4444YOU|r, next " .. ColorName(name, class, 12))
            else
                r.holder:SetText("|cffff4444on YOU|r")
            end
            return
        end
        local name, class = UnitNameClass(t.holder)
        if name then
            r.holder:SetText("on " .. ColorName(name, class, 12))
            return
        end
    end
    -- nobody known on top: show whatever the mob has targeted (the client may hide it)
    local ok = pcall(function()
        local name = UnitName(t.unit .. "target")
        if IsSecret(name) or name then r.holder:SetText(name) else r.holder:SetText("") end
    end)
    if not ok then r.holder:SetText("?") end
end

-- Row background, health line and percent text in the threat status colour;
-- grey background and green health line when the status is unknown;
-- pink in tank mode for a mob that is not on you
local function Tint(r, status, loose)
    local c = loose and LOOSE_COLOR or STATUS_COLOR[status or -1]
    if c then
        r.tint:SetColorTexture(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 0.75)
        r.pct:SetTextColor(c[1], c[2], c[3])
        r.num:SetTextColor(c[1], c[2], c[3])
        r.hp:SetStatusBarColor(c[1], c[2], c[3], 0.9)
    else
        r.tint:SetColorTexture(0.15, 0.15, 0.15, 0.6)
        r.pct:SetTextColor(0.7, 0.7, 0.7)
        r.num:SetTextColor(0.7, 0.7, 0.7)
        r.hp:SetStatusBarColor(0.2, 0.9, 0.2, 0.9)
    end
end

local function DrawRow(r, t, tank)
    pcall(function() SetMark(r.mark, GetRaidTargetIndex(t.unit)) end)
    if not pcall(function() r.name:SetText(UnitName(t.unit)) end) then r.name:SetText("?") end
    if not pcall(function() SetLevel(r.level, UnitLevel(t.unit)) end) then r.level:SetText("") end
    local okHp = pcall(function()
        r.hp:SetMinMaxValues(0, UnitHealthMax(t.unit))
        r.hp:SetValue(UnitHealth(t.unit))
    end)
    r.hp:SetShown(okHp)
    HolderText(r, t, tank)
    local loose = tank and (t.myStatus or 0) < 2 and (t.myStatus ~= nil or t.holder ~= nil or t.onList)
    Tint(r, t.myStatus, loose)
    -- first column: the threat number; last column: LOOSE for a mob not on you
    local function Pct(v) return string.format("%d%%", math.floor(v + 0.5)) end
    if tank and (t.myStatus or 0) >= 2 then
        -- yours: how close the next one in line is to pulling it
        r.num:SetText(t.nextPct and Pct(t.nextPct) or "-")
    elseif t.myPct then
        r.num:SetText(Pct(t.myPct))
    elseif t.myStatus or loose then
        r.num:SetText("-")
    else
        r.num:SetText(t.unknown and "?" or "")
    end
    r.pct:SetText(loose and "LOOSE" or "")
    r:Show()
end

local function Draw(mobs, tank)
    local n = math.min(#mobs, MAX_ROWS)
    for i = 1, MAX_ROWS do
        if i <= n then DrawRow(rows[i], mobs[i], tank) else rows[i]:Hide() end
    end
    if n == 0 then win:Hide() return end
    local extra = #mobs - n
    local title = tank and "Threat - tank" or "Threat"
    win.title:SetText(extra > 0 and string.format("%s  (+%d more)", title, extra) or title)
    win:SetHeight(20 + n * (ROW_H + 2) + 2)
    win:Show()
end

--------------------------------------------------------------------------
-- Preview with made-up mobs, so the layout can be seen out of combat
--------------------------------------------------------------------------
local testUntil = 0
local function DrawTest()
    local fake = {
        { "Deviate Ravager", 8, "|cffff4444on YOU|r", 100, 3, 0.7, 19 },
        { "Druid of the Fang", nil, "on Tankname", 92, 1, 0.4, 20 },
        { "Deviate Lasher", nil, "|cffff4444on YOU|r", 100, 2, 0.9, 18 },
        { "Deviate Viper", 2, "on Tankname", 35, 0, 1.0, -1 },
    }
    for i = 1, MAX_ROWS do
        local f, r = fake[i], rows[i]
        if f then
            r.name:SetText(f[1])
            SetLevel(r.level, f[7])
            SetMark(r.mark, f[2])
            r.holder:SetText(f[3])
            r.num:SetText(string.format("%d%%", f[4]))
            r.pct:SetText("")
            Tint(r, f[5])
            r.hp:Show()
            r.hp:SetMinMaxValues(0, 1)
            r.hp:SetValue(f[6])
            r:Show()
        else
            r:Hide()
        end
    end
    win.title:SetText("Threat  (preview)")
    win:SetHeight(20 + #fake * (ROW_H + 2) + 2)
    win:Show()
end

--------------------------------------------------------------------------
-- Driver
--------------------------------------------------------------------------
local elapsed = 0
local drawErrorShown = false
local driver = CreateFrame("Frame")
-- saved settings exist only once the addon has finished loading
driver:RegisterEvent("ADDON_LOADED")
driver:SetScript("OnEvent", function(_, _, name)
    if name == ADDON then pcall(RestorePosition) end
end)
driver:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < UPDATE_EVERY then return end
    elapsed = 0
    if GetTime() < testUntil then return end
    if not DB().threat then
        if win:IsShown() then win:Hide() end
        pcall(HideThreatPlates)
        return
    end
    local okT, tank = pcall(PlayerIsTank)
    tank = okT and tank == true
    local ok, mobs = pcall(CollectMobs, tank)
    local okD, err = false, mobs
    if ok then okD, err = pcall(Draw, mobs, tank) end
    if not okD then
        win:Hide()
        -- say once per session why the window is missing, instead of hiding silently
        if not drawErrorShown then
            drawErrorShown = true
            Print("|cffff4444threat window error:|r " .. tostring(err) .. "  (please report this line)")
        end
    end
    pcall(UpdateThreatPlates, ok and mobs or nil, tank)
    pcall(CheckAggroLoss, ok and mobs or nil, tank)
end)

-- Enemy nameplates must be on for the addon to see nearby mobs.
-- The game refuses this setting during combat, so it is only tried outside.
local function EnsureNameplates()
    if InCombatLockdown and InCombatLockdown() then return end
    local ok, shown = pcall(GetCVar, "nameplateShowEnemies")
    if ok and (shown == "0" or shown == 0) then
        if pcall(SetCVar, "nameplateShowEnemies", "1") then
            Print("Enemy nameplates turned on (the threat window sees mobs through them).")
        end
    end
end

function BossNav_ToggleThreat()
    DB().threat = not DB().threat
    Print("Threat window " .. (DB().threat and "on" or "off") .. ".")
    if DB().threat then EnsureNameplates() else win:Hide() end
end

-- /bnav threat [test]
local function ThreatCommand(rest)
    rest = (rest or ""):lower()
    if rest == "test" then
        testUntil = GetTime() + 30
        DrawTest()
        Print("Threat window preview for 30 seconds (drag it to move it).")
    elseif rest == "alert" then
        Print("Lost-aggro alert for tanks " .. (ToggleAggroAlert() and "on" or "off") .. ".")
    elseif rest == "plates" then
        Print("Threat labels on enemy nameplates " .. (ToggleThreatPlates() and "on" or "off") .. ".")
    elseif rest == "tank" then
        local mode = CycleTankMode()
        local tank, why = PlayerIsTank()
        Print(string.format("Threat tank mode: %s (right now: %s, %s).", mode,
            tank and "tank" or "not tank", why))
    elseif rest == "debug" then
        -- raw values the client gives for each mob, to see what is readable
        local function show(v) if IsSecret(v) then return "SECRET" end return tostring(v) end
        local okT, tank, why = pcall(PlayerIsTank)
        Print(string.format("tank mode: %s (%s)", okT and tostring(tank) or "error", tostring(why)))
        local members, seen = GroupUnits(), 0
        for i = 1, 40 do
            local unit = "nameplate" .. i
            local ok, exists = pcall(UnitExists, unit)
            if ok and (IsSecret(exists) or exists) then
                seen = seen + 1
                local _, combat = pcall(UnitAffectingCombat, unit)
                local _, hp = pcall(UnitHealth, unit)
                Print(string.format("%s: combat=%s  health=%s", unit, show(combat), show(hp)))
                local _, short = pcall(UnitThreatSituation, "player", unit)
                local _, onMe = pcall(UnitIsUnit, unit .. "target", "player")
                Print(string.format("   short threat=%s  targets me=%s", show(short), show(onMe)))
                for _, m in ipairs(members) do
                    local okE, mex = pcall(UnitExists, m)
                    if okE and (IsSecret(mex) or mex) then
                        local okT, tanking, status, scaled = pcall(UnitDetailedThreatSituation, m, unit)
                        Print(string.format("   %s: ok=%s tanking=%s status=%s pct=%s", m,
                            tostring(okT), show(tanking), show(status), show(scaled)))
                    end
                end
            end
        end
        if seen == 0 then Print("threat debug: no enemy nameplates in view.") end
    elseif rest == "reset" then
        DB().threatPos = nil
        win:ClearAllPoints()
        win:SetPoint("LEFT", UIParent, "CENTER", 220, 80)
        Print("Threat window moved back to its starting spot.")
    else
        BossNav_ToggleThreat()
    end
end

-- shared with the other BossNav files
ns.EnsureNameplates = EnsureNameplates
ns.ThreatCommand = ThreatCommand
