-- Hides the rows that fail the role filter in the Looking For Group window.
-- The window sorts its result list through a global helper before drawing it;
-- a hook on that helper drops the unwanted listings from the list in place.
-- The helper's name differs between client styles, so every known one is tried,
-- also when the group finder addon loads later (it is load-on-demand).
local ADDON, ns = ...
-- from the files loaded before this one
local LFGMatches             = ns.LFGMatches
local LFGRoleWanted          = ns.LFGRoleWanted
local Print                  = ns.Print

local SORTERS = {
    "LFGBrowseUtil_SortSearchResults",   -- classic-style Looking For Group window
    "LFGListUtil_SortSearchResults",     -- retail-style Premade Groups window
}
local hooked = {}

local function DropHidden(results)
    if type(results) ~= "table" or not LFGRoleWanted() then return end
    for i = #results, 1, -1 do
        if not LFGMatches(results[i]) then table.remove(results, i) end
    end
end

local function TryHook()
    for _, fn in ipairs(SORTERS) do
        if not hooked[fn] and type(_G[fn]) == "function" then
            hooksecurefunc(fn, DropHidden)
            hooked[fn] = true
        end
    end
end

-- redraw an open window after the filter changed
local function RefreshLFGWindow()
    local browse = _G.LFGBrowseFrame
    if browse and browse:IsShown() then
        for _, method in ipairs({ "UpdateResultList", "UpdateResults" }) do
            if type(browse[method]) == "function" then pcall(browse[method], browse) end
        end
    end
    local panel = _G.LFGListFrame and _G.LFGListFrame.SearchPanel
    if panel and panel:IsShown() and _G.LFGListSearchPanel_UpdateResultList then
        pcall(_G.LFGListSearchPanel_UpdateResultList, panel)
        pcall(_G.LFGListSearchPanel_UpdateResults, panel)
    end
end

-- /bnav lfg window: which hook took, plus candidate names if none did
local function LFGWindowReport()
    TryHook()
    local checksHost = ns.LFGChecksHost and ns.LFGChecksHost()
    Print("Checkboxes attached to: " .. tostring(checksHost or "no window found"))
    local names = {}
    for fn in pairs(hooked) do names[#names + 1] = fn end
    if #names > 0 then
        Print("Window filter hooked: " .. table.concat(names, ", "))
        return
    end
    local found = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "function" and k:find("LFG") and k:find("Sort") then
            found[#found + 1] = k
        end
    end
    table.sort(found)
    Print("Window filter not hooked. Sort functions seen: " ..
        (#found > 0 and table.concat(found, ", ") or "none (open the Looking For Group window first)"))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", TryHook)

-- shared with the other BossNav files
ns.LFGWindowReport = LFGWindowReport
ns.RefreshLFGWindow = RefreshLFGWindow
