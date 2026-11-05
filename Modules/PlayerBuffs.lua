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
-- aura from the player was added, or a shown aura changed or ran out. The client updates the
-- remaining time itself (ns.Compat.SetAuraDurationText), also when it is secret. If the client
-- refuses to hand out auras (addon restrictions on Forever), the row stays as it is and is rebuilt
-- when the restriction ends.
--
-- Turned on per character in the options (Modules/Options.lua) or with "/gryphonframes buffs on"
-- (ns.charDb.playerBuffs). Position, icon size, icons per row, alignment and sort order are saved
-- per Edit Mode layout in ns.db.playerBuffs.layouts[layoutName] as
-- { point, x, y, iconSize, perRow, alignment, sort, sortReversed }. Without a point, the row is
-- attached below the power bar of the player frame.
--
-- Turned off on Forever for now: the client does not list auras for addon code in combat, so buffs
-- gained there would not show up.
if not ns.Compat.CanReadValuesInCombat() then
    return
end

local PlayerBuffs = ns:RegisterModule("PlayerBuffs")

local LibEditMode = LibStub("LibEditMode")

local FILTER = "HELPFUL|PLAYER"
local SPACING = 2
-- Height of the remaining time below an icon.
local TIMER_HEIGHT = 10
-- Gap between the power bar of the player frame and the attached row.
local ATTACH_GAP = 4
PlayerBuffs.DEFAULT_ICON_SIZE, PlayerBuffs.MIN_ICON_SIZE, PlayerBuffs.MAX_ICON_SIZE = 24, 12, 48
PlayerBuffs.DEFAULT_PER_ROW, PlayerBuffs.MIN_PER_ROW, PlayerBuffs.MAX_PER_ROW = 8, 1, 16
-- How the icons of a row are arranged: "left" (from left to right), "center" or "right" (from
-- right to left).
PlayerBuffs.DEFAULT_ALIGNMENT = "left"
-- Order of the icons: "index" (the order of the game), "time" (shortest remaining time first),
-- "duration" (shortest full duration first), "name" or "whitelist" (in the order of the whitelist,
-- the other buffs after them). sortReversed in the layout turns the order around.
PlayerBuffs.DEFAULT_SORT = "index"

-- Position the frame has in LibEditMode. "Reset Position" in the Edit Mode dialog moves the frame
-- exactly here, which the module takes as "attach to the player frame again" (see TargetCastBar).
local DEFAULT_POSITION = { point = "CENTER", x = 0, y = -200 }
-- The lists in the update info of UNIT_AURA.
local UPDATE_LISTS = { "addedAuras", "updatedAuraInstanceIDs", "removedAuraInstanceIDs" }

local container
local buttons = {}
-- auraInstanceIDs of the shown buffs, to skip UNIT_AURA updates of other auras.
local shownIds = {}

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
-- BuildLists(): { ids = { [spellId] = position }, names = { [lowercase name] = position } }, with
-- the position of the first entry for it in the list (for the sort order "whitelist").
local lists = {}

-- An entry is a spell ID if it is a number, otherwise an aura name. Names match all ranks of a
-- spell, but only in the language of the client.
local function BuildList(entries)
    local list = { ids = {}, names = {} }
    for position, entry in ipairs(entries) do
        local id = tonumber(entry)
        if id then
            list.ids[id] = list.ids[id] or position
        else
            local name = tostring(entry):lower()
            list.names[name] = list.names[name] or position
        end
    end
    return list
end

local function BuildLists()
    lists.whitelist = BuildList(ns.charDb.playerBuffsWhitelist)
    lists.blacklist = BuildList(ns.charDb.playerBuffsBlacklist)
end

-- Position of the first list entry that matches the buff, or nil.
local function GetListPosition(list, auraData)
    local spellId, name = auraData.spellId, auraData.name
    local idPosition = spellId and not ns.Compat.IsSecret(spellId) and list.ids[spellId]
    local namePosition = name and not ns.Compat.IsSecret(name) and list.names[name:lower()]
    if idPosition and namePosition then
        return math.min(idPosition, namePosition)
    end
    return idPosition or namePosition or nil
end

-- Which buffs from the player are shown: never the ones on the blacklist, always the ones on the
-- whitelist. With ns.charDb.playerBuffsWhitelistOnly only the whitelist is shown. Buffs without a
-- duration (forms, auras, aspects) are hidden with ns.charDb.playerBuffsHidePermanent; the others
-- only up to the maximum duration (ns.charDb.playerBuffsMaxDuration in seconds, 0 = no limit). The
-- maximum duration is the full duration of the buff, not the remaining time. With secret spell ID
-- and name (combat restrictions), the lists cannot match: the buff is shown, also with
-- playerBuffsWhitelistOnly, so the row does not become empty in combat.
local function ShouldShow(auraData)
    if GetListPosition(lists.blacklist, auraData) then
        return false
    end
    if GetListPosition(lists.whitelist, auraData) then
        return true
    end
    if ns.charDb.playerBuffsWhitelistOnly then
        return ns.Compat.IsSecret(auraData.spellId) and ns.Compat.IsSecret(auraData.name)
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

-- Shows the remaining time below the icon, empty for buffs without a duration. The client keeps
-- the text up to date; without the API for it, the text stays empty.
local function UpdateDuration(button)
    if not ns.Compat.SetAuraDurationText(button.Duration, "player", button.auraInstanceID) then
        button.Duration:SetText("")
    end
end

-- Size of the row: a full row of icons, so it can be picked up in Edit Mode without buffs.
local function UpdateContainerSize(count)
    local iconSize = GetLayoutValue(nil, "iconSize", PlayerBuffs.DEFAULT_ICON_SIZE)
    local perRow = GetLayoutValue(nil, "perRow", PlayerBuffs.DEFAULT_PER_ROW)
    local rows = math.max(math.ceil(count / perRow), 1)
    container:SetSize(perRow * (iconSize + SPACING) - SPACING, rows * (iconSize + TIMER_HEIGHT + SPACING) - SPACING)
end

-- Places the shown icons in rows, aligned within the full width of a row (see UpdateContainerSize).
local function LayoutButtons(count)
    local iconSize = GetLayoutValue(nil, "iconSize", PlayerBuffs.DEFAULT_ICON_SIZE)
    local perRow = GetLayoutValue(nil, "perRow", PlayerBuffs.DEFAULT_PER_ROW)
    local alignment = GetLayoutValue(nil, "alignment", PlayerBuffs.DEFAULT_ALIGNMENT)
    for i = 1, count do
        local column, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        if alignment == "right" then
            column = perRow - 1 - column
        elseif alignment == "center" then
            local inRow = math.min(count - row * perRow, perRow)
            column = column + (perRow - inRow) / 2
        end
        local button = buttons[i]
        button:SetSize(iconSize, iconSize)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", column * (iconSize + SPACING), -row * (iconSize + TIMER_HEIGHT + SPACING))
    end
end

-- Value a buff is sorted by, or nil to put it after the others: the expiration time for "time"
-- (the order by remaining time stays the same while the buffs run, so no resort is needed), the
-- full duration for "duration", the lowercase name for "name" and the position in the whitelist for
-- "whitelist". Buffs without a duration, buffs not on the whitelist and secret values have no sort
-- value.
local function GetSortValue(auraData, sort)
    if sort == "time" then
        local expirationTime = auraData.expirationTime
        if expirationTime and not ns.Compat.IsSecret(expirationTime) and expirationTime > 0 then
            return expirationTime
        end
    elseif sort == "duration" then
        local duration = auraData.duration
        if duration and not ns.Compat.IsSecret(duration) and duration > 0 then
            return duration
        end
    elseif sort == "whitelist" then
        return GetListPosition(lists.whitelist, auraData)
    elseif sort == "name" then
        local name = auraData.name
        if name and not ns.Compat.IsSecret(name) then
            return name:lower()
        end
    end
end

-- Shown buffs of the last update as { auraData, index, value }, reused to avoid garbage.
local sorted = {}

local function CompareSortValues(a, b)
    if a.value and b.value and a.value ~= b.value then
        return a.value < b.value
    elseif (a.value == nil) ~= (b.value == nil) then
        return a.value ~= nil
    end
    return a.index < b.index
end

-- Orders the shown buffs by sort value, buffs without one last. The game's order breaks ties, so
-- the order is stable. Reversed turns the whole order around, so buffs without a sort value come
-- first (e.g. buffs without a duration as the longest ones).
local function SortAuras(count, sort, reversed)
    if sort ~= PlayerBuffs.DEFAULT_SORT then
        for i = 1, count do
            sorted[i].value = GetSortValue(sorted[i].auraData, sort)
        end
        table.sort(sorted, CompareSortValues)
    end
    if reversed then
        for i = 1, math.floor(count / 2) do
            sorted[i], sorted[count + 1 - i] = sorted[count + 1 - i], sorted[i]
        end
    end
end

-- True if UpdateAuras() could not read the auras and has to run again when a restriction ends.
local updatePending = false

-- Fills sorted with the buffs to show and returns their number, or nil if the client refuses to
-- hand out the auras. Reads C_UnitAuras directly instead of AuraUtil.ForEachAura: in Edit Mode,
-- Blizzard switches AuraUtil to example auras (AURA_DATA_PROVIDER_SWITCH), which would stay in the
-- row after Edit Mode until the next UNIT_AURA.
local function ReadAuras()
    local count, index = 0, 1
    local readable, auraData = ns.Compat.TryGetAuraDataByIndex("player", index, FILTER)
    while readable and auraData do
        if ShouldShow(auraData) then
            count = count + 1
            local entry = sorted[count] or {}
            sorted[count] = entry
            entry.auraData, entry.index = auraData, index
        end
        index = index + 1
        readable, auraData = ns.Compat.TryGetAuraDataByIndex("player", index, FILTER)
    end
    if not readable then
        return nil
    end
    for i = count + 1, #sorted do
        sorted[i] = nil
    end
    return count
end

-- Shows the buffs from the player, in the order of the game or sorted (SortAuras).
local function UpdateAuras()
    local count = ns.charDb.playerBuffs and ReadAuras()
    updatePending = count == nil
    if updatePending then
        return
    end
    count = count or 0
    wipe(shownIds)
    if count > 0 then
        SortAuras(count, GetLayoutValue(nil, "sort", PlayerBuffs.DEFAULT_SORT),
            GetLayoutValue(nil, "sortReversed", false))
        for i = 1, count do
            local auraData = sorted[i].auraData
            local button = buttons[i] or CreateButton()
            buttons[i] = button
            button.auraInstanceID = auraData.auraInstanceID
            button.Icon:SetTexture(auraData.icon)
            button.Count:SetText(ns.Compat.GetAuraStackText("player", auraData))
            UpdateDuration(button)
            button:Show()
            -- A secret value cannot be a table key; IsRelevantUpdate() then updates on every change.
            if not ns.Compat.IsSecret(auraData.auraInstanceID) then
                shownIds[auraData.auraInstanceID] = true
            end
        end
    end
    for i = count + 1, #buttons do
        buttons[i]:Hide()
        ns.Compat.SetAuraDurationText(buttons[i].Duration, nil)
    end
    LayoutButtons(count)
    UpdateContainerSize(count)
end

-- True if a part of the update cannot be read (combat restrictions).
local function HasHiddenFields(updateInfo)
    if ns.Compat.IsSecret(updateInfo.isFullUpdate) then
        return true
    end
    for _, key in ipairs(UPDATE_LISTS) do
        local list = updateInfo[key]
        if ns.Compat.IsSecret(list) or (list and not ns.Compat.IsReadableTable(list)) then
            return true
        end
    end
    return false
end

-- Whether a UNIT_AURA update can change the shown buffs: a full update, a new aura from the
-- player, or a shown aura that changed or ran out. What cannot be read may be any of these, so it
-- updates too.
local function IsRelevantUpdate(updateInfo)
    if not ns.Compat.IsReadableTable(updateInfo) or HasHiddenFields(updateInfo) or updateInfo.isFullUpdate then
        return true
    end
    for _, auraData in ipairs(updateInfo.addedAuras or {}) do
        local sourceUnit, isHelpful = auraData.sourceUnit, auraData.isHelpful
        if ns.Compat.IsSecret(sourceUnit) or ns.Compat.IsSecret(isHelpful)
                or (isHelpful and sourceUnit and UnitIsUnit(sourceUnit, "player")) then
            return true
        end
    end
    for _, id in ipairs(updateInfo.updatedAuraInstanceIDs or {}) do
        if ns.Compat.IsSecret(id) or shownIds[id] then
            return true
        end
    end
    for _, id in ipairs(updateInfo.removedAuraInstanceIDs or {}) do
        if ns.Compat.IsSecret(id) or shownIds[id] then
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
        {
            kind = LibEditMode.SettingType.Dropdown,
            name = L["PLAYER_BUFFS_ALIGNMENT"],
            default = PlayerBuffs.DEFAULT_ALIGNMENT,
            values = {
                { text = L["PLAYER_BUFFS_ALIGNMENT_LEFT"], value = "left" },
                { text = L["PLAYER_BUFFS_ALIGNMENT_CENTER"], value = "center" },
                { text = L["PLAYER_BUFFS_ALIGNMENT_RIGHT"], value = "right" },
            },
            get = function(layoutName)
                return GetLayoutValue(layoutName, "alignment", PlayerBuffs.DEFAULT_ALIGNMENT)
            end,
            set = function(layoutName, value)
                SetLayoutValue(layoutName, "alignment", value)
                ApplyLayout()
            end,
        },
        {
            kind = LibEditMode.SettingType.Dropdown,
            name = L["PLAYER_BUFFS_SORT"],
            desc = L["PLAYER_BUFFS_SORT_DESC"],
            default = PlayerBuffs.DEFAULT_SORT,
            values = {
                { text = L["PLAYER_BUFFS_SORT_INDEX"], value = "index" },
                { text = L["PLAYER_BUFFS_SORT_TIME"], value = "time" },
                { text = L["PLAYER_BUFFS_SORT_DURATION"], value = "duration" },
                { text = L["PLAYER_BUFFS_SORT_NAME"], value = "name" },
                { text = L["PLAYER_BUFFS_SORT_WHITELIST"], value = "whitelist" },
            },
            get = function(layoutName)
                return GetLayoutValue(layoutName, "sort", PlayerBuffs.DEFAULT_SORT)
            end,
            set = function(layoutName, value)
                SetLayoutValue(layoutName, "sort", value)
                ApplyLayout()
            end,
        },
        {
            kind = LibEditMode.SettingType.Checkbox,
            name = L["PLAYER_BUFFS_SORT_REVERSED"],
            desc = L["PLAYER_BUFFS_SORT_REVERSED_DESC"],
            default = false,
            get = function(layoutName)
                return GetLayoutValue(layoutName, "sortReversed", false)
            end,
            set = function(layoutName, value)
                -- nil instead of false keeps the default out of the saved variables.
                SetLayoutValue(layoutName, "sortReversed", value or nil)
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
    ns.Compat.OnAddOnRestrictionChanged(function()
        if updatePending then
            UpdateAuras()
        end
    end)

    ApplyLayout()
end
