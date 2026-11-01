local addonName, ns = ...

-- Shared addon namespace. All files receive the same `ns` table via `...`.
ns.name = addonName
ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version")
ns.modules = {}

-- Default values for the saved variables. Missing keys are filled in on load.
-- Account-wide (GryphonFramesDB, ns.db): settings and data shared by all characters.
ns.defaults = {
    debug = false,
    -- Target cast bar positions per Edit Mode layout. Filled by Modules/TargetCastBar.lua.
    targetCastBar = {
        layouts = {},
    },
}

-- Per character (GryphonFramesCharDB, ns.charDb): data and settings only the logged-in character needs.
ns.charDefaults = {
    -- Automatic chat messages (login, hints). Change with "/gryphonframes chat on|off".
    chatMessages = true,
    -- Combo points on the target's nameplate (Modules/NameplateComboPoints.lua). Change with
    -- "/gryphonframes combo on|off".
    nameplateComboPoints = false,
    -- Size of the combo points on the nameplate (scale, 1 = Blizzard's combo point size).
    nameplateComboPointsScale = 1,
    -- "above" the name or "below" the nameplate.
    nameplateComboPointsPosition = "above",
    -- Gap in pixels to the name or the cast bar area.
    nameplateComboPointsGap = 2,
    -- Horizontal position in percent of the free space: -100 left, 0 centered, 100 right.
    nameplateComboPointsOffsetX = 0,
    -- nameplateComboPointsStyle ("modern" or "classic") depends on the client, see Core/Compat.lua.
    -- Energy and mana ticks on the power bar of the player frame (Modules/PlayerPowerTicks.lua).
    -- Change with "/gryphonframes energy on|off" and "/gryphonframes mana on|off".
    playerEnergyTicks = false,
    -- Mana ticks include the five second rule after a mana spend.
    playerManaTicks = false,
}

-- Registers a module. A module may implement:
--   module:OnInitialize()  -- called once after saved variables are loaded
--   module:OnEnable()      -- called on PLAYER_LOGIN
function ns:RegisterModule(name)
    local module = { name = name }
    self.modules[#self.modules + 1] = module
    self.modules[name] = module
    return module
end

-- Registers a "/gryphonframes <name> ..." subcommand.
--   handler(args)  -- args: the rest of the input after the command name, trimmed
--   helpLines      -- user-facing help lines (already localized), shown by "/gryphonframes"
ns.commands = {}

function ns:RegisterCommand(name, handler, helpLines)
    local command = { name = name, handler = handler, helpLines = helpLines or {} }
    self.commands[#self.commands + 1] = command
    self.commands[name] = command
end

-- Simple event dispatcher: ns:RegisterEvent("EVENT", function(event, ...) end)
local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handlers = eventHandlers[event]
    if not handlers then
        return
    end
    for i = 1, #handlers do
        handlers[i](event, ...)
    end
end)

function ns:RegisterEvent(event, handler)
    if not eventHandlers[event] then
        eventHandlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(eventHandlers[event], handler)
end

-- Unit events for one unit only: ns:RegisterUnitEvent("UNIT_EVENT", "player", function(event, ...) end)
-- The game filters by unit (RegisterUnitEvent), so the handler does not run for the events of
-- other units (group, raid, nameplates). One frame per unit, because RegisterUnitEvent replaces
-- the unit filter of an event registered on the same frame before.
local unitEventFrames = {}

function ns:RegisterUnitEvent(event, unit, handler)
    local unitFrame = unitEventFrames[unit]
    if not unitFrame then
        unitFrame = CreateFrame("Frame")
        unitFrame.handlers = {}
        unitFrame:SetScript("OnEvent", function(frame, unitEvent, ...)
            local handlers = frame.handlers[unitEvent]
            for i = 1, #handlers do
                handlers[i](unitEvent, ...)
            end
        end)
        unitEventFrames[unit] = unitFrame
    end
    if not unitFrame.handlers[event] then
        unitFrame.handlers[event] = {}
        unitFrame:RegisterUnitEvent(event, unit)
    end
    table.insert(unitFrame.handlers[event], handler)
end
