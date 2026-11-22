-- Diagnostics: when the client blocks a call from this addon, say where.
--
-- The client often names the blocked call only as "UNKNOWN()", which tells
-- nothing. The event arrives while the blocked code is still running, so the
-- call stack at that moment holds the BossNav file and line that caused it.
-- Each place is reported once per session, so combat does not flood chat.
local ADDON, ns = ...
-- from the files loaded before this one
local Print                  = ns.Print

local reported = {}   -- "file:line" -> true once printed

-- the first BossNav file:line on the stack that is not this file
local function Culprit()
    if not debugstack then return nil end
    local ok, stack = pcall(debugstack, 2, 40, 0)
    if not ok or type(stack) ~= "string" then return nil end
    for line in stack:gmatch("[^\n]+") do
        local file, num = line:match("BossNav[/\\](.-%.lua)%]?:(%d+)")
        if file and not file:find("BlockReport", 1, true) then
            return file .. ":" .. num
        end
    end
    return nil
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:SetScript("OnEvent", function(_, _, addon, call)
    if addon ~= ADDON then return end
    local where = Culprit() or "unknown place"
    local key = where .. " " .. tostring(call)
    if reported[key] then return end
    reported[key] = true
    Print("|cffff4444the client blocked this call:|r " .. tostring(call) ..
        " at " .. where .. "  (please report this line)")
end)
