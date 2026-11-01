local _, ns = ...
local L = ns.L

-- Shows the buffs the player cast at the player frame: below the power bar, or anywhere in Edit
-- Mode.
--
-- Blizzard shows the player's buffs only in the BuffFrame at the top right of the screen, mixed
-- with the buffs of others. This module adds an own row of icons with all buffs from the player
-- (aura filter "HELPFUL|PLAYER"), with stacks, the remaining time and the Blizzard tooltip.
-- Blizzard's BuffFrame stays untouched. ShouldShow() filters the buffs by a maximum duration, a
-- whitelist and a blacklist (spell IDs or aura names, per character).
--
-- Updates: UNIT_AURA of the player (filtered by unit in the client) rebuilds the icons only if an
-- aura from the player was added, or a shown aura changed or ran out. The remaining time is
-- updated by a ticker every TIMER_INTERVAL seconds, and only while a shown buff has a duration.
--
-- Turned on per character in the options (Modules/Options.lua) or with "/gryphonframes buffs on"
-- (ns.charDb.playerBuffs). Position, icon size and icons per row are saved per Edit Mode layout in
-- ns.db.playerBuffs.layouts[layoutName] as { point, x, y, iconSize, perRow }. Without a point, the
-- row is attached below the power bar of the player frame.
local PlayerBuffs = ns:RegisterModule("PlayerBuffs")

local LibEditMode = LibStub("LibEditMode")

local FILTER = "HELPFUL|PLAYER"
local SPACING = 2
-- Height of the remaining time below an icon.
local TIMER_HEIGHT = 10
local TIMER_INTERVAL = 0.5
-- Gap between the power bar of the player frame and the attached row.
local ATTACH_GAP = 4
PlayerBuffs.DEFAULT_ICON_SIZE, PlayerBuffs.MIN_ICON_SIZE, PlayerBuffs.MAX_ICON_SIZE = 24, 12, 48
PlayerBuffs.DEFAULT_PER_ROW, PlayerBuffs.MIN_PER_ROW, PlayerBuffs.MAX_PER_ROW = 8, 1, 16

-- Position the frame has in LibEditMode. "Reset Position" in the Edit Mode dialog moves the frame
-- exactly here, which the module takes as "attach to the player frame again" (see TargetCastBar).
local DEFAULT_POSITION = { point = "CENTER", x = 0, y = -200 }

local container
local buttons = {}
-- auraInstanceIDs of the shown buffs, to skip UNIT_AURA updates of other auras.
local shownIds = {}
local ticker

local function GetLayouts()
    return ns.db.playerBuffs.layouts
end

local function GetLayout(layoutName)
    layoutName = layoutName or LibEditMode:GetActiveLayoutName()
    return layoutName and GetLayouts()[layoutName]
end

local function GetLayoutValue(layoutName, key, default)
    local layout = GetLayout(layoutName)
    return layout and layout[key] or default
end

-- Sets a value of a layout, creating the layout entry if needed.
local function SetLayoutValue(layoutName, key, value)
    if not layoutName then
        return
    end
    local layouts = GetLayouts()
    layouts[layoutName] = layouts[layoutName] or {}
    layouts[layoutName][key] = value
end

local function IsDefaultPosition(point, x, y)
    return point == DEFAULT_POSITION.point
        and math.abs(x - DEFAULT_POSITION.x) < 0.01
        and math.abs(y - DEFAULT_POSITION.y) < 0.01
end

-- Lookup tables of the whitelist and blacklist, built from the entries in ns.charDb by
-- BuildLists(): { ids = { [spellId] = true }, names = { [lowercase name] = true } }.
local lists = {}

-- An entry is a spell ID if it is a number, otherwise an aura name. Names match all ranks of a
-- spell, but only in the language of the client.
local function BuildList(entries)
    local list = { ids = {}, names = {} }
    for _, entry in ipairs(entries) do
        local id = tonumber(entry)
        if id then
            list.ids[id] = true
        else
            list.names[tostring(entry):lower()] = true
        end
    end
    return list
end

local function BuildLists()
    lists.whitelist = BuildList(ns.charDb.playerBuffsWhitelist)
    lists.blacklist = BuildList(ns.charDb.playerBuffsBlacklist)
end

local function IsInList(list, auraData)
    local spellId, name = auraData.spellId, auraData.name
    if spellId and not ns.Compat.IsSecret(spellId) and list.ids[spellId] then
        return true
    end
    return name and not ns.Compat.IsSecret(name) and list.names[name:lower()] or false
end

-- Which buffs from the player are shown: never the ones on the blacklist, always the ones on the
-- whitelist. With ns.charDb.playerBuffsWhitelistOnly only the whitelist is shown. Buffs without a
-- duration (forms, auras, aspects) are hidden with ns.charDb.playerBuffsHidePermanent; the others
-- only up to the maximum duration (ns.charDb.playerBuffsMaxDuration in seconds, 0 = no limit). The
-- maximum duration is the full duration of the buff, not the remaining time.
local function ShouldShow(auraData)
    if IsInList(lists.blacklist, auraData) then
        return false
    end
    if IsInList(lists.whitelist, auraData) then
        return true
    end
    if ns.charDb.playerBuffsWhitelistOnly then
        return false
    end
    local duration = auraData.duration
    if ns.Compat.IsSecret(duration) then
        return true
    end
    if not duration or duration == 0 then
        return not ns.charDb.playerBuffsHidePermanent
    end
    local maxDuration = ns.charDb.playerBuffsMaxDuration
    return maxDuration == 0 or duration <= maxDuration
end

local function ShowTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetUnitBuffByAuraInstanceID("player", button.auraInstanceID, FILTER)
end

local function CreateButton()
    local button = CreateFrame("Button", nil, container)
    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetAllPoints()
    button.Count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    button.Count:SetPoint("BOTTOMRIGHT", 2, 0)
    button.Duration = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.Duration:SetPoint("TOP", button, "BOTTOM", 0, -1)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return button
end

local function UpdateDuration(button)
    local expirationTime = button.expirationTime
    if not expirationTime or expirationTime == 0 or ns.Compat.IsSecret(expirationTime) then
        button.Duration:SetText("")
        return
    end
    local remaining = math.max(expirationTime - GetTime(), 0)
    button.Duration:SetFormattedText(SecondsToTimeAbbrev(remaining))
end

local function UpdateDurations()
    for _, button in ipairs(buttons) do
        if button:IsShown() then
            UpdateDuration(button)
        end
    end
end

local function SetTicker(needed)
    if needed and not ticker then
        ticker = C_Timer.NewTicker(TIMER_INTERVAL, UpdateDurations)
    elseif not needed and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

-- Size of the row: a full row of icons, so it can be picked up in Edit Mode without buffs.
local function UpdateContainerSize(count)
    local iconSize = GetLayoutValue(nil, "iconSize", PlayerBuffs.DEFAULT_ICON_SIZE)
    local perRow = GetLayoutValue(nil, "perRow", PlayerBuffs.DEFAULT_PER_ROW)
    local rows = math.max(math.ceil(count / perRow), 1)
    container:SetSize(perRow * (iconSize + SPACING) - SPACING, rows * (iconSize + TIMER_HEIGHT + SPACING) - SPACING)
end

-- Shows the buffs from the player, in the order of the game. Reads C_UnitAuras directly instead of
-- AuraUtil.ForEachAura: in Edit Mode, Blizzard switches AuraUtil to example auras
-- (AURA_DATA_PROVIDER_SWITCH), which would stay in the row after Edit Mode until the next
-- UNIT_AURA.
local function UpdateAuras()
    wipe(shownIds)
    local count = 0
    local hasDuration = false
    if ns.charDb.playerBuffs then
        local iconSize = GetLayoutValue(nil, "iconSize", PlayerBuffs.DEFAULT_ICON_SIZE)
        local perRow = GetLayoutValue(nil, "perRow", PlayerBuffs.DEFAULT_PER_ROW)
        local index = 1
        local auraData = C_UnitAuras.GetAuraDataByIndex("player", index, FILTER)
        while auraData do
            if ShouldShow(auraData) then
                count = count + 1
                local button = buttons[count] or CreateButton()
                buttons[count] = button
                button.auraInstanceID = auraData.auraInstanceID
                button.expirationTime = auraData.expirationTime
                button.Icon:SetTexture(auraData.icon)
                local applications = auraData.applications
                button.Count:SetText((ns.Compat.IsSecret(applications) or applications > 1) and applications or "")
                button:SetSize(iconSize, iconSize)
                button:ClearAllPoints()
                local column, row = (count - 1) % perRow, math.floor((count - 1) / perRow)
                button:SetPoint("TOPLEFT", column * (iconSize + SPACING), -row * (iconSize + TIMER_HEIGHT + SPACING))
                UpdateDuration(button)
                button:Show()
                shownIds[auraData.auraInstanceID] = true
                if button.Duration:GetText() ~= "" then
                    hasDuration = true
                end
            end
            index = index + 1
            auraData = C_UnitAuras.GetAuraDataByIndex("player", index, FILTER)
        end
    end
    for i = count + 1, #buttons do
        buttons[i]:Hide()
    end
    UpdateContainerSize(count)
    SetTicker(hasDuration)
end

-- Whether a UNIT_AURA update can change the shown buffs: a full update, a new aura from the
-- player, or a shown aura that changed or ran out.
local function IsRelevantUpdate(updateInfo)
    if not updateInfo or updateInfo.isFullUpdate then
        return true
    end
    for _, auraData in ipairs(updateInfo.addedAuras or {}) do
        -- A hidden source may be the player, so it updates too.
        local sourceUnit = auraData.sourceUnit
        if ns.Compat.IsSecret(sourceUnit)
                or (auraData.isHelpful and sourceUnit and UnitIsUnit(sourceUnit, "player")) then
            return true
        end
    end
    for _, id in ipairs(updateInfo.updatedAuraInstanceIDs or {}) do
        if shownIds[id] then
            return true
        end
    end
    for _, id in ipairs(updateInfo.removedAuraInstanceIDs or {}) do
        if shownIds[id] then
            return true
        end
    end
    return false
end

-- Attaches the row below the power bar of the player frame, or moves it to the saved position of
-- the active layout.
local function ApplyLayout()
    container:ClearAllPoints()
    local layout = GetLayout()
    if layout and layout.point then
        container:SetPoint(layout.point, UIParent, layout.point, layout.x, layout.y)
    else
        local bar = PlayerFrame_GetManaBar()
        container:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -ATTACH_GAP)
    end
    UpdateAuras()
end

-- Current position relative to UIParent's center (the row has scale 1).
local function GetContainerPosition()
    local x, y = container:GetCenter()
    local width, height = UIParent:GetSize()
    return "CENTER", x - width / 2, y - height / 2
end

local function SetAttached(layoutName, attached)
    if not layoutName then
        return
    end
    if attached then
        SetLayoutValue(layoutName, "point", nil)
    elseif not GetLayoutValue(layoutName, "point") then
        local point, x, y = GetContainerPosition()
        SetLayoutValue(layoutName, "point", point)
        SetLayoutValue(layoutName, "x", x)
        SetLayoutValue(layoutName, "y", y)
    end
    ApplyLayout()
end

-- LibEditMode callback after the row was dragged, moved with the arrow keys or reset.
local function OnPositionChanged(_, layoutName, point, x, y)
    if not layoutName then
        return
    end
    if IsDefaultPosition(point, x, y) then
        SetAttached(layoutName, true)
        return
    end
    SetLayoutValue(layoutName, "point", point)
    SetLayoutValue(layoutName, "x", x)
    SetLayoutValue(layoutName, "y", y)
    ApplyLayout()
end

local function RegisterEditMode()
    container.editModeName = L["PLAYER_BUFFS"]
    LibEditMode:AddFrame(container, OnPositionChanged, DEFAULT_POSITION, L["PLAYER_BUFFS"])
    LibEditMode:AddFrameSettings(container, {
        {
            kind = LibEditMode.SettingType.Checkbox,
            name = L["PLAYER_BUFFS_ATTACH"],
            desc = L["PLAYER_BUFFS_ATTACH_DESC"],
            default = true,
            get = function(layoutName)
                return not GetLayoutValue(layoutName, "point")
            end,
            set = SetAttached,
        },
        {
            kind = LibEditMode.SettingType.Slider,
            name = L["PLAYER_BUFFS_ICON_SIZE"],
            default = PlayerBuffs.DEFAULT_ICON_SIZE,
            minValue = PlayerBuffs.MIN_ICON_SIZE,
            maxValue = PlayerBuffs.MAX_ICON_SIZE,
            valueStep = 1,
            get = function(layoutName)
                return GetLayoutValue(layoutName, "iconSize", PlayerBuffs.DEFAULT_ICON_SIZE)
            end,
            set = function(layoutName, value)
                SetLayoutValue(layoutName, "iconSize", value)
                ApplyLayout()
            end,
        },
        {
            kind = LibEditMode.SettingType.Slider,
            name = L["PLAYER_BUFFS_PER_ROW"],
            default = PlayerBuffs.DEFAULT_PER_ROW,
            minValue = PlayerBuffs.MIN_PER_ROW,
            maxValue = PlayerBuffs.MAX_PER_ROW,
            valueStep = 1,
            get = function(layoutName)
                return GetLayoutValue(layoutName, "perRow", PlayerBuffs.DEFAULT_PER_ROW)
            end,
            set = function(layoutName, value)
                SetLayoutValue(layoutName, "perRow", value)
                ApplyLayout()
            end,
        },
    })

    LibEditMode:RegisterCallback("layout", ApplyLayout)
    LibEditMode:RegisterCallback("enter", ApplyLayout)
    LibEditMode:RegisterCallback("create", function(layoutName, _, sourceLayoutName)
        local source = sourceLayoutName and GetLayouts()[sourceLayoutName]
        if source then
            GetLayouts()[layoutName] = CopyTable(source)
        end
    end)
    LibEditMode:RegisterCallback("rename", function(oldLayoutName, newLayoutName)
        GetLayouts()[newLayoutName] = GetLayouts()[oldLayoutName]
        GetLayouts()[oldLayoutName] = nil
    end)
    LibEditMode:RegisterCallback("delete", function(layoutName)
        GetLayouts()[layoutName] = nil
    end)
end

function PlayerBuffs:IsEnabled()
    return ns.charDb.playerBuffs
end

function PlayerBuffs:SetEnabled(enabled)
    ns.charDb.playerBuffs = enabled
    if container then
        container:SetShown(enabled)
        UpdateAuras()
    end
end

function PlayerBuffs:IsHidingPermanent()
    return ns.charDb.playerBuffsHidePermanent
end

function PlayerBuffs:SetHidingPermanent(hide)
    ns.charDb.playerBuffsHidePermanent = hide
    if container then
        UpdateAuras()
    end
end

function PlayerBuffs:IsWhitelistOnly()
    return ns.charDb.playerBuffsWhitelistOnly
end

function PlayerBuffs:SetWhitelistOnly(whitelistOnly)
    ns.charDb.playerBuffsWhitelistOnly = whitelistOnly
    if container then
        UpdateAuras()
    end
end

-- Choices for the maximum duration in seconds, 0 = no limit.
PlayerBuffs.MAX_DURATIONS = { 0, 30, 60, 120, 300, 600, 1800, 3600 }

function PlayerBuffs:GetMaxDuration()
    return ns.charDb.playerBuffsMaxDuration
end

function PlayerBuffs:SetMaxDuration(seconds)
    ns.charDb.playerBuffsMaxDuration = seconds
    if container then
        UpdateAuras()
    end
end

-- "whitelist" or "blacklist": the entries as entered, spell IDs as numbers.
function PlayerBuffs:GetList(kind)
    return kind == "whitelist" and ns.charDb.playerBuffsWhitelist or ns.charDb.playerBuffsBlacklist
end

function PlayerBuffs:SetList(kind, entries)
    local saved = {}
    for i, entry in ipairs(entries) do
        saved[i] = tonumber(entry) or entry
    end
    if kind == "whitelist" then
        ns.charDb.playerBuffsWhitelist = saved
    else
        ns.charDb.playerBuffsBlacklist = saved
    end
    BuildLists()
    if container then
        UpdateAuras()
    end
end

ns:RegisterCommand("buffs", function(args)
    local value = args:lower()
    if value == "on" then
        PlayerBuffs:SetEnabled(true)
    elseif value == "off" then
        PlayerBuffs:SetEnabled(false)
    elseif value ~= "" then
        ns:Print(L["HELP_BUFFS"])
        return
    end
    ns:Print(PlayerBuffs:IsEnabled() and L["BUFFS_ON"] or L["BUFFS_OFF"])
end, { L["HELP_BUFFS"] })

function PlayerBuffs:OnEnable()
    BuildLists()

    -- Invisible itself: only the icons have textures. LibEditMode shows its selection overlay on
    -- top of it while Edit Mode is open.
    container = CreateFrame("Frame", nil, UIParent)
    container:SetClampedToScreen(true)
    container:SetShown(ns.charDb.playerBuffs)

    RegisterEditMode()
    ns:RegisterUnitEvent("UNIT_AURA", "player", function(_, _, updateInfo)
        if IsRelevantUpdate(updateInfo) then
            UpdateAuras()
        end
    end)

    ApplyLayout()
end
