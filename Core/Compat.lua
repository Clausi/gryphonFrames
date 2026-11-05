local _, ns = ...

-- Client differences (Forever, Classic Era, Anniversary). Every check for a client difference
-- lives here and detects the API or frame field it needs, instead of comparing version numbers.
local Compat = {}
ns.Compat = Compat

-- Forever uses the Mainline target frame: its auras sit in an aura container, and
-- TargetSpellBarMixin:AdjustPosition() (Blizzard_UnitFrame/Mainline/TargetFrame.lua) may anchor the
-- cast bar to it. Classic Era and Anniversary use the Classic target frame
-- (Blizzard_UnitFrame/Classic/TargetFrame.lua), which has no aura container.
local hasAuraContainer = TargetFrame and TargetFrame.GetAuraContainer ~= nil

-- Forever has the combo point atlases of the Mainline UI (Blizzard_UnitFrame/Mainline/
-- RogueComboPoint.xml). Classic Era and Anniversary do not have them (checked in-game); they only
-- have the texture of the Classic ComboFrame (Blizzard_UnitFrame/Classic/ComboFrame.xml), which
-- Forever's code no longer uses.
local hasComboPointAtlas = C_Texture.GetAtlasInfo("uf-roguecp-icon-red") ~= nil

-- False on Forever: in combat, power values are secret and C_UnitAuras refuses to list auras for
-- addon code, so PlayerBuffs and PlayerPowerTicks would show next to nothing there and are turned
-- off. The Mainline target frame marks Forever, the only supported client with the restrictions:
-- their API exists in the docs of all three clients, so it cannot tell them apart.
function Compat.CanReadValuesInCombat()
    return not hasAuraContainer
end

-- Default style of the nameplate combo points: what the client's own combo points look like.
ns.charDefaults.nameplateComboPointsStyle = hasComboPointAtlas and "modern" or "classic"

-- True if the value is a secret value. Clients without secret values have no issecretvalue.
function Compat.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

-- True if the value is a table whose fields addon code may read. Clients without secret values have
-- no canaccesstable.
function Compat.IsReadableTable(value)
    if Compat.IsSecret(value) or type(value) ~= "table" then
        return false
    end
    return canaccesstable == nil or canaccesstable(value)
end

-- Returns true and the aura data (nil past the last aura), or false if the client refuses to hand
-- it out. During addon restrictions on Forever, C_UnitAuras.GetAuraDataByIndex() may return secret
-- fields or raise "Auras cannot be accessed when secret" for addon code. The API docs do not say
-- when it does which (RequiresUnitAuraAccess), and C_Secrets.ShouldAurasBeSecret() cannot tell the
-- two apart, so the call is protected instead of checked up front.
function Compat.TryGetAuraDataByIndex(unit, index, filter)
    return pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
end

-- Calls callback when an addon restriction starts or ends; it fires after a restriction ended.
function Compat.OnAddOnRestrictionChanged(callback)
    if C_EventUtils.IsEventValid("ADDON_RESTRICTION_STATE_CHANGED") then
        ns:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", callback)
    end
end

-- Stack count of an aura as text, empty below 2 stacks. A secret count (combat restrictions)
-- cannot be compared: C_UnitAuras.GetAuraApplicationDisplayCount() formats it in the client. In
-- the API docs of all three clients; without it, the secret count is shown as it is. Like most aura
-- functions, it takes no secret arguments from addon code (SecretArguments "AllowedWhenUntainted").
function Compat.GetAuraStackText(unit, auraData)
    local applications = auraData.applications
    if not Compat.IsSecret(applications) then
        return applications > 1 and applications or ""
    end
    if C_UnitAuras.GetAuraApplicationDisplayCount and not Compat.IsSecret(auraData.auraInstanceID) then
        return C_UnitAuras.GetAuraApplicationDisplayCount(unit, auraData.auraInstanceID, 2)
    end
    return applications
end

-- A duration text binding (C_DurationUtil) lets the client update a font string with the
-- remaining time of a duration object, also when the time is secret. The aura container of the
-- Mainline UI uses it the same way (Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua). In the
-- API docs of all three clients and checked in-game on Classic, the Classic UI itself does not use
-- it.
local hasDurationTextBinding = C_DurationUtil ~= nil and C_DurationUtil.CreateDurationTextBinding ~= nil
    and C_StringUtil ~= nil and C_StringUtil.CreateSecondsFormatter ~= nil
    and C_UnitAuras.GetAuraDuration ~= nil
local durationBindings = {}
local durationFormatter

-- Formats like the aura buttons of the Mainline UI (Blizzard_AuraContainerShared.lua): one unit
-- with a one letter abbreviation, e.g. "5m", the last unit rounded up. Not every client has all
-- enums of the API docs (Anniversary has no Enum.SecondsFormatterRounding, checked in-game), so an
-- option is only set if its enum and method exist.
local function SetFormatterOption(formatter, method, enumName, valueName)
    local enum = Enum[enumName]
    if enum and enum[valueName] ~= nil and formatter[method] then
        formatter[method](formatter, enum[valueName])
    end
end

local function GetDurationFormatter()
    if not durationFormatter then
        durationFormatter = C_StringUtil.CreateSecondsFormatter()
        SetFormatterOption(durationFormatter, "SetDefaultAbbreviation", "SecondsFormatterAbbreviation", "OneLetter")
        SetFormatterOption(durationFormatter, "SetRounding", "SecondsFormatterRounding", "Truncate")
        SetFormatterOption(durationFormatter, "SetMinInterval", "SecondsFormatterInterval", "Seconds")
        if durationFormatter.SetCanRoundUpLastUnit then
            durationFormatter:SetCanRoundUpLastUnit(true)
        end
        if durationFormatter.SetDesiredUnitCount then
            durationFormatter:SetDesiredUnitCount(1)
        end
    end
    return durationFormatter
end

-- Lets the client show the remaining time of the aura in the font string and keep it up to date.
-- Without an auraInstanceID, it stops updating the font string. Returns false if the client
-- cannot do it.
function Compat.SetAuraDurationText(fontString, unit, auraInstanceID)
    local binding = durationBindings[fontString]
    if not auraInstanceID then
        if binding then
            binding:SetEnabled(false)
        end
        return false
    end
    if not hasDurationTextBinding or Compat.IsSecret(auraInstanceID) then
        return false
    end
    if not binding then
        binding = C_DurationUtil.CreateDurationTextBinding()
        binding:SetFontString(fontString)
        binding:SetFormatter(GetDurationFormatter())
        -- Buffs without a duration have a zero duration.
        binding:SetZeroDurationText("")
        binding:SetExpiredText("")
        durationBindings[fontString] = binding
    end
    binding:SetDuration(C_UnitAuras.GetAuraDuration(unit, auraInstanceID))
    binding:SetEnabled(true)
    return true
end

-- Forever builds tooltips from tooltip data (Blizzard_GameTooltip/Mainline/GameTooltip.lua,
-- GameTooltipDataMixin) and calls the post calls of TooltipDataProcessor with it. The Classic
-- GameTooltip (Blizzard_GameTooltip/Classic/GameTooltip.lua) has no tooltip data: it fires the
-- scripts OnTooltipSetSpell and OnTooltipSetItem, and nothing for auras.
local hasTooltipData = TooltipDataProcessor ~= nil and GameTooltip.ProcessInfo ~= nil

-- Tooltips the Classic hooks are added to. ItemRefTooltip shows links clicked in chat.
local CLASSIC_TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }
-- Classic methods that show an aura by index, with the filter they add to the filter argument
-- (SetUnitAura takes the full filter).
local CLASSIC_AURA_INDEX_METHODS = {
    SetUnitAura = false,
    SetUnitBuff = "HELPFUL",
    SetUnitDebuff = "HARMFUL",
}
-- Classic methods that show an aura by its aura instance ID.
local CLASSIC_AURA_INSTANCE_METHODS = {
    "SetUnitAuraByAuraInstanceID",
    "SetUnitBuffByAuraInstanceID",
    "SetUnitDebuffByAuraInstanceID",
}

local function GetAuraFilter(methodFilter, filter)
    if not methodFilter then
        return filter
    end
    return filter and filter ~= "" and methodFilter .. "|" .. filter or methodFilter
end

-- Calls callback(tooltip, kind, value) after a tooltip shows a spell, an aura, an item or a unit.
-- kind is "spell" (also for auras) or "item" with the ID, or "unit" with the unit's GUID. The
-- callback may add lines; the tooltip is resized after it.
function Compat.HookTooltipIds(callback)
    if hasTooltipData then
        local function Hook(kind, field)
            return function(tooltip, tooltipData)
                local value = tooltipData and tooltipData[field]
                if value then
                    callback(tooltip, kind, value)
                end
            end
        end
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, Hook("spell", "id"))
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, Hook("spell", "id"))
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, Hook("item", "id"))
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, Hook("unit", "guid"))
        return
    end

    -- Units are only shown in GameTooltip.
    GameTooltip:HookScript("OnTooltipSetUnit", function(self)
        local _, unit = self:GetUnit()
        local guid = unit and UnitGUID(unit)
        if guid then
            callback(self, "unit", guid)
        end
    end)

    for _, name in ipairs(CLASSIC_TOOLTIPS) do
        local tooltip = _G[name]
        if tooltip then
            tooltip:HookScript("OnTooltipSetSpell", function(self)
                local _, spellId = self:GetSpell()
                if spellId then
                    callback(self, "spell", spellId)
                end
            end)
            tooltip:HookScript("OnTooltipSetItem", function(self)
                local _, link = self:GetItem()
                local itemId = link and tonumber(link:match("item:(%d+)"))
                if itemId then
                    callback(self, "item", itemId)
                end
            end)
        end
    end
    -- Lines added after the tooltip was shown need a Show() to resize it.
    local function OnAura(tooltip, auraData)
        if auraData and auraData.spellId then
            callback(tooltip, "spell", auraData.spellId)
            tooltip:Show()
        end
    end
    for method, methodFilter in pairs(CLASSIC_AURA_INDEX_METHODS) do
        if GameTooltip[method] then
            hooksecurefunc(GameTooltip, method, function(self, unit, index, filter)
                OnAura(self, C_UnitAuras.GetAuraDataByIndex(unit, index, GetAuraFilter(methodFilter, filter)))
            end)
        end
    end
    for _, method in ipairs(CLASSIC_AURA_INSTANCE_METHODS) do
        if GameTooltip[method] then
            hooksecurefunc(GameTooltip, method, function(self, unit, auraInstanceID)
                OnAura(self, C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID))
            end)
        end
    end
end

-- Offset of the target cast bar's TOPLEFT from the target frame's BOTTOMLEFT, where Blizzard puts
-- it while the target has no extra aura rows below the frame. Mirrors the non-aura branches of
-- TargetSpellBarMixin:AdjustPosition(), so the values must follow Blizzard's code.
function Compat.GetTargetSpellBarOffset(spellBar)
    if hasAuraContainer then
        local x = TargetFrame.smallSize and 38 or 43
        local y = TargetFrame.smallSize and 3 or 5
        if TargetFrame.haveToT then
            y = TargetFrame.smallSize and -48 or -46
        end
        return x, y
    end

    local x = 43 + (spellBar.xOffset or 0)
    local y = 3
    if TargetFrame.haveToT then
        y = -25
    elseif TargetFrame.haveElite then
        y = -9
    end
    return x, y
end

-- True if the client has Blizzard's modern combo point art (Forever). Without it, the modern style
-- of the nameplate combo points is drawn from plain shapes.
function Compat.HasModernComboPointArt()
    return hasComboPointAtlas
end

-- Hands the target cast bar back to Blizzard's anchoring after the addon had anchored it.
function Compat.ReleaseTargetSpellBar(spellBar)
    if hasAuraContainer then
        -- AdjustPosition() is not called here: run from addon code it could taint the aura layout
        -- it reads. It clears the points itself and runs again on the next show of the bar. The
        -- shown state of the bar may be secret, like its size.
        local shown = spellBar:IsShown()
        if not Compat.IsSecret(shown) and not shown then
            spellBar:ClearAllPoints()
        end
        return
    end

    -- The Classic AdjustPosition() only adds its TOPLEFT point without clearing the addon's point,
    -- so the points are cleared here and Blizzard's anchoring is restored right away. It reads no
    -- secret values and only sets the points of the bar.
    spellBar:ClearAllPoints()
    spellBar:AdjustPosition()
end
