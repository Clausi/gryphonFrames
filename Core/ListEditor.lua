local _, ns = ...
local L = ns.L

-- A small dialog to edit a list of text entries, one per line (e.g. the buff whitelist of
-- Modules/PlayerBuffs.lua). Opened from the options with ns.ListEditor:Open().
--
-- Own frame, not shown through Blizzard's panel manager (ShowUIPanel), so it also works in combat.
-- The settings panel stays open below it. Escape in the text field or the close button cancels,
-- "Save" passes the entries to the callback.
local ListEditor = {}
ns.ListEditor = ListEditor

local WIDTH, HEIGHT = 360, 340
local PADDING = 12
local BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
local INPUT_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local frame
local onSave

-- Lines of the text without surrounding spaces and without empty lines.
local function ParseLines(text)
    local entries = {}
    for line in text:gmatch("[^\r\n]+") do
        line = strtrim(line)
        if line ~= "" then
            entries[#entries + 1] = line
        end
    end
    return entries
end

local function Close()
    frame:Hide()
    onSave = nil
end

local function Save()
    local callback = onSave
    local entries = ParseLines(frame.EditBox:GetText())
    Close()
    if callback then
        callback(entries)
    end
end

local function CreateButton(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(100, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreateEditor()
    frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetBackdrop(BACKDROP)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.Title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.Title:SetPoint("TOP", 0, -PADDING - 4)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", Close)

    frame.Description = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.Description:SetPoint("TOPLEFT", PADDING + 6, -PADDING - 24)
    frame.Description:SetPoint("TOPRIGHT", -PADDING - 6, -PADDING - 24)
    frame.Description:SetJustifyH("LEFT")

    local save = CreateButton(frame, L["LIST_EDITOR_SAVE"], Save)
    save:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, PADDING + 4)
    local cancel = CreateButton(frame, CANCEL, Close)
    cancel:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, PADDING + 4)

    local input = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    input:SetBackdrop(INPUT_BACKDROP)
    input:SetBackdropColor(0, 0, 0, 0.8)
    input:SetBackdropBorderColor(0.6, 0.6, 0.6)
    input:SetPoint("TOPLEFT", frame.Description, "BOTTOMLEFT", -4, -8)
    input:SetPoint("BOTTOMRIGHT", -PADDING - 2, PADDING + 32)

    local scroll = CreateFrame("ScrollFrame", nil, input, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(WIDTH - 2 * PADDING - 48)
    editBox:SetScript("OnEscapePressed", Close)
    scroll:SetScrollChild(editBox)
    frame.EditBox = editBox

    -- A click anywhere in the field puts the cursor into the text, also below the last line.
    input:EnableMouse(true)
    input:SetScript("OnMouseDown", function()
        editBox:SetFocus()
    end)
end

-- Opens the editor with one line per entry. onSaveCallback(entries) gets the new list on "Save".
function ListEditor:Open(title, description, entries, onSaveCallback)
    if not frame then
        CreateEditor()
    end
    onSave = onSaveCallback
    frame.Title:SetText(title)
    frame.Description:SetText(description)
    local lines = {}
    for i, entry in ipairs(entries) do
        lines[i] = tostring(entry)
    end
    frame.EditBox:SetText(table.concat(lines, "\n"))
    frame:Show()
    frame.EditBox:SetFocus()
    frame.EditBox:SetCursorPosition(0)
end
