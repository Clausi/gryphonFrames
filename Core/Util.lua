local _, ns = ...

local PREFIX = "|cff33ccffGryphonFrames|r: "

-- Prints a message to the default chat frame with the addon prefix.
function ns:Print(message, ...)
    if select("#", ...) > 0 then
        message = message:format(...)
    end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(message))
end

-- Prints a message the addon shows on its own (not as the answer to a command). The user can turn
-- these off with "/gryphonframes chat off".
function ns:Notify(message, ...)
    if self.charDb and self.charDb.chatMessages then
        self:Print(message, ...)
    end
end

-- Prints only when debug mode is enabled in the saved variables.
function ns:Debug(message, ...)
    if self.db and self.db.debug then
        self:Print("|cff999999[debug]|r " .. tostring(message), ...)
    end
end

-- Memory the addon keeps (in KB) after a full garbage collection. Slow (collects garbage and scans
-- every addon), so it is only used in debug mode.
local function GetRetainedMemory()
    collectgarbage("collect")
    UpdateAddOnMemoryUsage()
    return GetAddOnMemoryUsage(ns.name)
end

-- Calls fn(...). In debug mode, also prints how much memory it retained afterwards.
function ns:MeasureMemory(label, fn, ...)
    if not (self.db and self.db.debug) then
        fn(...)
        return
    end
    local before = GetRetainedMemory()
    fn(...)
    local after = GetRetainedMemory()
    self:Debug("Memory %s: %+.1f KB (total %.1f KB)", label, after - before, after)
end

-- In debug mode, prints the memory the addon currently retains.
function ns:DebugMemory(label)
    if self.db and self.db.debug then
        self:Debug("Memory %s: %.1f KB", label, GetRetainedMemory())
    end
end

-- Sets up the menu of a DropdownButton that shows no selection text (fixed text or only an arrow),
-- so it only needs the menu while it is open. A generated menu takes ~80 KB even with 12 entries:
-- - SetupMenu builds the menu right away on a shown dropdown, so it runs while hidden. The menu is
--   generated anyway on every open (DropdownButtonMixin:OpenMenu).
-- - After closing, the generated description is released. Blizzard's code handles a nil description
--   (it is nil until the first open as well). Only used on own frames, so the write causes no taint.
function ns.SetupMenuOnDemand(dropdown, generator)
    local wasShown = dropdown:IsShown()
    dropdown:Hide()
    dropdown:SetupMenu(generator)
    dropdown:SetShown(wasShown)
    dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuClose, function()
        dropdown.menuDescription = nil
    end, dropdown)
end

-- Recursively copies missing default values into the target table.
function ns.ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ns.ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end
