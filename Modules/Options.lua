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

    -- Subcategories for all options of the unit frames and of the nameplates; each feature is a
    -- section in one of them. They are listed in the order they are registered: alphabetical by
    -- their English names, in every language.
    local nameplates = Settings.RegisterVerticalLayoutSubcategory(category, L["OPTIONS_NAMEPLATES"])
    RegisterComboPoints(nameplates)

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
