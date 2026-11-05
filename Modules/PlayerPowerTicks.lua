local _, ns = ...
local L = ns.L

-- Shows the power ticks on the power bar of the player frame: a spark runs from left to right in
-- the 2 seconds between two ticks, so the player sees when the next energy or mana tick comes.
-- For mana, a spend starts the five second rule instead: a tinted spark runs back from right to
-- left in 5 seconds, the time without mana regeneration, then the tick spark takes over at the
-- next tick.
--
-- Energy and mana regenerate in ticks every 2 seconds on Classic Era and Anniversary. The game has
-- no API or event for the tick itself, so the module takes the time of gains from
-- UNIT_POWER_FREQUENT and keeps the 2-second rhythm going from there, also at full energy, when no
-- event fires. Gains outside the rhythm (Relentless Strikes, Thistle Tea, Furor, potions, Life
-- Tap) do not move it; only two such gains 2 seconds apart (the rhythm really shifted) do. Every
-- loss of mana counts as a spend, also mana drained by enemies.
--
-- On Forever, power values are secret in combat, so gains and spends cannot be seen there. The
-- module only shows the five second rule on Forever, without reading power: every successful cast
-- of a spell that costs mana starts it. Free casts (Clearcasting) start it as well, mana drained by
-- enemies does not. Energy ticks and the mana tick spark are not available there.
--
-- The spark moves by a translation animation, so no Lua runs per frame. Lua only runs on power
-- events of the player (on Forever on spell casts), on form changes and when a setting changes.
--
-- Turned on per character and power type in the options (Modules/Options.lua) or with
-- "/gryphonframes energy on" and "/gryphonframes mana on" (ns.charDb.playerEnergyTicks,
-- ns.charDb.playerManaTicks). The power bar comes from PlayerFrame_GetManaBar(), which all
-- supported clients have.

local PlayerPowerTicks = ns:RegisterModule("PlayerPowerTicks")

-- False on Forever, see above.
PlayerPowerTicks.HAS_TICKS = ns.Compat.CanReadValuesInCombat()

local TICK_INTERVAL = 2
local FIVE_SECOND_RULE = 5
-- Allowed deviation in seconds of a gain from the tick rhythm (event and frame delay).
local TOLERANCE = 0.3
local SPARK_TEXTURE = "Interface\\CastingBar\\UI-CastingBar-Spark"
local SPARK_WIDTH = 16
local RULE_WIDTH = 2
local RULE_COLOR = { 1, 0.1, 0.1, 0.75 }

-- One tracker per power type, keyed by the power token of UNIT_POWER_FREQUENT. tickTime is the time
-- of the last known tick (nil until the first gain), candidateTime a gain outside the rhythm that
-- may start a new one, ruleEnd the end of the five second rule.
local trackers = {
    ENERGY = { powerType = Enum.PowerType.Energy, setting = "playerEnergyTicks" },
    -- Full mana has no tick to wait for, so the spark hides there.
    MANA = {
        powerType = Enum.PowerType.Mana, setting = "playerManaTicks", fiveSecondRule = true, hideWhenFull = true,
    },
}

local spark, sparkFrame, animation, translation
-- Last readable size of the power bar.
local barWidth, barHeight
-- Counts the timers; only the latest one runs, a new one or Hide() cancels the others.
local timerId = 0

local function After(delay, callback)
    timerId = timerId + 1
    local id = timerId
    C_Timer.After(delay, function()
        if id == timerId then
            callback()
        end
    end)
end

-- The tracker of the power type the player frame shows, if its setting is on.
local function GetActiveTracker()
    local powerType = UnitPowerType("player")
    for _, tracker in pairs(trackers) do
        if tracker.powerType == powerType then
            return ns.charDb[tracker.setting] and tracker or nil
        end
    end
end

local function IsInRule(tracker, now)
    return tracker.ruleEnd and now < tracker.ruleEnd
end

local function IsFull(tracker)
    return UnitPower("player", tracker.powerType) >= UnitPowerMax("player", tracker.powerType)
end

-- Frame sizes may be secret on Forever, where the five second rule starts in combat. The size from
-- before that is kept then; the power bar does not change its size in combat.
local function UpdateBarSize(bar)
    local width, height = bar:GetWidth(), bar:GetHeight()
    if not ns.Compat.IsSecret(width) and not ns.Compat.IsSecret(height) then
        barWidth, barHeight = width, height
    end
end

-- Seconds between time and the nearest tick of the rhythm that started at startTime.
local function GetDeviation(time, startTime)
    local phase = (time - startTime) % TICK_INTERVAL
    return math.min(phase, TICK_INTERVAL - phase)
end

local function Hide()
    timerId = timerId + 1
    if sparkFrame then
        animation:Stop()
        sparkFrame:Hide()
    end
end

-- Runs the spark across the power bar in duration seconds, from left to right or (reverse) from
-- right to left, once or again and again. The width is read on each start, so a changed power bar
-- is picked up.
local function Play(duration, looping, color, reverse)
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
    -- The spark texture needs additive blending, it has a black background (checked in-game). That
    -- adds the blue of the mana bar to a tint and turns red into pink, so a tinted spark is a line.
    if color then
        spark:SetColorTexture(color[1], color[2], color[3], color[4])
        spark:SetBlendMode("BLEND")
        spark:SetSize(RULE_WIDTH, barHeight - 1)
    else
        spark:SetTexture(SPARK_TEXTURE)
        spark:SetBlendMode("ADD")
        spark:SetSize(SPARK_WIDTH, barHeight * 2)
    end
    animation:Stop()
    spark:ClearAllPoints()
    spark:SetPoint("CENTER", sparkFrame, reverse and "RIGHT" or "LEFT")
    animation:SetLooping(looping and "REPEAT" or "NONE")
    translation:SetDuration(duration)
    translation:SetOffset(reverse and -barWidth or barWidth, 0)
    sparkFrame:Show()
    animation:Play()
end

-- Starts the tick spark at a tick, if the tracker is shown and not in the five second rule.
local function StartTicks(tracker)
    if tracker ~= GetActiveTracker() or IsInRule(tracker, GetTime())
            or (tracker.hideWhenFull and IsFull(tracker)) then
        Hide()
        return
    end
    timerId = timerId + 1
    Play(TICK_INTERVAL, true)
end

-- Starts the tick spark at the next tick of the rhythm. The animation cannot start in the middle,
-- so the spark stays hidden until then; without a known rhythm it waits for the next gain.
local function StartAtNextTick(tracker)
    Hide()
    if tracker.tickTime then
        After(TICK_INTERVAL - (GetTime() - tracker.tickTime) % TICK_INTERVAL, function()
            StartTicks(tracker)
        end)
    end
end

local function OnGain(tracker, now)
    if not tracker.tickTime or GetDeviation(now, tracker.tickTime) <= TOLERANCE then
        tracker.tickTime, tracker.candidateTime = now, nil
    elseif tracker.candidateTime and GetDeviation(now, tracker.candidateTime) <= TOLERANCE then
        -- Two gains outside the rhythm, but in a rhythm of their own: the ticks shifted.
        tracker.tickTime, tracker.candidateTime = now, nil
    else
        tracker.candidateTime = now
        return
    end
    -- Gains in the five second rule (mana per 5 seconds from gear) only keep the rhythm.
    if not IsInRule(tracker, now) then
        StartTicks(tracker)
    end
end

local function OnSpend(tracker, now)
    tracker.ruleEnd = now + FIVE_SECOND_RULE
    if tracker == GetActiveTracker() then
        Play(FIVE_SECOND_RULE, false, RULE_COLOR, true)
        After(FIVE_SECOND_RULE, function()
            StartAtNextTick(tracker)
        end)
    end
end

local function OnPowerChanged(tracker)
    local value = UnitPower("player", tracker.powerType)
    local now = GetTime()
    if value > tracker.last then
        OnGain(tracker, now)
    elseif value < tracker.last and tracker.fiveSecondRule then
        OnSpend(tracker, now)
    end
    tracker.last = value
end

-- Forever only, where power cannot be read: the cast stands in for the spend.
local function OnSpellCast(_, _, _, spellId)
    if ns.Compat.SpellCostsMana(spellId) then
        OnSpend(trackers.MANA, GetTime())
    end
end

-- Shows or hides the spark after a form change or a setting change. The rhythm and the five
-- second rule are kept while the power type is not shown; the spark comes back at the end of the
-- rule or at the next tick.
local function Refresh()
    Hide()
    local bar = PlayerFrame_GetManaBar()
    if bar then
        UpdateBarSize(bar)
    end
    local tracker = GetActiveTracker()
    if not tracker then
        return
    end
    local now = GetTime()
    if IsInRule(tracker, now) then
        After(tracker.ruleEnd - now, function()
            StartAtNextTick(tracker)
        end)
    else
        StartAtNextTick(tracker)
    end
end

local function SetSetting(key, value)
    ns.charDb[key] = value
    Refresh()
end

function PlayerPowerTicks:IsEnergyEnabled()
    return ns.charDb.playerEnergyTicks
end

function PlayerPowerTicks:SetEnergyEnabled(enabled)
    SetSetting("playerEnergyTicks", enabled)
end

function PlayerPowerTicks:IsManaEnabled()
    return ns.charDb.playerManaTicks
end

function PlayerPowerTicks:SetManaEnabled(enabled)
    SetSetting("playerManaTicks", enabled)
end

-- "/gryphonframes energy on|off" and "/gryphonframes mana on|off".
local function RegisterToggleCommand(name, help, onText, offText, isEnabled, setEnabled)
    ns:RegisterCommand(name, function(args)
        local value = args:lower()
        if value == "on" then
            setEnabled(PlayerPowerTicks, true)
        elseif value == "off" then
            setEnabled(PlayerPowerTicks, false)
        elseif value ~= "" then
            ns:Print(help)
            return
        end
        ns:Print(isEnabled(PlayerPowerTicks) and onText or offText)
    end, { help })
end

if PlayerPowerTicks.HAS_TICKS then
    RegisterToggleCommand("energy", L["HELP_ENERGY"], L["ENERGY_ON"], L["ENERGY_OFF"],
        PlayerPowerTicks.IsEnergyEnabled, PlayerPowerTicks.SetEnergyEnabled)
    RegisterToggleCommand("mana", L["HELP_MANA"], L["MANA_ON"], L["MANA_OFF"],
        PlayerPowerTicks.IsManaEnabled, PlayerPowerTicks.SetManaEnabled)
else
    RegisterToggleCommand("mana", L["HELP_MANA_RULE"], L["MANA_RULE_ON"], L["MANA_RULE_OFF"],
        PlayerPowerTicks.IsManaEnabled, PlayerPowerTicks.SetManaEnabled)
end

function PlayerPowerTicks:OnEnable()
    sparkFrame = CreateFrame("Frame", nil, UIParent)
    sparkFrame:Hide()
    spark = sparkFrame:CreateTexture(nil, "OVERLAY")

    animation = spark:CreateAnimationGroup()
    translation = animation:CreateAnimation("Translation")
    -- The five second rule runs once; the spark hides at its end instead of jumping back.
    animation:SetScript("OnFinished", function()
        sparkFrame:Hide()
    end)

    if self.HAS_TICKS then
        for _, tracker in pairs(trackers) do
            tracker.last = UnitPower("player", tracker.powerType)
        end
        ns:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player", function(_, _, powerToken)
            local tracker = trackers[powerToken]
            if tracker then
                OnPowerChanged(tracker)
            end
        end)
    else
        ns:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", OnSpellCast)
    end
    -- Druid forms change the power type shown in the player frame.
    ns:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player", Refresh)

    Refresh()
end
