-- luacheck configuration for GryphonFrames (WoW Forever, Classic Era and Anniversary, Lua 5.1)
std = "lua51"
max_line_length = 120
exclude_files = { ".tools/", "Libs/" }

-- Methods defined with ":" do not have to use the implicit self.
self = false

-- Globals the addon defines.
globals = {
    "GryphonFramesDB",
    "GryphonFramesCharDB",
    "SLASH_GRYPHONFRAMES1",
    "SlashCmdList",
}

-- WoW API and Blizzard UI globals the addon reads. Add new ones here when used.
read_globals = {
    -- WoW Lua extensions
    "format",
    "floor",
    "strtrim",
    "issecretvalue",
    "hooksecurefunc",
    "wipe",
    "CopyTable",

    -- Libraries
    "LibStub",

    -- API
    "C_AddOns",
    "C_NamePlate",
    "C_Texture",
    "C_Timer",
    "CreateFrame",
    "Enum",
    "GetAddOnMemoryUsage",
    "GetComboPoints",
    "GetLocale",
    "InCombatLockdown",
    "UnitPowerMax",
    "UpdateAddOnMemoryUsage",

    -- UI helpers
    "CreateSettingsListSectionHeaderInitializer",
    "DropdownButtonMixin",
    "MinimalSliderWithSteppersMixin",
    "Settings",
    "SettingsPanel",

    -- Nameplate layout (read only, see NameplateComboPoints.lua)
    "NamePlateConstants",
    "NamePlateSetupOptions",

    -- Frames
    "DEFAULT_CHAT_FRAME",
    "NamePlateDriverFrame",
    "TargetFrame",
    -- Re-anchored after Blizzard's AdjustPosition() once it was moved in Edit Mode (see TargetCastBar.lua).
    "TargetFrameSpellBar",
    "UIParent",
}
