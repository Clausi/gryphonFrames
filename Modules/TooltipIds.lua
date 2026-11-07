local _, ns = ...
local L = ns.L

-- Adds the spell ID, item ID or NPC ID as a line to tooltips of spells, auras (buffs and debuffs),
-- items and NPCs.
--
-- The client builds tooltips from tooltip data (Blizzard_GameTooltip/Mainline/GameTooltip.lua,
-- GameTooltipDataMixin) and calls the post calls of TooltipDataProcessor with it. They only run
-- when a tooltip is built, never per frame. They cannot be removed again, so they are added when
-- the first kind of ID is turned on and skip the kinds that are off.
--
-- Turned on per character and kind in the options (Modules/Options.lua) or with
-- "/gryphonframes spellids on", "/gryphonframes itemids on" and "/gryphonframes npcids on"
-- (ns.charDb.tooltipSpellIds, ns.charDb.tooltipItemIds, ns.charDb.tooltipNpcIds).
local TooltipIds = ns:RegisterModule("TooltipIds")

local LABEL_COLOR = NORMAL_FONT_COLOR
local VALUE_COLOR = HIGHLIGHT_FONT_COLOR
-- Per kind of ID: the setting in ns.charDb, the tooltip label and the chat messages.
local KINDS = {
    spell = { setting = "tooltipSpellIds", label = "TOOLTIP_SPELL_ID", on = "SPELL_IDS_ON",
              off = "SPELL_IDS_OFF" },
    item = { setting = "tooltipItemIds", label = "TOOLTIP_ITEM_ID", on = "ITEM_IDS_ON", off = "ITEM_IDS_OFF" },
    npc = { setting = "tooltipNpcIds", label = "TOOLTIP_NPC_ID", on = "NPC_IDS_ON", off = "NPC_IDS_OFF" },
}

-- The NPC ID is the 6th part of the GUID of a creature or vehicle:
-- "Creature-0-[server]-[instance]-[zone]-[npc ID]-[spawn]". Players and pets have none.
local function GetNpcId(guid)
    local unitType, _, _, _, _, npcId = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcId)
    end
end

local hooked = false
-- Kinds of ID already added to each tooltip since it was last cleared: some tooltips are built
-- twice.
local added = setmetatable({}, { __mode = "k" })
local clearHooked = setmetatable({}, { __mode = "k" })

local function OnTooltipCleared(tooltip)
    added[tooltip] = nil
end

local function AddId(tooltip, kind, id)
    -- A secret ID or GUID cannot be compared or formatted; it is left out.
    if not ns.charDb[KINDS[kind].setting] or issecretvalue(id) or tooltip:IsForbidden() then
        return
    end
    if kind == "npc" then
        id = GetNpcId(id)
        if not id then
            return
        end
    end
    if not clearHooked[tooltip] then
        clearHooked[tooltip] = true
        tooltip:HookScript("OnTooltipCleared", OnTooltipCleared)
    end
    local kinds = added[tooltip] or {}
    added[tooltip] = kinds
    if kinds[kind] then
        return
    end
    kinds[kind] = true
    tooltip:AddDoubleLine(L[KINDS[kind].label], id, LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b,
        VALUE_COLOR.r, VALUE_COLOR.g, VALUE_COLOR.b)
end

-- Post call for one tooltip data type: adds the field of the tooltip data as the kind of ID. The
-- npc kind gets the GUID of the unit.
local function CreatePostCall(kind, field)
    return function(tooltip, tooltipData)
        local value = tooltipData and tooltipData[field]
        if value then
            AddId(tooltip, kind, value)
        end
    end
end

local function Hook()
    if hooked then
        return
    end
    hooked = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, CreatePostCall("spell", "id"))
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, CreatePostCall("spell", "id"))
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, CreatePostCall("item", "id"))
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, CreatePostCall("npc", "guid"))
end

-- kind is "spell" or "item".
function TooltipIds:IsEnabled(kind)
    return ns.charDb[KINDS[kind].setting]
end

-- Shown on the next tooltip; an open tooltip keeps its lines.
function TooltipIds:SetEnabled(kind, enabled)
    ns.charDb[KINDS[kind].setting] = enabled
    if enabled then
        Hook()
    end
end

for _, kind in ipairs({ "spell", "item", "npc" }) do
    local info = KINDS[kind]
    local help = L["HELP_" .. kind:upper() .. "_IDS"]
    ns:RegisterCommand(kind .. "ids", function(args)
        local value = args:lower()
        if value == "on" then
            TooltipIds:SetEnabled(kind, true)
        elseif value == "off" then
            TooltipIds:SetEnabled(kind, false)
        elseif value ~= "" then
            ns:Print(help)
            return
        end
        ns:Print(TooltipIds:IsEnabled(kind) and L[info.on] or L[info.off])
    end, { help })
end

function TooltipIds:OnEnable()
    for _, info in pairs(KINDS) do
        if ns.charDb[info.setting] then
            Hook()
        end
    end
end
