-- Shows how far each group member is: on a party portrait frame just above
-- the name (under the frame sit the buffs, to the right the bars); at the
-- bottom right of a raid-style block: "23 yd", "< 25 yd", "> 40 yd".
--
-- The first way that answers wins:
--   1. Exact yards from both positions (UnitPosition). The client gives
--      positions in the open world only, not inside dungeons.
--   2. A range band from items with known ranges (5 to 100 yards): the
--      smallest range the member is inside gives "< N yd". The player does
--      not need to own the items. Skipped in combat, where the game may
--      block the check for addons.
--   3. The game's own group range check: "< 40 yd" or "> 40 yd".
-- Nobody inside a dungeon gets a distance (the client hides positions
-- there, and range checks through walls mean little):
--   - you inside: only a member still outside shows, as the distance from
--     them to this dungeon's entrance, "out 340 yd" (in blue);
--   - you outside: a member whose position is hidden while yours is
--     readable counts as inside a dungeon and shows nothing.
-- An answer the client hides (a secret value) is skipped; with nothing left
-- the text stays empty. Colours: green within 30 yards (healing and buff
-- range), yellow up to 40, red beyond.
-- /bnav distance turns it off and on.
local ADDON, ns = ...
-- from the files loaded before this one
local DB                     = ns.DB
local Forbidden              = ns.ClassForbidden
local EntranceOf             = ns.EntranceOf
local IsSecret               = ns.IsSecret
local Plain                  = ns.ClassPlain
local TRAVEL                 = ns.TRAVEL
local WorldPos               = ns.WorldPos
local state                  = ns.state

local INTERVAL  = 0.3   -- seconds between updates
local FONT_SIZE = 10

-- { range in yards, item with that range on friendly units }, nearest first
-- (the item ranges range-check addons use; an item the client does not know
-- is skipped)
local LADDER = {
    { 5, 37727 }, { 8, 34368 }, { 10, 32321 }, { 15, 1251 }, { 20, 21519 },
    { 25, 31463 }, { 30, 34191 }, { 35, 18904 }, { 40, 34471 }, { 45, 32698 },
    { 60, 32825 }, { 80, 35278 }, { 100, 33119 },
}

local function Enabled()
    return DB().partyDistance ~= false
end

-- true / false, or nil when the check told nothing readable
local function Bool(ok, v)
    if not ok or v == nil or IsSecret(v) then return nil end
    if v == true or v == 1 then return true end
    if v == false or v == 0 then return false end
    return nil
end

-- 1. exact yards, or nil
local function Yards(unit)
    if not UnitPosition then return nil end
    local ok1, py, px, _, pmap = pcall(UnitPosition, "player")
    local ok2, uy, ux, _, umap = pcall(UnitPosition, unit)
    if not (ok1 and ok2) then return nil end
    py, px, pmap = Plain(py), Plain(px), Plain(pmap)
    uy, ux, umap = Plain(uy), Plain(ux), Plain(umap)
    if type(py) ~= "number" or type(px) ~= "number" or type(uy) ~= "number" or type(ux) ~= "number" then
        return nil
    end
    if pmap ~= umap then return nil end
    return math.sqrt((px - ux) ^ 2 + (py - uy) ^ 2)
end

-- 1b. member outside while you are inside: yards from them to this
-- dungeon's entrance, or nil
local function Num(v)
    v = Plain(v)
    return type(v) == "number" and v or nil
end

-- the dungeon you are in, as a travel entry (it knows the entrance)
local function CurrentEntry()
    if not (state.inInstance and state.cfg) then return nil end
    for _, e in ipairs(TRAVEL) do
        if e.cfg == state.cfg then return e end
    end
    return nil
end

-- continent and world spot of a member, from the zone map they stand on
-- (same reckoning as the entrance, so the two compare)
local function MemberWorld(unit)
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local okM, mapID = pcall(C_Map.GetBestMapForUnit, unit)
    mapID = okM and Num(mapID)
    if not mapID then return nil end
    local okP, v = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
    if not okP or type(v) ~= "table" then return nil end
    local fx, fy
    if v.GetXY then
        local okXY, a, b = pcall(v.GetXY, v)
        if okXY then fx, fy = Num(a), Num(b) end
    else
        fx, fy = Num(v.x), Num(v.y)
    end
    if not (fx and fy) or (fx == 0 and fy == 0) then return nil end
    return WorldPos(mapID, fx, fy)
end

-- yards, "far" when they are on another continent, or nil
local function ToEntrance(unit)
    local entry = CurrentEntry()
    if not entry then return nil end
    local mapID, ex, ey = EntranceOf(entry)
    if not mapID then return nil end
    local econt, ewx, ewy = WorldPos(mapID, ex, ey)
    if not econt then return nil end
    local cont, wx, wy = MemberWorld(unit)
    if not cont then return nil end
    if cont ~= econt then return "far" end
    return math.sqrt((wx - ewx) ^ 2 + (wy - ewy) ^ 2)
end

local function OutsideText(d)
    if d == "far" then return "|cff66bbffout, far|r" end
    local n = d >= 1000 and string.format("%.1fk", d / 1000) or string.format("%d", math.floor(d + 0.5))
    return "|cff66bbffout " .. n .. " yd|r"
end

-- 2. ("<", N) for the nearest range the unit is inside, (">", N) past the
-- farthest one that answered, or nil
local function Band(unit)
    if InCombatLockdown and InCombatLockdown() then return nil end
    local fn = (C_Item and C_Item.IsItemInRange) or IsItemInRange
    if not fn then return nil end
    local farthestOut
    for _, step in ipairs(LADDER) do
        local inside = Bool(pcall(fn, step[2], unit))
        if inside == true then return "<", step[1] end
        if inside == false then farthestOut = step[1] end
    end
    if farthestOut then return ">", farthestOut end
    return nil
end

-- 3. the game's ~40-yard group check
local function GroupBand(unit)
    if not UnitInRange then return nil end
    local ok, inRange, checked = pcall(UnitInRange, unit)
    if not ok or IsSecret(checked) or checked == false then return nil end
    local b = Bool(true, inRange)
    if b == nil then return nil end
    return b and "<" or ">", 40
end

-- you outside: true when the member seems to be inside a dungeon (their
-- position and map are hidden while yours are readable)
local function InDungeon(unit)
    if not UnitPosition then return false end
    local okP, py = pcall(UnitPosition, "player")
    if not okP or not Num(py) then return false end   -- no positions at all: cannot tell
    local okU, uy = pcall(UnitPosition, unit)
    if okU and Num(uy) then return false end
    if C_Map and C_Map.GetBestMapForUnit then
        local okM, mapID = pcall(C_Map.GetBestMapForUnit, unit)
        if okM and Num(mapID) then return false end
    end
    return true
end

local function Colour(yards)
    if yards <= 30 then return "|cff40ff40" end
    if yards <= 40 then return "|cffffd100" end
    return "|cffff4040"
end

-- "23 yd" / "< 25 yd" / "> 40 yd", or nil when nothing could be read
local function DistanceText(unit)
    local okE, exists = pcall(UnitExists, unit)
    if not okE or Plain(exists) ~= true then return nil end
    local okS, isMe = pcall(UnitIsUnit, unit, "player")
    if okS and Plain(isMe) == true then return nil end
    local okC, connected = pcall(UnitIsConnected, unit)
    if okC and Plain(connected) == false then return nil end

    if state.inInstance then
        local d = ToEntrance(unit)
        return d and OutsideText(d) or nil
    end
    local yards = Yards(unit)
    if not yards and InDungeon(unit) then return nil end
    if yards then return Colour(yards) .. string.format("%d yd", math.floor(yards + 0.5)) .. "|r" end
    local sign, n = Band(unit)
    if not sign then sign, n = GroupBand(unit) end
    if not sign then return nil end
    -- "> 40" means farther than 40: colour it as beyond that
    return Colour(sign == ">" and n + 1 or n) .. sign .. " " .. n .. " yd|r"
end

--------------------------------------------------------------------------
-- Text on the frames
--------------------------------------------------------------------------
local texts = {}   -- frame -> its font string

-- the name text of a party portrait frame
local function NameOf(frame, i)
    local n = frame.name or frame.Name
    if not n and i then n = _G["PartyMemberFrame" .. i .. "Name"] end
    if type(n) == "table" and n.GetObjectType then return n end
    return nil
end

local function TextFor(frame, compact, i)
    local fs = texts[frame]
    if fs then return fs end
    local ok, t = pcall(frame.CreateFontString, frame, nil, "OVERLAY", "GameFontHighlightSmall")
    if not ok or not t then return nil end
    local face, _, flags = t:GetFont()
    if face then t:SetFont(face, FONT_SIZE, flags) end
    if compact then
        -- inside the block, bottom right: the next block sits right under it
        t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
        t:SetJustifyH("RIGHT")
    else
        local name = NameOf(frame, i)
        if name then
            -- above the name, clear of its box's border and the leader crown
            t:SetPoint("BOTTOMLEFT", name, "TOPLEFT", 22, 5)   -- right of the leader crown
        else
            t:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 48, 0)
        end
        t:SetJustifyH("LEFT")
    end
    texts[frame] = t
    return t
end

local function Mark(frame, unit, compact, i)
    if type(frame) ~= "table" or Forbidden(frame) or not frame.CreateFontString then return end
    local text = Enabled() and type(unit) == "string" and DistanceText(unit) or nil
    local fs = texts[frame]
    if not text then
        if fs then fs:Hide() end
        return
    end
    fs = TextFor(frame, compact, i)
    if not fs then return end
    fs:SetText(text)
    fs:Show()
end

local function MarkCompact(uf)
    if type(uf) ~= "table" or Forbidden(uf) then return end
    Mark(uf, Plain(uf.displayedUnit) or Plain(uf.unit), true)
end

-- party portrait frames under every name the game has used
local function PartyFrame(i)
    return _G["PartyMemberFrame" .. i] or (_G.PartyFrame and _G.PartyFrame["MemberFrame" .. i])
end

local function MarkAll()
    for i = 1, 4 do Mark(PartyFrame(i), "party" .. i, false, i) end
    for i = 1, 5 do MarkCompact(_G["CompactPartyFrameMember" .. i]) end
    for i = 1, 40 do MarkCompact(_G["CompactRaidFrame" .. i]) end
    for g = 1, 8 do
        for m = 1, 5 do MarkCompact(_G["CompactRaidGroup" .. g .. "Member" .. m]) end
    end
end

local ticker = CreateFrame("Frame")
local elapsed = 0
ticker:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < INTERVAL then return end
    elapsed = 0
    if not (IsInGroup and IsInGroup()) and not next(texts) then return end
    pcall(MarkAll)
end)

-- /bnav distance
local function TogglePartyDistance()
    DB().partyDistance = not Enabled()
    pcall(MarkAll)
    return DB().partyDistance
end

-- /bnav distance test: what each check says for every group member
local function DistanceReport(print)
    local units = {}
    for i = 1, 4 do units[#units + 1] = "party" .. i end
    for _, u in ipairs(units) do
        local okE, exists = pcall(UnitExists, u)
        if okE and Plain(exists) == true then
            local okN, name = pcall(UnitName, u)
            name = (okN and Plain(name)) or u
            local yards = Yards(u)
            local s1, n1 = Band(u)
            local s2, n2 = GroupBand(u)
            local d = state.inInstance and ToEntrance(u)
            local out = not state.inInstance and "" or
                (", to entrance " .. (d == "far" and "other continent" or d and string.format("%.0f yd", d) or "unknown"))
            print(string.format("%s: position %s, items %s, group check %s%s", name,
                yards and string.format("%.1f yd", yards) or "hidden",
                s1 and (s1 .. " " .. n1 .. " yd") or ((InCombatLockdown and InCombatLockdown()) and "skipped (combat)" or "no answer"),
                s2 and (s2 .. " " .. n2 .. " yd") or "no answer", out))
        end
    end
end

-- /bnav distance [test]
ns.AddCommand({ "distance", "dist" }, function(rest)
    if rest:lower() == "test" then
        DistanceReport(ns.Print)
    else
        ns.Print("Distance under party/raid frames " .. (TogglePartyDistance() and "on" or "off") .. ".")
    end
end, {
    "  /bnav distance        how far each group member is, under their frame (on/off; 'test' shows every check)",
})

-- shared with the other BossNav files
