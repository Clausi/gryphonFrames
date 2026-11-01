local addonName, ns = ...
local L = ns.L

ns:RegisterEvent("ADDON_LOADED", function(_, loadedName)
    if loadedName ~= addonName then
        return
    end

    GryphonFramesDB = ns.ApplyDefaults(GryphonFramesDB or {}, ns.defaults)
    ns.db = GryphonFramesDB
    GryphonFramesCharDB = ns.ApplyDefaults(GryphonFramesCharDB or {}, ns.charDefaults)
    ns.charDb = GryphonFramesCharDB

    -- Debug mode breaks the memory down: loaded files and saved variables, then each module.
    ns:DebugMemory("after loading files")
    for _, module in ipairs(ns.modules) do
        if module.OnInitialize then
            ns:MeasureMemory(module.name .. ":OnInitialize", module.OnInitialize, module)
        end
    end
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
    for _, module in ipairs(ns.modules) do
        if module.OnEnable then
            ns:MeasureMemory(module.name .. ":OnEnable", module.OnEnable, module)
        end
    end

    ns:Notify(L["ADDON_LOADED"], ns.version or "?")
end)

-- Slash commands
ns:RegisterCommand("version", function()
    ns:Print(ns.version or "?")
end, { L["HELP_VERSION"] })

ns:RegisterCommand("debug", function()
    ns.db.debug = not ns.db.debug
    ns:Print(ns.db.debug and L["DEBUG_ON"] or L["DEBUG_OFF"])
end, { L["HELP_DEBUG"] })

-- "/gryphonframes chat on|off" sets the automatic chat messages, without argument shows the setting.
ns:RegisterCommand("chat", function(args)
    local value = args:lower()
    if value == "on" then
        ns.charDb.chatMessages = true
    elseif value == "off" then
        ns.charDb.chatMessages = false
    elseif value ~= "" then
        ns:Print(L["HELP_CHAT"])
        return
    end
    ns:Print(ns.charDb.chatMessages and L["CHAT_ON"] or L["CHAT_OFF"])
end, { L["HELP_CHAT"] })

local function PrintHelp()
    ns:Print(L["HELP_HEADER"])
    for _, command in ipairs(ns.commands) do
        for _, line in ipairs(command.helpLines) do
            ns:Print(line)
        end
    end
end

SLASH_GRYPHONFRAMES1 = "/gryphonframes"
SlashCmdList["GRYPHONFRAMES"] = function(input)
    local name, args = strtrim(input or ""):match("^(%S*)%s*(.-)$")
    local command = ns.commands[name:lower()]

    if command then
        command.handler(args)
    else
        PrintHelp()
    end
end
