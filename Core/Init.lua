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
