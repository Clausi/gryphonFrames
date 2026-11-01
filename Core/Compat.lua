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
-- RogueComboPoint.xml). Classic Era and Anniversary only have the texture of the Classic ComboFrame
-- (Blizzard_UnitFrame/Classic/ComboFrame.xml).
local hasComboPointAtlas = C_Texture.GetAtlasInfo("uf-roguecp-icon-red") ~= nil

-- True if the value is a secret value. Clients without secret values have no issecretvalue.
function Compat.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
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

-- Adds the textures of a combo point to an own frame of 12x12 (the size of the Classic
-- ComboPointTemplate): an empty socket and point.Active, the filled point on top of it.
function Compat.SetupComboPoint(point)
    local background = point:CreateTexture(nil, "BACKGROUND")
    local active = point:CreateTexture(nil, "ARTWORK")

    if hasComboPointAtlas then
        background:SetAtlas("uf-roguecp-bg-dis")
        background:SetAllPoints()
        active:SetAtlas("uf-roguecp-icon-red")
        active:SetAllPoints()
    else
        -- Same textures and texture coordinates as ComboPointTemplate.
        background:SetTexture("Interface\\ComboFrame\\ComboPoint")
        background:SetSize(12, 16)
        background:SetPoint("TOPLEFT")
        background:SetTexCoord(0, 0.375, 0, 1)
        active:SetTexture("Interface\\ComboFrame\\ComboPoint")
        active:SetSize(8, 16)
        active:SetPoint("TOPLEFT", 2, 0)
        active:SetTexCoord(0.375, 0.5625, 0, 1)
    end

    point.Active = active
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
