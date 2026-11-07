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

-- Look of the points: "modern" like the combo points of the modern unit frames, "classic" like
-- the Classic ComboFrame.
NameplateComboPoints.STYLES = { "modern", "classic" }

local COMBO_POINT_TEXTURE = "Interface\\ComboFrame\\ComboPoint"

local row
-- Points per style, created on first use. A style change hides the points of the other style.
local pointsByStyle = {}

-- Each style fills a point (POINT_SIZE x POINT_SIZE) with its empty socket and adds:
--   point.Active  -- frame with the filled point, faded and scaled by the transitions
--   point.Glow    -- texture that flashes when the point fills

-- Like ComboPointTemplate (Blizzard_UnitFrame/Classic/ComboFrame.xml): socket, gem (Highlight)
-- and the Shine that ComboFrame_Update() flashes on a new point.
local function SetupClassic(point)
    local socket = point:CreateTexture(nil, "BACKGROUND")
    socket:SetTexture(COMBO_POINT_TEXTURE)
    socket:SetSize(12, 16)
    socket:SetPoint("TOPLEFT")
    socket:SetTexCoord(0, 0.375, 0, 1)

    local gem = point.Active:CreateTexture(nil, "ARTWORK")
    gem:SetTexture(COMBO_POINT_TEXTURE)
    gem:SetSize(8, 16)
    gem:SetPoint("TOPLEFT", 2, 0)
    gem:SetTexCoord(0.375, 0.5625, 0, 1)

    point.Glow = point:CreateTexture(nil, "OVERLAY")
    point.Glow:SetTexture(COMBO_POINT_TEXTURE)
    point.Glow:SetSize(14, 16)
    point.Glow:SetPoint("TOPLEFT", 0, 4)
    point.Glow:SetTexCoord(0.5625, 1, 0, 1)
    point.Glow:SetBlendMode("ADD")
end

-- Blizzard's modern combo point (RogueComboPointTemplate, Blizzard_UnitFrame/Mainline/
-- RogueComboPoint.xml): BGInactive, BGActive with IconUncharged on top, and BGGlow.
local function SetupModern(point)
    local socket = point:CreateTexture(nil, "BACKGROUND")
    socket:SetAtlas("uf-roguecp-bg-dis")
    socket:SetAllPoints()

    local background = point.Active:CreateTexture(nil, "BORDER")
    background:SetAtlas("uf-roguecp-bg")
    background:SetAllPoints()
    local gem = point.Active:CreateTexture(nil, "ARTWORK")
    gem:SetAtlas("uf-roguecp-icon-red")
    gem:SetAllPoints()

    point.Glow = point:CreateTexture(nil, "OVERLAY")
    point.Glow:SetAtlas("uf-roguecp-bg")
    point.Glow:SetPoint("TOPLEFT", -2, 2)
    point.Glow:SetPoint("BOTTOMRIGHT", 2, -2)
    point.Glow:SetBlendMode("ADD")
end

local function CreateAlpha(group, fromAlpha, toAlpha, duration, order)
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(fromAlpha)
    alpha:SetToAlpha(toAlpha)
    alpha:SetDuration(duration)
    alpha:SetOrder(order or 1)
    return alpha
end

-- Transitions like Blizzard's: a new point fades in, shrinks from a larger size and flashes, a
-- spent point fades out.
local function CreateTransitions(point)
    point.fillIn = point.Active:CreateAnimationGroup()
    point.fillIn:SetToFinalAlpha(true)
    CreateAlpha(point.fillIn, 0, 1, 0.15)
    local scale = point.fillIn:CreateAnimation("Scale")
    scale:SetScaleFrom(1.6, 1.6)
    scale:SetScaleTo(1, 1)
    scale:SetDuration(0.2)
    scale:SetOrigin("CENTER", 0, 0)

    point.flash = point.Glow:CreateAnimationGroup()
    point.flash:SetToFinalAlpha(true)
    CreateAlpha(point.flash, 0, 0.9, 0.1, 1)
    CreateAlpha(point.flash, 0.9, 0, 0.35, 2)

    point.spend = point.Active:CreateAnimationGroup()
    point.spend:SetToFinalAlpha(true)
    CreateAlpha(point.spend, 1, 0, 0.2)
end

local function CreatePoint(style)
    local point = CreateFrame("Frame", nil, row)
    point:SetSize(POINT_SIZE, POINT_SIZE)
    point.Active = CreateFrame("Frame", nil, point)
    point.Active:SetAllPoints()
    if style == "classic" then
        SetupClassic(point)
    else
        SetupModern(point)
    end
    point.Active:SetAlpha(0)
    point.Glow:SetAlpha(0)
    CreateTransitions(point)
    point.isActive = false
    return point
end

local function GetPoints()
    local style = ns.charDb.nameplateComboPointsStyle
    if not pointsByStyle[style] then
        pointsByStyle[style] = {}
    end
    return pointsByStyle[style]
end

local function SetActive(point, isActive, suppressTransition)
    if point.isActive == isActive then
        return
    end
    point.isActive = isActive
    point.fillIn:Stop()
    point.flash:Stop()
    point.spend:Stop()
    if suppressTransition then
        point.Active:SetAlpha(isActive and 1 or 0)
        point.Glow:SetAlpha(0)
    elseif isActive then
        point.fillIn:Play()
        point.flash:Play()
    else
        point.spend:Play()
    end
end

-- Style and number of points the row is laid out for. The layout only changes with them.
local laidOutStyle, laidOutMaxPoints

-- Lays out maxPoints points of the current style in a row and hides the rest.
local function LayoutPoints(maxPoints)
    local style = ns.charDb.nameplateComboPointsStyle
    if style == laidOutStyle and maxPoints == laidOutMaxPoints then
        return
    end

    local points = GetPoints()
    if style ~= laidOutStyle then
        for _, stylePoints in pairs(pointsByStyle) do
            if stylePoints ~= points then
                for _, point in ipairs(stylePoints) do
                    point:Hide()
                end
            end
        end
    end
    laidOutStyle, laidOutMaxPoints = style, maxPoints

    row:SetSize(maxPoints * POINT_SIZE + (maxPoints - 1) * SPACING, POINT_SIZE)
    for index = 1, math.max(maxPoints, #points) do
        local point = points[index]
        if not point then
            point = CreatePoint(style)
            points[index] = point
        end
        if index <= maxPoints then
            point:ClearAllPoints()
            point:SetPoint("LEFT", row, "LEFT", (index - 1) * (POINT_SIZE + SPACING), 0)
            point:Show()
        else
            SetActive(point, false, true)
            point:Hide()
        end
    end
end

-- Fills the first comboPoints points. Without transitions after a target change, like
-- Blizzard's ComboFrame. Only points whose state changes are touched.
local function FillPoints(comboPoints, maxPoints, suppressTransitions)
    local points = GetPoints()
    for index = 1, maxPoints do
        SetActive(points[index], index <= comboPoints, suppressTransitions)
    end
end

-- Empties all points without transitions while the row is hidden, so the first point after it
-- shows again fills with a transition.
local function ResetPoints()
    for _, point in ipairs(GetPoints()) do
        SetActive(point, false, true)
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
    if not width or issecretvalue(width) or width <= 0 then
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
    if issecretvalue(nameShown) or not nameShown or issecretvalue(height) then
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
    return castBarShown and not issecretvalue(castBarShown) or false
end

-- Factor from the health bar's coordinates to the row's own coordinates (the row has its own
-- scale on top of the nameplate's).
local function GetScaleFactor(healthBar)
    local barScale, rowScale = healthBar:GetEffectiveScale(), row:GetEffectiveScale()
    if issecretvalue(barScale) or issecretvalue(rowScale) then
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
    if row:GetParent() ~= namePlate then
        row:SetParent(namePlate)
        row:SetFrameLevel(namePlate:GetFrameLevel() + 10)
    end
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
            if barX and castBarX and not issecretvalue(barX) and not issecretvalue(castBarX) then
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

-- Set by a target change or a new setting: the next update shows the points without transitions.
local suppressTransitions = false

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
    if issecretvalue(comboPoints) or comboPoints == 0 then
        suppressTransitions = false
        if shown.namePlate then
            wipe(shown)
            ResetPoints()
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
    local placed = namePlate == shown.namePlate and maxPoints == shown.maxPoints
        and healthBarWidth == shown.healthBarWidth and castBarShown == shown.castBarShown
        and nameHeight == shown.nameHeight
    if placed and comboPoints == shown.comboPoints then
        suppressTransitions = false
        return
    end
    shown.namePlate, shown.comboPoints, shown.maxPoints = namePlate, comboPoints, maxPoints
    shown.healthBarWidth, shown.castBarShown, shown.nameHeight = healthBarWidth, castBarShown, nameHeight

    -- A new combo point on the same nameplate only fills a point; the row stays where it is.
    if not placed then
        LayoutPoints(maxPoints)
        AttachTo(namePlate, shown)
    end
    FillPoints(comboPoints, maxPoints, suppressTransitions)
    suppressTransitions = false
    row:Show()
end

-- Places the row again, e.g. after a setting or the nameplate style changed.
local function Refresh()
    if row then
        wipe(shown)
        row:Hide()
    end
    suppressTransitions = true
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

-- "modern" or "classic", see STYLES.
function NameplateComboPoints:GetStyle()
    return ns.charDb.nameplateComboPointsStyle
end

function NameplateComboPoints:SetStyle(style)
    SetSetting("nameplateComboPointsStyle", style == "classic" and "classic" or "modern")
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

    ns:RegisterEvent("PLAYER_TARGET_CHANGED", function()
        suppressTransitions = true
        Update()
    end)
    -- Moving the points to a new target keeps the count, so no power event fires.
    ns:RegisterEvent("COMBO_TARGET_CHANGED", Update)
    ns:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player", Update)
    ns:RegisterUnitEvent("UNIT_MAXPOWER", "player", Update)
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
