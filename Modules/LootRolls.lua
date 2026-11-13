local _, ns = ...
local L = ns.L

-- Improves group loot rolls in two ways, each on by default and set per character:
-- - A panel next to each of Blizzard's roll frames lists who chose need, greed or pass
--   (ns.charDb.lootRollChoices, "/gryphonframes rolls off").
-- - A small scrolling window keeps the finished rolls, grouped by item, newest first
--   (ns.charDb.lootRollResults, "/gryphonframes rollresults off"). A roll already shows there once
--   the player made an own choice, with the players still to choose, and becomes its result when it
--   ends. The window can close by itself ns.charDb.lootRollResultsAutoClose seconds after the last
--   result while no roll runs, 0 keeps it open.
--
-- Position, size and look of the window are saved per Edit Mode layout in
-- ns.db.lootRolls.layouts[layoutName], the settings follow those of the window of GryphonThreat.
-- In Edit Mode, the window stays open and shows a made-up result while it has none. Dragging it
-- moves it, and the handle in its corner sizes it. It is an own frame, not protected, so this also
-- works in combat; Edit Mode itself does not.
--
-- The data comes from C_LootHistory, the source of Blizzard's own loot history
-- (Blizzard_FrameXML/Mainline/LootHistory.lua). A drop there has no roll ID, so a roll frame finds
-- its drop by the item. With two drops of one item, the frames may show them swapped.
--
-- Blizzard hides a roll frame after the own choice, and its panel with it. The gamepad UI has its
-- own roll frames (GamepadGroupLootRollFrame), which get no panel.
local LootRolls = ns:RegisterModule("LootRolls")

local LibEditMode = LibStub("LibEditMode")

local NUM_ROLL_FRAMES = 4
local DEFAULT_POSITION = { point = "CENTER", x = 0, y = 200 }
LootRolls.MAX_AUTO_CLOSE, LootRolls.AUTO_CLOSE_STEP = 120, 5

-- The panel has the art of GroupLootFrameBaseTemplate (Blizzard_UIPanels_Game/Mainline/
-- GroupLootFrame.xml) and its height. The border is 9 pixels larger than the frame it surrounds.
local PANEL_WIDTH, PANEL_HEIGHT, PANEL_GAP, PANEL_PADDING, PANEL_LINE_HEIGHT = 210, 67, 10, 12, 18
local PANEL_BORDER_OUTSET = 9
local LOOT_ART = "Interface\\LootFrame\\LootToast"
-- Only the right part of the background: its left part has the wells of the icon and the name.
local PANEL_BACKGROUND_COORDS = { 0.46777344, 0.55273438, 0.30859375, 0.57031250 }
local PANEL_BORDER_COORDS = { 0.00097656, 0.28027344, 0.43750000, 0.73437500 }
local WINDOW_PADDING, WINDOW_HEADER = 8, 26
local MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT = 200, 100, 600, 800
-- Edit Mode settings of the window. opacity, background and textSize are percent.
local LAYOUT_DEFAULTS = {
    width = 290,
    height = 220,
    padding = 8,
    opacity = 100,
    background = 85,
    textSize = 100,
    itemIcons = true,
    classColors = true,
}
local RESIZE_HANDLE_SIZE = 32
-- The scroll bar sits in the space right of the content.
local SCROLL_BAR_SPACE = 24
local ITEM_HEIGHT, ICON_SIZE, LINE_HEIGHT = 32, 28, 16
local ROLL_ICON_SIZE = 16
local WINNER_COLOR = "ff40ff40"
-- The oldest result goes when a new one does not fit.
local MAX_RESULTS = 50
local BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local RollState = Enum.EncounterLootDropRollState
-- Blizzard's roll icons, as in the tooltip of its loot history (LootHistoryRollTooltipLineMixin).
local PASS_ICON = CreateAtlasMarkup("lootroll-icon-pass", ROLL_ICON_SIZE, ROLL_ICON_SIZE)
local STATE_ICONS = {
    [RollState.NeedMainSpec] = CreateAtlasMarkup("lootroll-icon-need", ROLL_ICON_SIZE, ROLL_ICON_SIZE),
    [RollState.Greed] = CreateAtlasMarkup("lootroll-icon-greed", ROLL_ICON_SIZE, ROLL_ICON_SIZE),
    [RollState.Transmog] = CreateAtlasMarkup("lootroll-icon-transmog", ROLL_ICON_SIZE, ROLL_ICON_SIZE),
    [RollState.Pass] = PASS_ICON,
}
STATE_ICONS[RollState.NeedOffSpec] = STATE_ICONS[RollState.NeedMainSpec]
-- Choices in the order of the panel. Transmog counts as greed, it ranks the same.
local PASS_CHOICE = { icon = PASS_ICON, color = "ffa0a0a0", states = { RollState.Pass } }
local CHOICES = {
    {
        icon = STATE_ICONS[RollState.NeedMainSpec], color = "ff40ff40",
        states = { RollState.NeedMainSpec, RollState.NeedOffSpec },
    },
    { icon = STATE_ICONS[RollState.Greed], color = "ffffd100", states = { RollState.Greed, RollState.Transmog } },
    PASS_CHOICE,
}

local panels = {}
local window, scrollFrame, content
local isEditing = false
-- Frames of the item groups in the window, reused from top to bottom.
local groups = {}
-- Entries of the window, oldest first: { key = drop key, dropInfo = drop info, running = true while
-- the roll runs }. The sample has no key.
local results = {}
local closeTimer
-- Running rolls: drop info by drop key. A drop in the history only becomes a result if it was seen
-- running, so finished drops of the history do not open the window after a loading screen.
local runningDrops = {}
-- Drop key by roll ID, once a roll frame found its drop.
local rollDropKeys = {}

local function GetDropKey(encounterID, lootListKey)
    return encounterID .. ":" .. lootListKey
end

local function GetItemId(link)
    return link and link:match("item:(%d+)")
end

local function GetColoredName(rollInfo)
    local color = RAID_CLASS_COLORS[rollInfo.playerClass]
    return color and color:WrapTextInColorCode(rollInfo.playerName) or rollInfo.playerName
end

-- Icon of the choice with the roll number, or only the icon without a number.
local function GetRollText(rollInfo)
    local icon = STATE_ICONS[rollInfo.state] or ""
    return rollInfo.roll and format("%s %d", icon, rollInfo.roll) or icon
end

local function IsFinished(dropInfo)
    return dropInfo.winner or dropInfo.allPassed
end

-- "Waiting on:" with the players who did not choose yet, as in Blizzard's loot history; nil once
-- the roll ended or everybody chose.
local function GetWaitingText(dropInfo, plainNames)
    if IsFinished(dropInfo) then
        return nil
    end
    local names = {}
    for _, rollInfo in ipairs(dropInfo.rollInfos) do
        if rollInfo.state == RollState.NoRoll then
            names[#names + 1] = plainNames and rollInfo.playerName or GetColoredName(rollInfo)
        end
    end
    if #names == 0 then
        return nil
    end
    return LOOT_HISTORY_WAITING_ON .. table.concat(names, LOOT_HISTORY_PLAYER_DELIMITER)
end

-- Lists all players who made a choice, in Blizzard's order, and those still to choose.
local function ShowRollsTooltip(owner, dropInfo)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(dropInfo.itemHyperlink)
    if dropInfo.allPassed then
        GameTooltip:AddLine(LOOT_HISTORY_ALL_PASSED, 1, 0.1, 0.1)
    end
    for _, rollInfo in ipairs(dropInfo.rollInfos) do
        if rollInfo.state ~= RollState.NoRoll then
            GameTooltip:AddDoubleLine(GetColoredName(rollInfo), GetRollText(rollInfo), 1, 1, 1, 1, 1, 1)
        end
    end
    local waiting = GetWaitingText(dropInfo)
    if waiting then
        GameTooltip:AddLine(waiting, 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

-- The running drop of a roll. Each drop goes to one roll only, in the order of the rolls.
local function FindDrop(rollID)
    local key = rollDropKeys[rollID]
    if key then
        return runningDrops[key]
    end
    local itemId = GetItemId(GetLootRollItemLink(rollID))
    if not itemId then
        return nil
    end
    local taken = {}
    for _, dropKey in pairs(rollDropKeys) do
        taken[dropKey] = true
    end
    for dropKey, dropInfo in pairs(runningDrops) do
        if not taken[dropKey] and GetItemId(dropInfo.itemHyperlink) == itemId then
            rollDropKeys[rollID] = dropKey
            return dropInfo
        end
    end
    return nil
end

-- Icon of the choice, its count and the names, nil if nobody made this choice.
local function GetChoiceText(dropInfo, choice, plainNames)
    local names = {}
    for _, rollInfo in ipairs(dropInfo.rollInfos) do
        for _, state in ipairs(choice.states) do
            if rollInfo.state == state then
                names[#names + 1] = plainNames and rollInfo.playerName or GetColoredName(rollInfo)
            end
        end
    end
    if #names == 0 then
        return nil
    end
    return format("%s |c%s(%d):|r %s", choice.icon, choice.color, #names, table.concat(names, ", "))
end

local function UpdatePanel(panel)
    local frame = panel:GetParent()
    local dropInfo = ns.charDb.lootRollChoices and frame.rollID and FindDrop(frame.rollID)
    panel.dropInfo = dropInfo
    -- Only the choices someone made, centered in the panel.
    local texts = {}
    for _, choice in ipairs(dropInfo and CHOICES or {}) do
        texts[#texts + 1] = GetChoiceText(dropInfo, choice)
    end
    local top = -(PANEL_HEIGHT - #texts * PANEL_LINE_HEIGHT) / 2
    for i, line in ipairs(panel.lines) do
        local y = top - (i - 1) * PANEL_LINE_HEIGHT
        line:SetPoint("TOPLEFT", PANEL_PADDING, y)
        line:SetPoint("TOPRIGHT", -PANEL_PADDING, y)
        line:SetText(texts[i] or "")
    end
    -- The border takes the quality color, which Blizzard sets on the border of the roll frame.
    panel.Border:SetVertexColor(frame.Border:GetVertexColor())
    panel:SetShown(#texts > 0)
end

local function UpdatePanels()
    for _, panel in ipairs(panels) do
        if panel:GetParent():IsShown() then
            UpdatePanel(panel)
        end
    end
end

-- A child of the roll frame, so it hides with it. Blizzard's frame itself is not changed.
local function CreatePanel(frame)
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetPoint("LEFT", frame, "RIGHT", PANEL_GAP, 0)
    panel:EnableMouse(true)

    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(LOOT_ART)
    background:SetTexCoord(unpack(PANEL_BACKGROUND_COORDS))
    background:SetAllPoints()

    panel.Border = panel:CreateTexture(nil, "BORDER")
    panel.Border:SetTexture(LOOT_ART)
    panel.Border:SetTexCoord(unpack(PANEL_BORDER_COORDS))
    panel.Border:SetSize(PANEL_WIDTH + PANEL_BORDER_OUTSET, PANEL_HEIGHT + PANEL_BORDER_OUTSET)
    panel.Border:SetPoint("CENTER")

    panel:Hide()
    panel.lines = {}
    for i = 1, #CHOICES do
        -- One line each: a long list ends in "...", the tooltip has all names.
        local line = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        panel.lines[i] = line
    end
    panel:SetScript("OnEnter", function(self)
        if self.dropInfo then
            ShowRollsTooltip(self, self.dropInfo)
        end
    end)
    panel:SetScript("OnLeave", HideTooltip)
    frame:HookScript("OnShow", function()
        UpdatePanel(panel)
    end)
    return panel
end

local function CancelCloseTimer()
    if closeTimer then
        closeTimer:Cancel()
        closeTimer = nil
    end
end

local function GetLayouts()
    return ns.db.lootRolls.layouts
end

-- Settings of the layout. Without a layout yet (early at login), the defaults.
local function GetLayout(layoutName)
    layoutName = layoutName or LibEditMode:GetActiveLayoutName()
    if not layoutName then
        return LAYOUT_DEFAULTS
    end
    local layout = ns.ApplyDefaults(GetLayouts()[layoutName] or {}, LAYOUT_DEFAULTS)
    GetLayouts()[layoutName] = layout
    return layout
end

-- A made-up result, for Edit Mode and "/gryphonframes rollresults test".
local function CreateSampleDrop()
    local _, class = UnitClass("player")
    local winner = {
        playerName = UnitName("player"), playerClass = class, state = RollState.NeedMainSpec, roll = 87,
        isWinner = true,
    }
    return {
        itemHyperlink = "|cffffffff|Hitem:6948::::::::::::::::|h[Hearthstone]|h|r",
        winner = winner,
        rollInfos = {
            winner,
            { playerName = UNKNOWN, playerClass = class, state = RollState.Greed, roll = 42 },
            { playerName = UNKNOWN, playerClass = class, state = RollState.Pass },
        },
    }
end

-- Line i of a group: player on the left, roll on the right. Created on first use.
local function GetLine(group, index)
    local line = group.lines[index]
    if not line then
        line = {}
        line.Roll = group:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        line.Name = group:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        line.Name:SetJustifyH("LEFT")
        line.Name:SetWordWrap(false)
        group.lines[index] = line
    end
    return line
end

local function SetLine(group, index, y, scale, name, roll)
    local line = GetLine(group, index)
    line.Roll:SetPoint("TOPRIGHT", 0, y)
    line.Name:SetPoint("TOPLEFT", 0, y)
    line.Name:SetPoint("TOPRIGHT", line.Roll, "TOPLEFT", -6, 0)
    line.Name:SetTextScale(scale)
    line.Roll:SetTextScale(scale)
    line.Name:SetText(name)
    line.Roll:SetText(roll)
    line.Name:Show()
    line.Roll:Show()
end

-- Fills the group with the item and one line per roll, the winner marked. Passes share one line,
-- and so do the players still to choose of a running roll; such a line ends in "..." when it is
-- too long. Returns the height of the group.
local function UpdateGroup(group, dropInfo, layout)
    group.dropInfo = dropInfo
    local scale = layout.textSize / 100
    local lineHeight = LINE_HEIGHT * scale
    local itemHeight = layout.itemIcons and ITEM_HEIGHT or lineHeight + 4

    group.Icon:SetShown(layout.itemIcons)
    group.Icon.Texture:SetTexture(Item:CreateFromItemLink(dropInfo.itemHyperlink):GetItemIcon())
    group.Item:ClearAllPoints()
    if layout.itemIcons then
        group.Item:SetPoint("TOPLEFT", group.Icon, "TOPRIGHT", 6, 0)
    else
        group.Item:SetPoint("TOPLEFT")
    end
    group.Item:SetPoint("BOTTOMRIGHT", group, "TOPRIGHT", 0, -(layout.itemIcons and ICON_SIZE or itemHeight))
    group.Item:SetTextScale(scale)
    group.Item:SetText(dropInfo.itemHyperlink)

    local count = 0
    local function AddLine(name, roll)
        SetLine(group, count + 1, -itemHeight - count * lineHeight, scale, name, roll)
        count = count + 1
    end
    if dropInfo.allPassed then
        AddLine(LOOT_HISTORY_ALL_PASSED, PASS_ICON)
    end
    for _, rollInfo in ipairs(dropInfo.rollInfos) do
        if rollInfo.state ~= RollState.NoRoll and rollInfo.state ~= RollState.Pass then
            local roll = GetRollText(rollInfo)
            AddLine(layout.classColors and GetColoredName(rollInfo) or rollInfo.playerName,
                rollInfo.isWinner and format("|c%s%s|r", WINNER_COLOR, roll) or roll)
        end
    end
    local passes = not dropInfo.allPassed
        and GetChoiceText(dropInfo, PASS_CHOICE, not layout.classColors)
    if passes then
        AddLine(passes, "")
    end
    local waiting = GetWaitingText(dropInfo, not layout.classColors)
    if waiting then
        AddLine(waiting, "")
    end
    for i = count + 1, #group.lines do
        group.lines[i].Name:Hide()
        group.lines[i].Roll:Hide()
    end
    return itemHeight + count * lineHeight
end

local function OnDragStart()
    if not LibEditMode:IsInEditMode() then
        -- LibEditMode turns movable off again when it leaves Edit Mode with the window selected.
        window:SetMovable(true)
        window:StartMoving()
        window.isMoving = true
    end
end

-- The position of the top left corner: changing the size then keeps the window in place.
local function SavePosition()
    local layout = GetLayout()
    if layout ~= LAYOUT_DEFAULTS then
        layout.point, layout.x, layout.y = "TOPLEFT", window:GetLeft(), window:GetTop() - UIParent:GetHeight()
    end
end

local function OnDragStop()
    if window.isMoving then
        window.isMoving = false
        window:StopMovingOrSizing()
        SavePosition()
    end
end

local function CreateGroup()
    local group = CreateFrame("Frame", nil, content)
    group.lines = {}
    group:EnableMouse(true)
    -- The groups cover the window, so they move it like its free space does.
    group:RegisterForDrag("LeftButton")
    group:SetScript("OnDragStart", OnDragStart)
    group:SetScript("OnDragStop", OnDragStop)
    group:SetScript("OnEnter", function(self)
        ShowRollsTooltip(self, self.dropInfo)
    end)
    group:SetScript("OnLeave", HideTooltip)

    group.Icon = CreateFrame("Button", nil, group)
    group.Icon:SetSize(ICON_SIZE, ICON_SIZE)
    group.Icon:SetPoint("TOPLEFT")
    group.Icon.Texture = group.Icon:CreateTexture(nil, "ARTWORK")
    group.Icon.Texture:SetAllPoints()
    group.Icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(group.dropInfo.itemHyperlink)
        GameTooltip:Show()
    end)
    group.Icon:SetScript("OnLeave", HideTooltip)
    -- Shift-click links the item in chat.
    group.Icon:SetScript("OnClick", function()
        if IsModifiedClick() then
            HandleModifiedItemClick(group.dropInfo.itemHyperlink)
        end
    end)

    group.Item = group:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    group.Item:SetJustifyH("LEFT")
    group.Item:SetWordWrap(false)
    return group
end

-- Shows the results, newest first, or the sample in Edit Mode, and hides the window without any.
local function RefreshWindow()
    local shownResults = results
    if #results == 0 and isEditing and ns.charDb.lootRollResults then
        shownResults = { { dropInfo = CreateSampleDrop() } }
    end
    if #shownResults == 0 then
        window:Hide()
        return
    end
    local layout = GetLayout()
    local height = 0
    local index = 0
    for i = #shownResults, 1, -1 do
        index = index + 1
        local group = groups[index] or CreateGroup()
        groups[index] = group
        local groupHeight = UpdateGroup(group, shownResults[i].dropInfo, layout)
        group:ClearAllPoints()
        group:SetPoint("TOPLEFT", 0, -height)
        group:SetPoint("TOPRIGHT", 0, -height)
        group:SetHeight(groupHeight)
        group:Show()
        height = height + groupHeight + layout.padding
    end
    for i = index + 1, #groups do
        groups[i]:Hide()
    end
    content:SetHeight(height)
    window:Show()
end

local function CloseWindow()
    CancelCloseTimer()
    wipe(results)
    RefreshWindow()
end

-- Applies position, size and look of the active layout.
local function ApplyLayout()
    local layout = GetLayout()
    local position = layout.point and layout or DEFAULT_POSITION
    window:ClearAllPoints()
    window:SetPoint(position.point, UIParent, position.point, position.x, position.y)
    window:SetSize(layout.width, layout.height)
    window:SetAlpha(layout.opacity / 100)
    window:SetBackdropColor(0, 0, 0, layout.background / 100)
    window.Title:SetTextScale(layout.textSize / 100)
    RefreshWindow()
end

local function OnResizeStart(button, mouseButton)
    if mouseButton == "LeftButton" then
        -- StartSizing("BOTTOMRIGHT") only keeps the top left corner in place if the window is
        -- anchored there; a saved CENTER position would make it jump.
        local left, top = window:GetLeft(), window:GetTop()
        window:ClearAllPoints()
        window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        button:SetButtonState("PUSHED", true)
        window:StartSizing("BOTTOMRIGHT")
        window.isResizing = true
    end
end

local function OnResizeStop(button, mouseButton)
    if mouseButton ~= "LeftButton" or not window.isResizing then
        return
    end
    window.isResizing = false
    button:SetButtonState("NORMAL", false)
    window:StopMovingOrSizing()
    local layout = GetLayout()
    if layout ~= LAYOUT_DEFAULTS then
        layout.width, layout.height = floor(window:GetWidth() + 0.5), floor(window:GetHeight() + 0.5)
    end
    SavePosition()
    ApplyLayout()
    -- The width and height sliders show the new size.
    if isEditing then
        LibEditMode:RefreshFrameSettings(window)
    end
end

local function CreateWindow()
    -- Stays in the MEDIUM strata: the selection of Edit Mode is there (EditModeSystemSelectionBaseTemplate)
    -- and could not be clicked below a window in a higher strata.
    window = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    window:SetClampedToScreen(true)
    window:SetResizable(true)
    window:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", OnDragStart)
    window:SetScript("OnDragStop", OnDragStop)
    window:SetBackdrop(BACKDROP)
    window:SetBackdropBorderColor(0.4, 0.4, 0.4)
    window:Hide()

    window.Title = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    window.Title:SetPoint("TOPLEFT", WINDOW_PADDING, -WINDOW_PADDING)
    window.Title:SetText(L["LOOT_RESULTS_TITLE"])

    -- Not UIPanelCloseButton: its script goes through the panel manager, blocked in combat.
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButtonNoScripts")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", CloseWindow)

    scrollFrame = CreateFrame("ScrollFrame", nil, window, "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", WINDOW_PADDING, -WINDOW_HEADER)
    scrollFrame:SetPoint("BOTTOMRIGHT", -SCROLL_BAR_SPACE, WINDOW_PADDING)
    scrollFrame.ScrollBar:SetHideIfUnscrollable(true)
    content = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(content)
    window:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(width - WINDOW_PADDING - SCROLL_BAR_SPACE)
    end)

    -- The handle of Blizzard's damage meter, as in the window of GryphonThreat. The strata keeps it
    -- above the selection of Edit Mode.
    local resize = CreateFrame("Button", nil, window)
    resize:SetFrameStrata("DIALOG")
    resize:SetSize(RESIZE_HANDLE_SIZE, RESIZE_HANDLE_SIZE)
    resize:SetPoint("BOTTOMRIGHT", 4, -4)
    resize:SetNormalAtlas("damagemeters-scalehandle")
    resize:SetHighlightAtlas("damagemeters-scalehandle-hover")
    resize:SetPushedAtlas("damagemeters-scalehandle-pressed")
    resize:SetScript("OnMouseDown", OnResizeStart)
    resize:SetScript("OnMouseUp", OnResizeStop)
end

local function FindEntry(key)
    for _, entry in ipairs(results) do
        if key and entry.key == key then
            return entry
        end
    end
    return nil
end

local function IsAnyRollRunning()
    for _, entry in ipairs(results) do
        if entry.running then
            return true
        end
    end
    return false
end

-- While a roll runs, the window stays open. A new result starts the time again.
local function UpdateCloseTimer(restart)
    if IsAnyRollRunning() then
        CancelCloseTimer()
        return
    end
    if not restart and closeTimer then
        return
    end
    CancelCloseTimer()
    local seconds = ns.charDb.lootRollResultsAutoClose
    if seconds > 0 and #results > 0 then
        closeTimer = C_Timer.NewTimer(seconds, CloseWindow)
    end
end

-- Adds the drop to the window, or updates its entry there. key is nil for the sample.
local function ShowDrop(key, dropInfo)
    if not ns.charDb.lootRollResults then
        return
    end
    local finished = IsFinished(dropInfo) and true or false
    local entry = FindEntry(key)
    if entry then
        entry.dropInfo, entry.running = dropInfo, not finished
    else
        results[#results + 1] = { key = key, dropInfo = dropInfo, running = not finished }
        if #results > MAX_RESULTS then
            table.remove(results, 1)
        end
    end
    RefreshWindow()
    if not entry then
        -- The newest entry is at the top.
        scrollFrame:SetVerticalScroll(0)
    end
    UpdateCloseTimer(finished)
end

-- True once the player chose need, greed or pass for the drop.
local function HasOwnChoice(dropInfo)
    for _, rollInfo in ipairs(dropInfo.rollInfos) do
        if rollInfo.isSelf then
            return rollInfo.state ~= RollState.NoRoll
        end
    end
    return false
end

local function ForgetDrop(key)
    runningDrops[key] = nil
    for rollID, dropKey in pairs(rollDropKeys) do
        if dropKey == key then
            rollDropKeys[rollID] = nil
        end
    end
end

local function OnDropChanged(encounterID, dropInfo)
    local key = GetDropKey(encounterID, dropInfo.lootListKey)
    if not IsFinished(dropInfo) then
        runningDrops[key] = dropInfo
        if HasOwnChoice(dropInfo) then
            ShowDrop(key, dropInfo)
        end
    elseif runningDrops[key] then
        ForgetDrop(key)
        ShowDrop(key, dropInfo)
    end
end

local function IsTracking()
    return ns.charDb.lootRollChoices or ns.charDb.lootRollResults
end

local function OnUpdateDrop(_, encounterID, lootListKey)
    if IsTracking() then
        local dropInfo = C_LootHistory.GetSortedInfoForDrop(encounterID, lootListKey)
        if dropInfo then
            OnDropChanged(encounterID, dropInfo)
            UpdatePanels()
        end
    end
end

local function OnUpdateEncounter(_, encounterID)
    if IsTracking() then
        for _, dropInfo in ipairs(C_LootHistory.GetSortedDropsForEncounter(encounterID) or {}) do
            OnDropChanged(encounterID, dropInfo)
        end
        UpdatePanels()
    end
end

local function FormatPercent(value)
    return format("%d%%", value)
end

-- Blizzard hides the selection of a system while a slider that changes its look is dragged, so the
-- change can be seen. LibEditMode reuses the sliders of its dialog for every frame, so each gets
-- one hook, which looks at the setting it shows.
local function HookSliderPreview(widget, hookedWidgets)
    if hookedWidgets[widget] or not (widget.Slider and widget.Slider.RegisterCallback) then
        return
    end
    hookedWidgets[widget] = true
    local function OnInteract(alpha)
        if widget.setting and widget.setting.hideLootRollsSelection then
            window.Selection:SetAlpha(alpha)
        end
    end
    local events = MinimalSliderWithSteppersMixin.Event
    widget.Slider:RegisterCallback(events.OnInteractStart, function()
        OnInteract(0)
    end, hookedWidgets)
    widget.Slider:RegisterCallback(events.OnInteractEnd, function()
        OnInteract(1)
    end, hookedWidgets)
end

-- Uses LibEditMode's internal dialog, the library has no API for it. Without it, the selection just
-- stays visible.
local function HookSettingsDialog()
    local dialog = LibEditMode.internal and LibEditMode.internal.dialog
    if not dialog then
        return
    end
    local hookedWidgets = {}
    hooksecurefunc(dialog, "Update", function()
        for _, widget in ipairs(dialog.Settings.widgets or {}) do
            HookSliderPreview(widget, hookedWidgets)
        end
    end)
    dialog:HookScript("OnHide", function()
        window.Selection:SetAlpha(1)
    end)
end

-- LibEditMode callback after the window was dragged, moved with the arrow keys or reset.
local function OnPositionChanged(_, layoutName, point, x, y)
    if layoutName then
        local layout = GetLayout(layoutName)
        layout.point, layout.x, layout.y = point, x, y
        ApplyLayout()
    end
end

-- A setting stored in the layout under key, applied right away.
local function LayoutSetting(kind, key, name, extra)
    local setting = {
        kind = kind,
        name = name,
        default = LAYOUT_DEFAULTS[key],
        get = function(layoutName)
            return GetLayout(layoutName)[key]
        end,
        set = function(layoutName, value)
            GetLayout(layoutName)[key] = value
            ApplyLayout()
        end,
    }
    for field, value in pairs(extra or {}) do
        setting[field] = value
    end
    return setting
end

local function Slider(key, name, minValue, maxValue, valueStep, formatter, hideSelection)
    local setting = LayoutSetting(LibEditMode.SettingType.Slider, key, name, {
        minValue = minValue,
        maxValue = maxValue,
        valueStep = valueStep,
        formatter = formatter,
        hideLootRollsSelection = hideSelection,
    })
    local set = setting.set
    -- The slider may report rounding errors.
    setting.set = function(layoutName, value)
        set(layoutName, floor(value + 0.5))
    end
    return setting
end

local function RegisterEditMode()
    window.editModeName = L["LOOT_RESULTS_TITLE"]
    LibEditMode:AddFrame(window, OnPositionChanged, DEFAULT_POSITION, L["LOOT_RESULTS_TITLE"])
    LibEditMode:AddFrameSettings(window, {
        Slider("width", L["LOOT_SETTING_WIDTH"], MIN_WIDTH, MAX_WIDTH, 1),
        Slider("height", L["LOOT_SETTING_HEIGHT"], MIN_HEIGHT, MAX_HEIGHT, 1),
        Slider("padding", L["LOOT_SETTING_PADDING"], 0, 20, 1),
        Slider("opacity", L["LOOT_SETTING_OPACITY"], 50, 100, 1, FormatPercent, true),
        Slider("background", L["LOOT_SETTING_BACKGROUND"], 0, 100, 1, FormatPercent, true),
        Slider("textSize", L["LOOT_SETTING_TEXT_SIZE"], 50, 150, 10, FormatPercent),
        LayoutSetting(LibEditMode.SettingType.Checkbox, "itemIcons", L["LOOT_SETTING_ITEM_ICONS"]),
        LayoutSetting(LibEditMode.SettingType.Checkbox, "classColors", L["LOOT_SETTING_CLASS_COLORS"]),
    })
    -- AddFrame creates LibEditMode's dialog.
    HookSettingsDialog()

    LibEditMode:RegisterCallback("layout", ApplyLayout)
    LibEditMode:RegisterCallback("enter", function()
        isEditing = true
        RefreshWindow()
    end)
    LibEditMode:RegisterCallback("exit", function()
        isEditing = false
        RefreshWindow()
    end)
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

function LootRolls:AreChoicesEnabled()
    return ns.charDb.lootRollChoices
end

function LootRolls:SetChoicesEnabled(enabled)
    ns.charDb.lootRollChoices = enabled
    UpdatePanels()
end

function LootRolls:AreResultsEnabled()
    return ns.charDb.lootRollResults
end

function LootRolls:SetResultsEnabled(enabled)
    ns.charDb.lootRollResults = enabled
    if enabled then
        RefreshWindow()
    else
        CloseWindow()
    end
end

function LootRolls:GetAutoClose()
    return ns.charDb.lootRollResultsAutoClose
end

-- Seconds, 0 keeps the window open. Counts from the next result.
function LootRolls:SetAutoClose(seconds)
    ns.charDb.lootRollResultsAutoClose = seconds
end

ns:RegisterCommand("rolls", function(args)
    local value = args:lower()
    if value == "on" then
        LootRolls:SetChoicesEnabled(true)
    elseif value == "off" then
        LootRolls:SetChoicesEnabled(false)
    elseif value ~= "" then
        ns:Print(L["HELP_LOOT_ROLLS"])
        return
    end
    ns:Print(LootRolls:AreChoicesEnabled() and L["LOOT_ROLLS_ON"] or L["LOOT_ROLLS_OFF"])
end, { L["HELP_LOOT_ROLLS"] })

ns:RegisterCommand("rollresults", function(args)
    local value = args:lower()
    if value == "test" and LootRolls:AreResultsEnabled() then
        ShowDrop(nil, CreateSampleDrop())
        return
    elseif value == "on" then
        LootRolls:SetResultsEnabled(true)
    elseif value == "off" then
        LootRolls:SetResultsEnabled(false)
    elseif value ~= "" and value ~= "test" then
        ns:Print(L["HELP_LOOT_RESULTS"])
        return
    end
    ns:Print(LootRolls:AreResultsEnabled() and L["LOOT_RESULTS_ON"] or L["LOOT_RESULTS_OFF"])
end, { L["HELP_LOOT_RESULTS"] })

function LootRolls:OnEnable()
    for i = 1, NUM_ROLL_FRAMES do
        local frame = _G["GroupLootFrame" .. i]
        if frame then
            panels[#panels + 1] = CreatePanel(frame)
        else
            ns:Debug("GroupLootFrame%d not found, its rolls show no choices.", i)
        end
    end

    CreateWindow()
    RegisterEditMode()
    ApplyLayout()

    ns:RegisterEvent("LOOT_HISTORY_UPDATE_DROP", OnUpdateDrop)
    ns:RegisterEvent("LOOT_HISTORY_UPDATE_ENCOUNTER", OnUpdateEncounter)
    ns:RegisterEvent("LOOT_HISTORY_CLEAR_HISTORY", function()
        wipe(runningDrops)
        wipe(rollDropKeys)
        -- Their result will not come anymore.
        for i = #results, 1, -1 do
            if results[i].running then
                table.remove(results, i)
            end
        end
        RefreshWindow()
        UpdateCloseTimer(false)
    end)
end
