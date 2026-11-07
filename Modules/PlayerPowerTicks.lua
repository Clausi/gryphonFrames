local _, ns = ...
local L = ns.L

-- Shows the five second rule on the mana bar of the player frame: after a spell that costs mana, a
-- red line runs from right to left in 5 seconds, the time without mana regeneration.
--
-- Power values are secret in combat, so spends cannot be seen. The module does not read power:
-- every successful cast of a spell that costs mana starts the rule. Free casts (Clearcasting) start
-- it as well, mana drained by enemies does not.
--
-- The line moves by a translation animation, so no Lua runs per frame. Lua only runs on spell casts
-- of the player, on form changes and when the setting changes.
--
-- Turned on per character in the options (Modules/Options.lua) or with "/gryphonframes mana on"
-- (ns.charDb.playerManaTicks).

local PlayerPowerTicks = ns:RegisterModule("PlayerPowerTicks")

local FIVE_SECOND_RULE = 5
local RULE_WIDTH = 2
local RULE_COLOR = { 1, 0.1, 0.1, 0.75 }

local spark, sparkFrame, animation, translation
-- Last readable size of the power bar.
local barWidth, barHeight

-- True if the setting is on and the player frame shows mana (not in druid forms).
local function IsActive()
    return ns.charDb.playerManaTicks and UnitPowerType("player") == Enum.PowerType.Mana
end

-- Frame sizes may be secret in combat. The size from before that is kept then; the power bar does
-- not change its size in combat.
local function UpdateBarSize(bar)
    local width, height = bar:GetWidth(), bar:GetHeight()
    if not issecretvalue(width) and not issecretvalue(height) then
        barWidth, barHeight = width, height
    end
end

local function Hide()
    if sparkFrame then
        animation:Stop()
        sparkFrame:Hide()
    end
end

-- Runs the line across the power bar from right to left. The width is read on each start, so a
-- changed power bar is picked up.
local function Play()
    local bar = PlayerFrame_GetManaBar()
    if not bar then
        return
    end
    UpdateBarSize(bar)
    if not barWidth then
        return
    end
    if sparkFrame:GetParent() ~= bar then
        sparkFrame:SetParent(bar)
        sparkFrame:SetAllPoints(bar)
    end
    sparkFrame:SetFrameLevel(bar:GetFrameLevel() + 2)
    animation:Stop()
    spark:SetSize(RULE_WIDTH, barHeight - 1)
    spark:ClearAllPoints()
    spark:SetPoint("CENTER", sparkFrame, "RIGHT")
    translation:SetDuration(FIVE_SECOND_RULE)
    translation:SetOffset(-barWidth, 0)
    sparkFrame:Show()
    animation:Play()
end

local function IsReadableTable(value)
    return not issecretvalue(value) and type(value) == "table" and canaccesstable(value)
end

-- True if the spell costs mana. The spell of a cast event may be a secret value
-- (SecretWhenUnitSpellCastRestricted), and C_Spell.GetSpellPowerCost() takes it from addon code. A
-- cost that cannot be read counts as mana, so the rule still starts: nearly every spell of a mana
-- user costs mana.
local function SpellCostsMana(spellId)
    local costs = C_Spell.GetSpellPowerCost(spellId)
    if not issecretvalue(costs) and not costs then
        return false
    end
    if not IsReadableTable(costs) then
        return true
    end
    for _, cost in ipairs(costs) do
        if not IsReadableTable(cost) or issecretvalue(cost.type) or issecretvalue(cost.cost)
                or issecretvalue(cost.minCost) then
            return true
        end
        if cost.type == Enum.PowerType.Mana and (cost.cost > 0 or cost.minCost > 0) then
            return true
        end
    end
    return false
end

local function OnSpellCast(_, _, _, spellId)
    if IsActive() and SpellCostsMana(spellId) then
        Play()
    end
end

-- Hides the line after a form change or a setting change; the next cast shows it again.
local function Refresh()
    Hide()
    local bar = PlayerFrame_GetManaBar()
    if bar then
        UpdateBarSize(bar)
    end
end

function PlayerPowerTicks:IsManaEnabled()
    return ns.charDb.playerManaTicks
end

function PlayerPowerTicks:SetManaEnabled(enabled)
    ns.charDb.playerManaTicks = enabled
    Refresh()
end

-- "/gryphonframes mana on|off".
ns:RegisterCommand("mana", function(args)
    local value = args:lower()
    if value == "on" then
        PlayerPowerTicks:SetManaEnabled(true)
    elseif value == "off" then
        PlayerPowerTicks:SetManaEnabled(false)
    elseif value ~= "" then
        ns:Print(L["HELP_MANA_RULE"])
        return
    end
    ns:Print(PlayerPowerTicks:IsManaEnabled() and L["MANA_RULE_ON"] or L["MANA_RULE_OFF"])
end, { L["HELP_MANA_RULE"] })

function PlayerPowerTicks:OnEnable()
    sparkFrame = CreateFrame("Frame", nil, UIParent)
    sparkFrame:Hide()
    spark = sparkFrame:CreateTexture(nil, "OVERLAY")
    spark:SetColorTexture(RULE_COLOR[1], RULE_COLOR[2], RULE_COLOR[3], RULE_COLOR[4])

    animation = spark:CreateAnimationGroup()
    translation = animation:CreateAnimation("Translation")
    -- The line hides at the end instead of jumping back.
    animation:SetScript("OnFinished", function()
        sparkFrame:Hide()
    end)

    ns:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", OnSpellCast)
    -- Druid forms change the power type shown in the player frame.
    ns:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player", Refresh)

    Refresh()
end
