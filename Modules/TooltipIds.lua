local _, ns = ...
local L = ns.L

-- Adds the spell ID, item ID, item level or NPC ID as a line to tooltips of spells, auras (buffs
-- and debuffs), items and NPCs.
--
-- The client builds tooltips from tooltip data (Blizzard_GameTooltip/Mainline/GameTooltip.lua,
-- GameTooltipDataMixin) and calls the post calls of TooltipDataProcessor with it. They only run
-- when a tooltip is built, never per frame. They cannot be removed again, so they are added when
-- the first kind of line is turned on and skip the kinds that are off.
--
-- Turned on per character and kind in the options (Modules/Options.lua) or with
-- "/gryphonframes spellids on", "/gryphonframes itemids on", "/gryphonframes itemlevel on" and
-- "/gryphonframes npcids on" (ns.charDb.tooltipSpellIds, ns.charDb.tooltipItemIds,
-- ns.charDb.tooltipItemLevel, ns.charDb.tooltipNpcIds).
local TooltipIds = ns:RegisterModule("TooltipIds")

local LABEL_COLOR = NORMAL_FONT_COLOR
local VALUE_COLOR = HIGHLIGHT_FONT_COLOR

-- The NPC ID is the 6th part of the GUID of a creature or vehicle:
-- "Creature-0-[server]-[instance]-[zone]-[npc ID]-[spawn]". Players and pets have none.
local function GetNpcId(tooltipData)
    local guid = tooltipData.guid
    if not guid or issecretvalue(guid) then
        return
    end
    local unitType, _, _, _, _, npcId = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcId)
    end
end

-- The item level of equippable items, as TooltipUtil.GetDisplayedItem finds the item: an item in
-- the bags or equipped has a GUID, other items (links, merchant, loot) a hyperlink. The level
-- includes upgrades and scaling.
local function GetItemLevel(tooltipData)
    local item = tooltipData.guid
    if item and not issecretvalue(item) then
        item = C_Item.GetItemLinkByGUID(item)
    else
        item = tooltipData.hyperlink
    end
    if not item or issecretvalue(item) or not C_Item.IsEquippableItem(item) then
        return
    end
    local itemLevel = C_Item.GetDetailedItemLevelInfo(item)
    if itemLevel and not issecretvalue(itemLevel) and itemLevel > 0 then
        return itemLevel
    end
end

local function GetId(tooltipData)
    local id = tooltipData.id
    -- A secret ID cannot be formatted; it is left out.
    if id and not issecretvalue(id) then
        return id
    end
end

-- Per kind of line: the setting in ns.charDb, the slash command, the tooltip label, the chat
-- messages, the tooltip data types it is added to and the function that reads its value from the
-- tooltip data (nil: no line). Kinds of the same tooltip data type are added in this order.
local KINDS = {
    spell = { setting = "tooltipSpellIds", command = "spellids", label = "TOOLTIP_SPELL_ID",
              on = "SPELL_IDS_ON", off = "SPELL_IDS_OFF", help = "HELP_SPELL_IDS",
              types = { "Spell", "UnitAura" }, getValue = GetId },
    itemLevel = { setting = "tooltipItemLevel", command = "itemlevel", label = "TOOLTIP_ITEM_LEVEL",
                  on = "ITEM_LEVEL_ON", off = "ITEM_LEVEL_OFF", help = "HELP_ITEM_LEVEL",
                  types = { "Item" }, getValue = GetItemLevel },
    item = { setting = "tooltipItemIds", command = "itemids", label = "TOOLTIP_ITEM_ID",
             on = "ITEM_IDS_ON", off = "ITEM_IDS_OFF", help = "HELP_ITEM_IDS",
             types = { "Item" }, getValue = GetId },
    npc = { setting = "tooltipNpcIds", command = "npcids", label = "TOOLTIP_NPC_ID",
            on = "NPC_IDS_ON", off = "NPC_IDS_OFF", help = "HELP_NPC_IDS",
            types = { "Unit" }, getValue = GetNpcId },
}
local KIND_ORDER = { "spell", "itemLevel", "item", "npc" }

local hooked = false
-- Kinds of line already added to each tooltip since it was last cleared: some tooltips are built
-- twice.
local added = setmetatable({}, { __mode = "k" })
local clearHooked = setmetatable({}, { __mode = "k" })

local function OnTooltipCleared(tooltip)
    added[tooltip] = nil
end

local function AddLine(tooltip, kind, tooltipData)
    local info = KINDS[kind]
    if not ns.charDb[info.setting] or not tooltipData or tooltip:IsForbidden() then
        return
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
    local value = info.getValue(tooltipData)
    if not value then
        return
    end
    kinds[kind] = true
    tooltip:AddDoubleLine(L[info.label], value, LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b,
        VALUE_COLOR.r, VALUE_COLOR.g, VALUE_COLOR.b)
end

local function Hook()
    if hooked then
        return
    end
    hooked = true
    for _, kind in ipairs(KIND_ORDER) do
        for _, dataType in ipairs(KINDS[kind].types) do
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType[dataType], function(tooltip, tooltipData)
                AddLine(tooltip, kind, tooltipData)
            end)
        end
    end
end

-- kind is "spell", "item", "itemLevel" or "npc".
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

for _, kind in ipairs(KIND_ORDER) do
    local info = KINDS[kind]
    local help = L[info.help]
    ns:RegisterCommand(info.command, function(args)
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
