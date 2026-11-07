local _, ns = ...
local L = ns.L

-- Makes the cast bar of the target frame movable in Edit Mode.
--
-- Blizzard's Edit Mode has no system for the target cast bar (TargetFrameSpellBar): it is a child
-- of TargetFrame, and TargetSpellBarMixin:AdjustPosition() anchors it below the frame or its auras
-- on every show, target change, target of target change and aura row change. This module
-- registers its own anchor frame with LibEditMode and, once the bar has been moved, re-anchors the
-- bar to it after every AdjustPosition(). Without a moved position, Blizzard's anchoring is kept.
--
-- Positions are saved per Edit Mode layout in ns.db.targetCastBar.layouts[layoutName] as
-- { point, x, y } relative to UIParent. A missing entry means "attached to the target frame".
local TargetCastBar = ns:RegisterModule("TargetCastBar")

local LibEditMode = LibStub("LibEditMode")

-- Position the anchor has in LibEditMode. "Reset Position" in the Edit Mode dialog moves the
-- anchor exactly here, which the module takes as "attach to the target frame again", like
-- Blizzard's own player cast bar does.
local DEFAULT_POSITION = { point = "CENTER", x = 0, y = -150 }

local anchor
local spellBar

local function GetLayouts()
    return ns.db.targetCastBar.layouts
end

-- Saved position of the active layout, or nil while the bar is attached to the target frame.
local function GetPosition(layoutName)
    layoutName = layoutName or LibEditMode:GetActiveLayoutName()
    return layoutName and GetLayouts()[layoutName]
end

local function IsDefaultPosition(point, x, y)
    return point == DEFAULT_POSITION.point
        and math.abs(x - DEFAULT_POSITION.x) < 0.01
        and math.abs(y - DEFAULT_POSITION.y) < 0.01
end

-- Size of TargetSpellBarTemplate (Blizzard_UnitFrame/Mainline/TargetFrame.xml). The bar's own size
-- cannot be used: the client returns it as a secret value once Blizzard has anchored the bar to
-- the aura container (AddForbiddenAspects in TargetSpellBarMixin:AdjustPosition()).
local BAR_WIDTH, BAR_HEIGHT = 150, 10

-- Scale of the bar relative to UIParent. The bar has no own scale, so it follows the target
-- frame (Edit Mode "Frame Size"). Falls back to 1 if the client hides the value.
local function GetBarScale()
    local scale = TargetFrame:GetEffectiveScale()
    if issecretvalue(scale) then
        return 1
    end
    return scale / UIParent:GetEffectiveScale()
end

-- The anchor has the on-screen size of the bar.
local function UpdateAnchorSize()
    local scale = GetBarScale()
    anchor:SetSize(BAR_WIDTH * scale, BAR_HEIGHT * scale)
end

-- Offset of the bar's TOPLEFT from the target frame's BOTTOMLEFT, where Blizzard puts it while the
-- target has no extra aura rows below the frame. Mirrors the non-aura branches of
-- TargetSpellBarMixin:AdjustPosition(), so the values must follow Blizzard's code.
local function GetBarOffset()
    local x = TargetFrame.smallSize and 38 or 43
    local y = TargetFrame.smallSize and 3 or 5
    if TargetFrame.haveToT then
        y = TargetFrame.smallSize and -48 or -46
    end
    return x, y
end

-- Hands the bar back to Blizzard's anchoring. AdjustPosition() is not called here: run from addon
-- code it could taint the aura layout it reads. It clears the points itself and runs again on the
-- next show of the bar. The shown state of the bar may be secret, like its size.
local function ReleaseBar()
    local shown = spellBar:IsShown()
    if not issecretvalue(shown) and not shown then
        spellBar:ClearAllPoints()
    end
end

-- Places the anchor where Blizzard shows the bar below the target frame, so it can be picked up
-- there in Edit Mode. The bar is not anchored at all before the target first casts, so its own
-- position cannot be used.
local function PlaceAnchorAtTargetFrame()
    local x, y = GetBarOffset()
    local scale = GetBarScale()
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", x * scale, y * scale)
end

-- Moves the bar to the anchor if the active layout has a saved position. Runs after every
-- Blizzard AdjustPosition(), so Blizzard's own anchoring is overridden. The bar is not a protected
-- frame, so this also works in combat.
local function ApplyBarPosition()
    if not GetPosition() then
        return
    end
    spellBar:ClearAllPoints()
    spellBar:SetPoint("CENTER", anchor, "CENTER")
end

-- Applies the saved position of the active layout to the anchor and the bar.
local function ApplyLayout()
    UpdateAnchorSize()
    local position = GetPosition()
    if position then
        anchor:ClearAllPoints()
        anchor:SetPoint(position.point, UIParent, position.point, position.x, position.y)
        ApplyBarPosition()
    else
        PlaceAnchorAtTargetFrame()
        ReleaseBar()
    end
end

-- Current anchor position relative to UIParent's center (the anchor has scale 1).
local function GetAnchorPosition()
    local x, y = anchor:GetCenter()
    local width, height = UIParent:GetSize()
    return { point = "CENTER", x = x - width / 2, y = y - height / 2 }
end

local function SetAttached(layoutName, attached)
    if not layoutName then
        return
    end
    if attached then
        GetLayouts()[layoutName] = nil
    elseif not GetLayouts()[layoutName] then
        GetLayouts()[layoutName] = GetAnchorPosition()
    end
    ApplyLayout()
end

-- LibEditMode callback after the anchor was dragged, moved with the arrow keys or reset.
local function OnPositionChanged(_, layoutName, point, x, y)
    if not layoutName then
        return
    end
    if IsDefaultPosition(point, x, y) then
        SetAttached(layoutName, true)
        return
    end
    GetLayouts()[layoutName] = { point = point, x = x, y = y }
    ApplyLayout()
end

local function RegisterLayoutCallbacks()
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

function TargetCastBar:OnEnable()
    spellBar = TargetFrameSpellBar
    if not spellBar then
        ns:Debug("TargetFrameSpellBar not found, target cast bar stays at Blizzard's position.")
        return
    end

    -- Invisible outside Edit Mode: no textures, no mouse. LibEditMode shows its selection overlay
    -- on top of it while Edit Mode is open.
    anchor = CreateFrame("Frame", nil, UIParent)
    anchor:SetClampedToScreen(true)
    anchor.editModeName = L["TARGET_CAST_BAR"]
    UpdateAnchorSize()
    PlaceAnchorAtTargetFrame()

    LibEditMode:AddFrame(anchor, OnPositionChanged, DEFAULT_POSITION, L["TARGET_CAST_BAR"])
    LibEditMode:AddFrameSettings(anchor, {
        {
            kind = LibEditMode.SettingType.Checkbox,
            name = L["TARGET_CAST_BAR_ATTACH"],
            desc = L["TARGET_CAST_BAR_ATTACH_DESC"],
            default = true,
            get = function(layoutName)
                return not GetPosition(layoutName)
            end,
            set = function(layoutName, attached)
                SetAttached(layoutName, attached)
            end,
        },
    })

    RegisterLayoutCallbacks()

    -- AdjustPosition() is also the OnShow script of the bar (TargetSpellBarTemplate).
    hooksecurefunc(spellBar, "AdjustPosition", ApplyBarPosition)
    spellBar:HookScript("OnShow", ApplyBarPosition)
end
