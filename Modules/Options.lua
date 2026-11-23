local _, ns = ...
local L = ns.L
local Options = ns:RegisterModule("Options")

-- Options page in Blizzard's settings (Esc > Options > AddOns > GryphonFrames) as a vertical list,
-- with subcategories for everything in tooltips and on unit frames. The settings stay in ns.db and ns.charDb; proxy
-- settings read and write them there.

local category

-- Proxy setting variables must be unique among all settings of the game and addons.
local function RegisterProxySetting(settingsCategory, variable, varType, name, defaultValue, getValue,
                                    setValue)
    return Settings.RegisterProxySetting(settingsCategory, "GRYPHONFRAMES_" .. variable, varType, name,
        defaultValue, getValue, setValue)
end

-- Five second rule on the player frame (Modules/PlayerPowerTicks.lua).
local function RegisterPowerTicks(unitFrames)
    local PlayerPowerTicks = ns.modules.PlayerPowerTicks
    local layout = SettingsPanel:GetLayout(unitFrames)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["OPTIONS_PLAYER_FRAME_HEADER"]))

    local mana = RegisterProxySetting(unitFrames, "MANA_TICKS", Settings.VarType.Boolean,
        L["OPTIONS_MANA_RULE"], ns.charDefaults.playerManaTicks,
        function()
            return PlayerPowerTicks:IsManaEnabled()
        end,
        function(value)
            PlayerPowerTicks:SetManaEnabled(value)
        end)
    Settings.CreateCheckbox(unitFrames, mana, L["OPTIONS_MANA_RULE_TOOLTIP"])
end

-- Spell IDs, item IDs, item levels and NPC IDs in tooltips (Modules/TooltipIds.lua).
local function RegisterTooltipIds(tooltips)
    local TooltipIds = ns.modules.TooltipIds
    local kinds = {
        { kind = "spell", key = "SPELL_IDS", default = ns.charDefaults.tooltipSpellIds },
        { kind = "item", key = "ITEM_IDS", default = ns.charDefaults.tooltipItemIds },
        { kind = "itemLevel", key = "ITEM_LEVEL", default = ns.charDefaults.tooltipItemLevel },
        { kind = "npc", key = "NPC_IDS", default = ns.charDefaults.tooltipNpcIds },
    }
    for _, entry in ipairs(kinds) do
        local kind = entry.kind
        local key = entry.key
        local enabled = RegisterProxySetting(tooltips, "TOOLTIP_" .. key, Settings.VarType.Boolean,
            L["OPTIONS_TOOLTIP_" .. key], entry.default,
            function()
                return TooltipIds:IsEnabled(kind)
            end,
            function(value)
                TooltipIds:SetEnabled(kind, value)
            end)
        Settings.CreateCheckbox(tooltips, enabled, L["OPTIONS_TOOLTIP_" .. key .. "_TOOLTIP"])
    end
end

local function RegisterSettings()
    local chatMessages = RegisterProxySetting(category, "CHAT_MESSAGES", Settings.VarType.Boolean,
        L["OPTIONS_CHAT_MESSAGES"], ns.charDefaults.chatMessages,
        function()
            return ns.charDb.chatMessages
        end,
        function(value)
            ns.charDb.chatMessages = value
        end)
    Settings.CreateCheckbox(category, chatMessages, L["OPTIONS_CHAT_MESSAGES_TOOLTIP"])

    -- Subcategories for all options of the tooltips and unit frames; each
    -- feature is a section in one of them. They are listed in the order they are registered:
    -- alphabetical by their English names, in every language.
    local tooltips = Settings.RegisterVerticalLayoutSubcategory(category, L["OPTIONS_TOOLTIPS"])
    RegisterTooltipIds(tooltips)

    local unitFrames = Settings.RegisterVerticalLayoutSubcategory(category, L["OPTIONS_UNIT_FRAMES"])
    RegisterPowerTicks(unitFrames)
end

function Options:OnInitialize()
    category = Settings.RegisterVerticalLayoutCategory(ns.name)
    RegisterSettings()
    Settings.RegisterAddOnCategory(category)
end

-- "/gryphonframes options" opens the options page. Opening it from addon code is blocked in combat
-- (ADDON_ACTION_BLOCKED for OpenSettingsPanel); Esc > Options still works there.
ns:RegisterCommand("options", function()
    if InCombatLockdown() then
        ns:Print(L["OPTIONS_IN_COMBAT"])
        return
    end
    Settings.OpenToCategory(category:GetID())
end, { L["HELP_OPTIONS"] })
