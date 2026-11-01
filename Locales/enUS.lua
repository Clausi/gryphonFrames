local _, ns = ...

-- Base locale. Every key used in the addon must be defined here.
-- Other locales only override the keys they translate; missing keys fall back to enUS.
local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
ns.L = L

L["ADDON_LOADED"] = "Version %s loaded. Type /gryphonframes for help."
L["DEBUG_ON"] = "Debug output enabled."
L["DEBUG_OFF"] = "Debug output disabled."
L["HELP_HEADER"] = "Commands:"
L["HELP_VERSION"] = "/gryphonframes version - show the addon version"
L["HELP_DEBUG"] = "/gryphonframes debug - toggle debug output"
L["HELP_CHAT"] = "/gryphonframes chat on||off - automatic chat messages (login, hints)"
L["CHAT_ON"] = "Automatic chat messages are on for this character."
L["CHAT_OFF"] = "Automatic chat messages are off for this character. Answers to commands are still shown."
L["TARGET_CAST_BAR"] = "Target Cast Bar"
L["TARGET_CAST_BAR_ATTACH"] = "Lock to Target Frame"
L["TARGET_CAST_BAR_ATTACH_DESC"] = "Shows the cast bar below the target frame, like Blizzard does. "
    .. "Dragging the cast bar unlocks it."
L["HELP_COMBO"] = "/gryphonframes combo on||off - also show combo points on the target's nameplate"
L["COMBO_ON"] = "Combo points on the target's nameplate are on for this character."
L["COMBO_OFF"] = "Combo points on the target's nameplate are off for this character."
L["HELP_OPTIONS"] = "/gryphonframes options - open the options"
L["OPTIONS_IN_COMBAT"] = "The options cannot be opened by command in combat. Use "
    .. "Esc > Options > AddOns or try again after the fight."
L["OPTIONS_CHAT_MESSAGES"] = "Chat Messages"
L["OPTIONS_CHAT_MESSAGES_TOOLTIP"] = "Shows automatic chat messages (login, hints). Answers to commands are "
    .. "always shown. Saved for this character."
L["OPTIONS_NAMEPLATES"] = "Nameplates"
L["OPTIONS_COMBO_HEADER"] = "Combo Points"
L["OPTIONS_COMBO"] = "Show on Target Nameplate"
L["OPTIONS_COMBO_TOOLTIP"] = "Also shows your combo points on the target's nameplate. "
    .. "Needs enemy nameplates. Saved for this character."
L["OPTIONS_COMBO_STYLE"] = "Style"
L["OPTIONS_COMBO_STYLE_TOOLTIP"] = "Modern like the combo points of the modern unit frames, or classic like "
    .. "the combo points at the Classic target frame. Saved for this character."
L["OPTIONS_COMBO_STYLE_MODERN"] = "Modern"
L["OPTIONS_COMBO_STYLE_CLASSIC"] = "Classic"
L["OPTIONS_COMBO_SCALE"] = "Size"
L["OPTIONS_COMBO_SCALE_TOOLTIP"] = "Size of the combo points on the nameplate. Saved for this character."
L["OPTIONS_COMBO_POSITION"] = "Position"
L["OPTIONS_COMBO_POSITION_TOOLTIP"] = "Above the name (above the health bar if the nameplate style shows the "
    .. "name inside it), or below the health bar. While the target casts, they move below the cast bar. "
    .. "Follows the nameplate style. Saved for this character."
L["OPTIONS_COMBO_POSITION_ABOVE"] = "Above the Name"
L["OPTIONS_COMBO_POSITION_BELOW"] = "Below the Nameplate"
L["OPTIONS_COMBO_GAP"] = "Gap"
L["OPTIONS_COMBO_GAP_TOOLTIP"] = "Distance in pixels to the name or to the health bar. Saved for this character."
L["OPTIONS_COMBO_OFFSET_X"] = "Left / Right"
L["OPTIONS_COMBO_OFFSET_X_TOOLTIP"] = "Moves the combo points within the width of the health bar: -100% is "
    .. "flush left, 0% centered, 100% flush right. Saved for this character."
