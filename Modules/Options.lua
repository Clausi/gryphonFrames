local _, ns = ...
local L = ns.L
local Options = ns:RegisterModule("Options")

-- Options page in Blizzard's settings (Esc > Options > AddOns > GryphonFrames) as a vertical list,
-- with subcategories for everything on unit frames and on nameplates. The settings stay in ns.db and ns.charDb; proxy
-- settings read and write them there.

local category

-- Proxy setting variables must be unique among all settings of the game and addons.
local function RegisterProxySetting(settingsCategory, variable, varType, name, defaultValue, getValue,
                                    setValue)
    return Settings.RegisterProxySetting(settingsCategory, "GRYPHONFRAMES_" .. variable, varType, name,
        defaultValue, getValue, setValue)
end

-- Combo points on the target's nameplate (Modules/NameplateComboPoints.lua).
local function RegisterComboPoints(nameplates)
    local NameplateComboPoints = ns.modules.NameplateComboPoints
    local layout = SettingsPanel:GetLayout(nameplates)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["OPTIONS_COMBO_HEADER"]))

    local enabled = RegisterProxySetting(nameplates, "COMBO_POINTS", Settings.VarType.Boolean,
        L["OPTIONS_COMBO"], ns.charDefaults.nameplateComboPoints,
        function()
            return NameplateComboPoints:IsEnabled()
        end,
        function(value)
            NameplateComboPoints:SetEnabled(value)
        end)
    Settings.CreateCheckbox(nameplates, enabled, L["OPTIONS_COMBO_TOOLTIP"])

    local style = RegisterProxySetting(nameplates, "COMBO_POINTS_STYLE", Settings.VarType.String,
        L["OPTIONS_COMBO_STYLE"], ns.charDefaults.nameplateComboPointsStyle,
        function()
            return NameplateComboPoints:GetStyle()
        end,
        function(value)
            NameplateComboPoints:SetStyle(value)
        end)
    local function GetStyleOptions()
        local container = Settings.CreateControlTextContainer()
        for _, value in ipairs(NameplateComboPoints.STYLES) do
            container:Add(value, L["OPTIONS_COMBO_STYLE_" .. value:upper()])
        end
        return container:GetData()
    end
    Settings.CreateDropdown(nameplates, style, GetStyleOptions, L["OPTIONS_COMBO_STYLE_TOOLTIP"])

    local scale = RegisterProxySetting(nameplates, "COMBO_POINTS_SCALE", Settings.VarType.Number,
        L["OPTIONS_COMBO_SCALE"], ns.charDefaults.nameplateComboPointsScale,
        function()
            return NameplateComboPoints:GetScale()
        end,
        function(value)
            -- The slider moves in steps of 0.1, but its values may carry rounding errors.
            NameplateComboPoints:SetScale(floor(value * 10 + 0.5) / 10)
        end)
    local sliderOptions = Settings.CreateSliderOptions(NameplateComboPoints.MIN_SCALE,
        NameplateComboPoints.MAX_SCALE, NameplateComboPoints.SCALE_STEP)
    sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return format("%d%%", floor(value * 100 + 0.5))
    end)
    Settings.CreateSlider(nameplates, scale, sliderOptions, L["OPTIONS_COMBO_SCALE_TOOLTIP"])

    local position = RegisterProxySetting(nameplates, "COMBO_POINTS_POSITION", Settings.VarType.String,
        L["OPTIONS_COMBO_POSITION"], ns.charDefaults.nameplateComboPointsPosition,
        function()
            return NameplateComboPoints:GetPosition()
        end,
        function(value)
            NameplateComboPoints:SetPosition(value)
        end)
    local function GetPositionOptions()
        local container = Settings.CreateControlTextContainer()
        for _, value in ipairs(NameplateComboPoints.POSITIONS) do
            container:Add(value, L["OPTIONS_COMBO_POSITION_" .. value:upper()])
        end
        return container:GetData()
    end
    Settings.CreateDropdown(nameplates, position, GetPositionOptions, L["OPTIONS_COMBO_POSITION_TOOLTIP"])

    local gap = RegisterProxySetting(nameplates, "COMBO_POINTS_GAP", Settings.VarType.Number,
        L["OPTIONS_COMBO_GAP"], ns.charDefaults.nameplateComboPointsGap,
        function()
            return NameplateComboPoints:GetGap()
        end,
        function(value)
            NameplateComboPoints:SetGap(floor(value + 0.5))
        end)
    local gapOptions = Settings.CreateSliderOptions(NameplateComboPoints.MIN_GAP, NameplateComboPoints.MAX_GAP, 1)
    gapOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    Settings.CreateSlider(nameplates, gap, gapOptions, L["OPTIONS_COMBO_GAP_TOOLTIP"])

    local offsetX = RegisterProxySetting(nameplates, "COMBO_POINTS_OFFSET_X", Settings.VarType.Number,
        L["OPTIONS_COMBO_OFFSET_X"], ns.charDefaults.nameplateComboPointsOffsetX,
        function()
            return NameplateComboPoints:GetOffsetX()
        end,
        function(value)
            NameplateComboPoints:SetOffsetX(floor(value + 0.5))
        end)
    local offsetOptions = Settings.CreateSliderOptions(NameplateComboPoints.MIN_OFFSET_X,
        NameplateComboPoints.MAX_OFFSET_X, 5)
    offsetOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return format("%d%%", floor(value + 0.5))
    end)
    Settings.CreateSlider(nameplates, offsetX, offsetOptions, L["OPTIONS_COMBO_OFFSET_X_TOOLTIP"])
end

-- Energy and mana ticks on the player frame (Modules/PlayerPowerTicks.lua).
local function RegisterPowerTicks(unitFrames)
    local PlayerPowerTicks = ns.modules.PlayerPowerTicks
    local layout = SettingsPanel:GetLayout(unitFrames)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["OPTIONS_PLAYER_FRAME_HEADER"]))

    local energy = RegisterProxySetting(unitFrames, "ENERGY_TICKS", Settings.VarType.Boolean,
        L["OPTIONS_ENERGY_TICKS"], ns.charDefaults.playerEnergyTicks,
        function()
            return PlayerPowerTicks:IsEnergyEnabled()
        end,
        function(value)
            PlayerPowerTicks:SetEnergyEnabled(value)
        end)
    Settings.CreateCheckbox(unitFrames, energy, L["OPTIONS_ENERGY_TICKS_TOOLTIP"])

    local mana = RegisterProxySetting(unitFrames, "MANA_TICKS", Settings.VarType.Boolean,
        L["OPTIONS_MANA_TICKS"], ns.charDefaults.playerManaTicks,
        function()
            return PlayerPowerTicks:IsManaEnabled()
        end,
        function(value)
            PlayerPowerTicks:SetManaEnabled(value)
        end)
    Settings.CreateCheckbox(unitFrames, mana, L["OPTIONS_MANA_TICKS_TOOLTIP"])
end

-- Own buffs at the player frame (Modules/PlayerBuffs.lua). Position and size are in Edit Mode.
local function RegisterPlayerBuffs(unitFrames)
    local PlayerBuffs = ns.modules.PlayerBuffs
    local enabled = RegisterProxySetting(unitFrames, "PLAYER_BUFFS", Settings.VarType.Boolean,
        L["OPTIONS_PLAYER_BUFFS"], ns.charDefaults.playerBuffs,
        function()
            return PlayerBuffs:IsEnabled()
        end,
        function(value)
            PlayerBuffs:SetEnabled(value)
        end)
    Settings.CreateCheckbox(unitFrames, enabled, L["OPTIONS_PLAYER_BUFFS_TOOLTIP"])

    local maxDuration = RegisterProxySetting(unitFrames, "PLAYER_BUFFS_MAX_DURATION", Settings.VarType.Number,
        L["OPTIONS_PLAYER_BUFFS_MAX_DURATION"], ns.charDefaults.playerBuffsMaxDuration,
        function()
            return PlayerBuffs:GetMaxDuration()
        end,
        function(value)
            PlayerBuffs:SetMaxDuration(value)
        end)
    local function GetMaxDurationOptions()
        local container = Settings.CreateControlTextContainer()
        for _, seconds in ipairs(PlayerBuffs.MAX_DURATIONS) do
            local text
            if seconds == 0 then
                text = L["OPTIONS_PLAYER_BUFFS_MAX_DURATION_NONE"]
            elseif seconds == 60 then
                text = L["OPTIONS_PLAYER_BUFFS_MINUTE"]
            elseif seconds < 60 then
                text = format(L["OPTIONS_PLAYER_BUFFS_SECONDS"], seconds)
            else
                text = format(L["OPTIONS_PLAYER_BUFFS_MINUTES"], seconds / 60)
            end
            container:Add(seconds, text)
        end
        return container:GetData()
    end
    Settings.CreateDropdown(unitFrames, maxDuration, GetMaxDurationOptions,
        L["OPTIONS_PLAYER_BUFFS_MAX_DURATION_TOOLTIP"])

    local hidePermanent = RegisterProxySetting(unitFrames, "PLAYER_BUFFS_HIDE_PERMANENT", Settings.VarType.Boolean,
        L["OPTIONS_PLAYER_BUFFS_HIDE_PERMANENT"], ns.charDefaults.playerBuffsHidePermanent,
        function()
            return PlayerBuffs:IsHidingPermanent()
        end,
        function(value)
            PlayerBuffs:SetHidingPermanent(value)
        end)
    Settings.CreateCheckbox(unitFrames, hidePermanent, L["OPTIONS_PLAYER_BUFFS_HIDE_PERMANENT_TOOLTIP"])

    local whitelistOnly = RegisterProxySetting(unitFrames, "PLAYER_BUFFS_WHITELIST_ONLY", Settings.VarType.Boolean,
        L["OPTIONS_PLAYER_BUFFS_WHITELIST_ONLY"], ns.charDefaults.playerBuffsWhitelistOnly,
        function()
            return PlayerBuffs:IsWhitelistOnly()
        end,
        function(value)
            PlayerBuffs:SetWhitelistOnly(value)
        end)
    Settings.CreateCheckbox(unitFrames, whitelistOnly, L["OPTIONS_PLAYER_BUFFS_WHITELIST_ONLY_TOOLTIP"])

    -- The lists are edited in ns.ListEditor, one spell ID or aura name per line.
    local layout = SettingsPanel:GetLayout(unitFrames)
    -- No search tags (addSearchTags = false): tags added from addon code taint the initializer,
    -- and the settings search carries that taint on to its results. On Forever, showing a Discord
    -- row there then calls the protected C_Discord.IsUserOAuthed.
    for _, kind in ipairs({ "whitelist", "blacklist" }) do
        local key = "OPTIONS_PLAYER_BUFFS_" .. kind:upper()
        layout:AddInitializer(CreateSettingsButtonInitializer(L[key], L["OPTIONS_PLAYER_BUFFS_EDIT"], function()
            ns.ListEditor:Open(L[key], L[key .. "_DESC"], PlayerBuffs:GetList(kind), function(entries)
                PlayerBuffs:SetList(kind, entries)
            end)
        end, L[key .. "_TOOLTIP"], false))
    end
end

-- Spell, item and NPC IDs in tooltips (Modules/TooltipIds.lua).
local function RegisterTooltipIds(tooltips)
    local TooltipIds = ns.modules.TooltipIds
    local kinds = {
        { kind = "spell", default = ns.charDefaults.tooltipSpellIds },
        { kind = "item", default = ns.charDefaults.tooltipItemIds },
        { kind = "npc", default = ns.charDefaults.tooltipNpcIds },
    }
    for _, entry in ipairs(kinds) do
        local kind = entry.kind
        local key = kind:upper() .. "_IDS"
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

    -- Subcategories for all options of the nameplates, tooltips and unit frames; each feature is a
    -- section in one of them. They are listed in the order they are registered: alphabetical by
    -- their English names, in every language.
    local nameplates = Settings.RegisterVerticalLayoutSubcategory(category, L["OPTIONS_NAMEPLATES"])
    RegisterComboPoints(nameplates)

    local tooltips = Settings.RegisterVerticalLayoutSubcategory(category, L["OPTIONS_TOOLTIPS"])
    RegisterTooltipIds(tooltips)

    local unitFrames = Settings.RegisterVerticalLayoutSubcategory(category, L["OPTIONS_UNIT_FRAMES"])
    -- The "Player Frame" section starts in RegisterPowerTicks().
    RegisterPowerTicks(unitFrames)
    RegisterPlayerBuffs(unitFrames)
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
