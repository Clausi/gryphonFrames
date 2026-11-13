-- luacheck configuration for GryphonFrames (WoW Forever, Lua 5.1)
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
    "strsplit",
    "strtrim",
    "canaccesstable",
    "issecretvalue",
    "hooksecurefunc",
    "wipe",
    "CopyTable",

    -- Libraries
    "LibStub",

    -- API
    "C_AddOns",
    "C_LootHistory",
    "C_NamePlate",
    "C_Spell",
    "C_Timer",
    "CreateFrame",
    "Enum",
    "GetAddOnMemoryUsage",
    "GetComboPoints",
    "GetLocale",
    "GetLootRollItemLink",
    "GetTime",
    "HandleModifiedItemClick",
    "InCombatLockdown",
    "IsModifiedClick",
    "Item",
    "UnitClass",
    "UnitName",
    "UnitPower",
    "UnitPowerMax",
    "UnitPowerType",
    "UpdateAddOnMemoryUsage",

    -- Global strings and colors
    "LOOT_HISTORY_ALL_PASSED",
    "LOOT_HISTORY_PLAYER_DELIMITER",
    "LOOT_HISTORY_WAITING_ON",
    "RAID_CLASS_COLORS",
    "UNKNOWN",
    "HIGHLIGHT_FONT_COLOR",
    "NORMAL_FONT_COLOR",

    -- Tooltips
    "TooltipDataProcessor",

    -- UI helpers
    "CreateAtlasMarkup",
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
    "GameTooltip",
    "NamePlateDriverFrame",
    -- Returns the power bar of the player frame on all clients (see PlayerPowerTicks.lua).
    "PlayerFrame_GetManaBar",
    "TargetFrame",
    -- Re-anchored after Blizzard's AdjustPosition() once it was moved in Edit Mode (see TargetCastBar.lua).
    "TargetFrameSpellBar",
    "UIParent",
}
