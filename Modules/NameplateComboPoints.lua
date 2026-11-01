local _, ns = ...
local L = ns.L

-- Shows the player's combo points on the target's nameplate as well, above the name or below the
-- nameplate.
--
-- Blizzard shows combo points only at the target frame (ComboFrame), on all supported clients: the
-- nameplate class bars of Blizzard_NamePlates are Mainline only, and Forever leaves out the rogue
-- and druid bars. This module adds an own row of points to the target's nameplate and leaves
-- Blizzard's ComboFrame untouched. Combo points are stored on the target, so the row follows target
-- changes like Blizzard's ComboFrame (GetComboPoints("player", "target")).
--
-- Turned on per character in the options (Modules/Options.lua) or with "/gryphonframes combo on"
-- (ns.charDb.nameplateComboPoints). The size is a scale of the whole row
-- (ns.charDb.nameplateComboPointsScale) on top of the nameplate's own scale. Position, gap and
-- horizontal position are ns.charDb.nameplateComboPointsPosition, ...Gap and ...OffsetX.
local NameplateComboPoints = ns:RegisterModule("NameplateComboPoints")

-- Size of ComboPointTemplate (Blizzard_UnitFrame/Classic/ComboFrame.xml) at scale 1.
local POINT_SIZE = 12
local MIN_SCALE, MAX_SCALE, SCALE_STEP = 0.5, 3, 0.1
NameplateComboPoints.MIN_SCALE = MIN_SCALE
NameplateComboPoints.MAX_SCALE = MAX_SCALE
NameplateComboPoints.SCALE_STEP = SCALE_STEP
local SPACING = 2

-- Where the row sits: above the name, or below the health bar (below the cast bar while the target
-- casts).
NameplateComboPoints.POSITIONS = { "above", "below" }
-- Gap in pixels of the nameplate between the row and the name, health bar or cast bar.
NameplateComboPoints.MIN_GAP, NameplateComboPoints.MAX_GAP = 0, 40
-- Horizontal position in percent of the free space within the width of the health bar: -100 is
-- flush left, 0 centered, 100 flush right.
NameplateComboPoints.MIN_OFFSET_X, NameplateComboPoints.MAX_OFFSET_X = -100, 100

local row
local points = {}

local function GetPoint(index)
    local point = points[index]
    if not point then
        point = CreateFrame("Frame", nil, row)
        point:SetSize(POINT_SIZE, POINT_SIZE)
        ns.Compat.SetupComboPoint(point)
        points[index] = point
    end
    return point
end

-- Shows maxPoints points in a centered row, the first comboPoints of them filled.
local function UpdatePoints(comboPoints, maxPoints)
    row:SetSize(maxPoints * POINT_SIZE + (maxPoints - 1) * SPACING, POINT_SIZE)
    for index = 1, math.max(maxPoints, #points) do
        local point = GetPoint(index)
        if index <= maxPoints then
            point:ClearAllPoints()
            point:SetPoint("LEFT", row, "LEFT", (index - 1) * (POINT_SIZE + SPACING), 0)
            point.Active:SetShown(index <= comboPoints)
            point:Show()
        else
            point:Hide()
        end
    end
end

-- The layout of a nameplate depends on its style (CVar "nameplateStyle": Modern, Thin, Block,
-- Health Focus, Cast Focus, Legacy, Classic). NamePlateDriverMixin:UpdateNamePlateOptions()
-- (Blizzard_NamePlates.lua) turns the style into NamePlateSetupOptions, and
-- NamePlateUnitFrameMixin (Blizzard_NamePlateUnitFrame.lua) anchors the parts from them. The row
-- reads the result instead of mirroring the styles:
-- - the health bar itself: with the Classic style it is narrower than its container, which keeps
--   room for the level on the right, so the row is placed relative to the bar;
-- - the name: inside the health bar (Modern, Block) or above it (all other styles).

local function GetHealthBar(namePlate)
    local container = namePlate.UnitFrame and namePlate.UnitFrame.HealthBarsContainer
    return container and (container.healthBar or container)
end

-- Width of the health bar, or nil while it is not laid out yet (right after NAME_PLATE_UNIT_ADDED)
-- or hidden by the client.
local function GetHealthBarWidth(namePlate)
    local healthBar = GetHealthBar(namePlate)
    local width = healthBar and healthBar:GetWidth()
    if not width or ns.Compat.IsSecret(width) or width <= 0 then
        return nil
    end
    return width
end

-- Height the name takes above the health bar (spacing and one line), or 0 if the style shows it
-- inside the bar or it is hidden.
local function GetNameHeightAbove(namePlate)
    local name = namePlate.UnitFrame and namePlate.UnitFrame.name
    if not name or not NamePlateSetupOptions or not NamePlateConstants
        or NamePlateSetupOptions.unitNameAnchorStyle == NamePlateConstants.NAME_ANCHOR_STYLES.InsideHealthBar then
        return 0
    end
    local nameShown = name:IsShown()
    local height = name:GetHeight()
    if ns.Compat.IsSecret(nameShown) or not nameShown or ns.Compat.IsSecret(height) then
        return 0
    end
    return (NamePlateSetupOptions.healthBarToNameAboveSpacing or 0) + height
end

-- Cast bar of the nameplate (BaseNamePlateUnitFrameTemplate, Blizzard_NamePlates.xml).
local function GetCastBar(namePlate)
    local castBars = namePlate.UnitFrame and namePlate.UnitFrame.CastBarsContainer
    return castBars and castBars.castBar
end

local function IsCastBarShown(namePlate)
    local castBar = GetCastBar(namePlate)
    local castBarShown = castBar and castBar:IsShown()
    return castBarShown and not ns.Compat.IsSecret(castBarShown) or false
end

-- Factor from the health bar's coordinates to the row's own coordinates (the row has its own
-- scale on top of the nameplate's).
local function GetScaleFactor(healthBar)
    local barScale, rowScale = healthBar:GetEffectiveScale(), row:GetEffectiveScale()
    if ns.Compat.IsSecret(barScale) or ns.Compat.IsSecret(rowScale) then
        return 1 / ns.charDb.nameplateComboPointsScale
    end
    return barScale / rowScale
end

-- Places the row above the name (or above the health bar, if the name is inside it), or below the
-- health bar and, while the target casts, below the cast bar. Horizontally it is placed within the
-- width of the health bar. The row is parented to the nameplate, so it follows its position, scale
-- and visibility like Blizzard's own nameplate class bars.
local function AttachTo(namePlate, layout)
    local healthBar = GetHealthBar(namePlate)
    row:SetParent(namePlate)
    row:SetFrameLevel(namePlate:GetFrameLevel() + 10)
    row:SetScale(ns.charDb.nameplateComboPointsScale)
    row:ClearAllPoints()
    if not healthBar then
        row:SetPoint("BOTTOM", namePlate, "TOP")
        return
    end

    local factor = GetScaleFactor(healthBar)
    local x = 0
    if layout.healthBarWidth then
        local freeSpace = math.max(layout.healthBarWidth * factor - row:GetWidth(), 0)
        x = ns.charDb.nameplateComboPointsOffsetX / 100 * freeSpace / 2
    end
    local gap = ns.charDb.nameplateComboPointsGap * factor

    if ns.charDb.nameplateComboPointsPosition == "below" then
        local castBar = layout.castBarShown and GetCastBar(namePlate)
        if castBar then
            -- The cast bar is not always centered below the health bar (Classic style), so x is
            -- moved by the distance between their centers to stay relative to the health bar.
            local barX = healthBar:GetCenter()
            local castBarX = castBar:GetCenter()
            if barX and castBarX and not ns.Compat.IsSecret(barX) and not ns.Compat.IsSecret(castBarX) then
                x = x + (barX - castBarX) * factor
            end
            row:SetPoint("TOP", castBar, "BOTTOM", x, -gap)
        else
            row:SetPoint("TOP", healthBar, "BOTTOM", x, -gap)
        end
    else
        row:SetPoint("BOTTOM", healthBar, "TOP", x, gap + layout.nameHeight * factor)
    end
end

-- What the row currently shows. Most events (energy ticks, other nameplates) change nothing, and
-- then Update() stops before touching any frame. The setters clear it, so new settings are applied.
local shown = {}

local Update

-- Below the nameplate, the row moves under the cast bar while it is shown. Blizzard reuses
-- nameplate frames, so each cast bar is hooked once; the hooks only run Update().
local hookedCastBars = {}

local function HookCastBar(namePlate)
    local castBar = GetCastBar(namePlate)
    if castBar and not hookedCastBars[castBar] then
        hookedCastBars[castBar] = true
        castBar:HookScript("OnShow", function()
            Update()
        end)
        castBar:HookScript("OnHide", function()
            Update()
        end)
    end
end

function Update()
    if not row then
        return
    end

    -- Forbidden nameplates (e.g. friendly ones in instances) are not returned to addon code.
    local namePlate = ns.charDb.nameplateComboPoints and C_NamePlate.GetNamePlateForUnit("target")
    local comboPoints = namePlate and GetComboPoints("player", "target") or 0
    if ns.Compat.IsSecret(comboPoints) or comboPoints == 0 then
        if shown.namePlate then
            wipe(shown)
            row:Hide()
        end
        return
    end

    local maxPoints = math.max(UnitPowerMax("player", Enum.PowerType.ComboPoints), comboPoints)
    -- The sizes may change after the nameplate appeared (layout not done yet), so they are part of
    -- what is compared.
    local healthBarWidth = GetHealthBarWidth(namePlate)
    local castBarShown, nameHeight = false, 0
    if ns.charDb.nameplateComboPointsPosition == "below" then
        HookCastBar(namePlate)
        castBarShown = IsCastBarShown(namePlate)
    else
        nameHeight = GetNameHeightAbove(namePlate)
    end
    if namePlate == shown.namePlate and comboPoints == shown.comboPoints and maxPoints == shown.maxPoints
        and healthBarWidth == shown.healthBarWidth and castBarShown == shown.castBarShown
        and nameHeight == shown.nameHeight then
        return
    end
    shown.namePlate, shown.comboPoints, shown.maxPoints = namePlate, comboPoints, maxPoints
    shown.healthBarWidth, shown.castBarShown, shown.nameHeight = healthBarWidth, castBarShown, nameHeight

    UpdatePoints(comboPoints, maxPoints)
    AttachTo(namePlate, shown)
    row:Show()
end

-- Places the row again, e.g. after a setting or the nameplate style changed.
local function Refresh()
    if row then
        wipe(shown)
        row:Hide()
    end
    Update()
end

-- Saves a setting and applies it right away.
local function SetSetting(key, value)
    ns.charDb[key] = value
    Refresh()
end

-- Blizzard lays out all nameplates again in UpdateNamePlateOptions() when the style, size or
-- another nameplate option changes (CVAR_UPDATE). Blizzard_NamePlates is loaded with the UI, but
-- is hooked on ADDON_LOADED in case a client loads it later.
local function HookNamePlateOptions()
    if NamePlateDriverFrame then
        hooksecurefunc(NamePlateDriverFrame, "UpdateNamePlateOptions", Refresh)
        return true
    end
    return false
end

function NameplateComboPoints:IsEnabled()
    return ns.charDb.nameplateComboPoints
end

function NameplateComboPoints:SetEnabled(enabled)
    SetSetting("nameplateComboPoints", enabled)
end

function NameplateComboPoints:GetScale()
    return ns.charDb.nameplateComboPointsScale
end

-- Sets the size of the row (between MIN_SCALE and MAX_SCALE).
function NameplateComboPoints:SetScale(scale)
    SetSetting("nameplateComboPointsScale", math.min(math.max(scale, MIN_SCALE), MAX_SCALE))
end

-- "above" or "below", see POSITIONS.
function NameplateComboPoints:GetPosition()
    return ns.charDb.nameplateComboPointsPosition
end

function NameplateComboPoints:SetPosition(position)
    SetSetting("nameplateComboPointsPosition", position == "below" and "below" or "above")
end

function NameplateComboPoints:GetGap()
    return ns.charDb.nameplateComboPointsGap
end

-- Sets the gap in pixels (between MIN_GAP and MAX_GAP).
function NameplateComboPoints:SetGap(gap)
    SetSetting("nameplateComboPointsGap", math.min(math.max(gap, self.MIN_GAP), self.MAX_GAP))
end

function NameplateComboPoints:GetOffsetX()
    return ns.charDb.nameplateComboPointsOffsetX
end

-- Sets the horizontal position in percent (between MIN_OFFSET_X and MAX_OFFSET_X).
function NameplateComboPoints:SetOffsetX(offset)
    SetSetting("nameplateComboPointsOffsetX", math.min(math.max(offset, self.MIN_OFFSET_X), self.MAX_OFFSET_X))
end

ns:RegisterCommand("combo", function(args)
    local value = args:lower()
    if value == "on" then
        NameplateComboPoints:SetEnabled(true)
    elseif value == "off" then
        NameplateComboPoints:SetEnabled(false)
    elseif value ~= "" then
        ns:Print(L["HELP_COMBO"])
        return
    end
    ns:Print(NameplateComboPoints:IsEnabled() and L["COMBO_ON"] or L["COMBO_OFF"])
end, { L["HELP_COMBO"] })

function NameplateComboPoints:OnEnable()
    row = CreateFrame("Frame", nil, UIParent)
    row:Hide()

    ns:RegisterEvent("PLAYER_TARGET_CHANGED", Update)
    -- Moving the points to a new target keeps the count, so no power event fires.
    ns:RegisterEvent("COMBO_TARGET_CHANGED", Update)
    ns:RegisterEvent("UNIT_POWER_FREQUENT", function(_, unit)
        if unit == "player" then
            Update()
        end
    end)
    ns:RegisterEvent("UNIT_MAXPOWER", function(_, unit)
        if unit == "player" then
            Update()
        end
    end)
    -- The target's nameplate appears and disappears with distance and line of sight, and Blizzard
    -- reuses nameplate frames for other units.
    ns:RegisterEvent("NAME_PLATE_UNIT_ADDED", Update)
    ns:RegisterEvent("NAME_PLATE_UNIT_REMOVED", Update)

    if not HookNamePlateOptions() then
        local hooked = false
        ns:RegisterEvent("ADDON_LOADED", function(_, addonName)
            if not hooked and addonName == "Blizzard_NamePlates" then
                hooked = HookNamePlateOptions()
            end
        end)
    end

    Update()
end
