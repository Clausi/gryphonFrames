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

-- Default style of the nameplate combo points: what the client's own combo points look like.
ns.charDefaults.nameplateComboPointsStyle = hasComboPointAtlas and "modern" or "classic"

-- True if the value is a secret value. Clients without secret values have no issecretvalue.
function Compat.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
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
