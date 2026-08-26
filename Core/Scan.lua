--[[
	Core/Scan.lua - bag + equipped-slot scan, keeps SW.shields up to date.

	Rescans on BAG_UPDATE_DELAYED (Blizzard already coalesces this into one
	fire per batch of bag changes), PLAYER_EQUIPMENT_CHANGED (a shield gets
	equipped/unequipped), and UPDATE_INVENTORY_DURABILITY (the worn shield's
	durability actually changes from combat damage - bag items never do,
	since only equipped gear takes damage). Between events the icon grid
	just reads SW.shields from memory.
]]

local ADDON, ns = ...
local SW = ns.SW

-- C_Container compatibility (present on Era 1.15.9, but be safe) - same
-- pattern as EasyMount's Core/Scan.lua, already verified working on this
-- client.
local Container = C_Container or {}
local GetNumSlots = Container.GetContainerNumSlots or _G.GetContainerNumSlots
local GetSlotInfo = Container.GetContainerItemInfo or _G.GetContainerItemInfo
local GetSlotLink = Container.GetContainerItemLink or _G.GetContainerItemLink
local GetSlotDurability = Container.GetContainerItemDurability or _G.GetContainerItemDurability

local SHIELD_EQUIP_LOC = "INVTYPE_SHIELD"
local INVSLOT_OFFHAND = 17 -- shields only ever equip here

local function slotItemID(bag, slot)
	local info = GetSlotInfo(bag, slot)
	if type(info) == "table" then return info.itemID end
	local link = GetSlotLink(bag, slot)
	if link then return tonumber(link:match("item:(%d+)")) end
	return nil
end

-- Per-physical-item identity, confirmed working on this client (Tek's
-- /sw dump: two identical "Bulwark of Ire" shields returned distinct GUIDs,
-- and an item's GUID stayed put across an equip/unequip location change).
-- Lets UI/Buttons.lua sort by something that never changes just because a
-- shield got equipped, unlike bag/slot which does. Best-effort: pcall'd
-- since exact availability isn't guaranteed on every future client patch;
-- nil guid falls back to itemID-only tiebreaking.
local function itemGUID(bag, slot, invSlot)
	if not (C_Item and C_Item.GetItemGUID and _G.ItemLocation) then return nil end
	local ok, result = pcall(function()
		local loc = invSlot
			and ItemLocation:CreateFromEquipmentSlot(invSlot)
			or ItemLocation:CreateFromBagAndSlot(bag, slot)
		if not loc or not loc:IsValid() then return nil end
		return C_Item.GetItemGUID(loc)
	end)
	return ok and result or nil
end

------------------------------------------------------------------------
-- Scan
------------------------------------------------------------------------

-- The currently-worn shield, if any. Returns (entry, pending) - pending
-- means the item's cached data hasn't arrived yet, same as the bag case.
local function scanEquipped()
	local itemID = GetInventoryItemID("player", INVSLOT_OFFHAND)
	if not itemID then return nil, false end

	local name, link, _, _, _, _, _, _, equipLoc, texture = GetItemInfo(itemID)
	if not name then return nil, true end
	if equipLoc ~= SHIELD_EQUIP_LOC then return nil, false end

	local durability, maxDurability = GetInventoryItemDurability(INVSLOT_OFFHAND)
	return {
		kind = "equipped", invSlot = INVSLOT_OFFHAND, itemID = itemID, link = link,
		icon = texture,
		durability = durability or 1,
		maxDurability = maxDurability or 1,
		guid = itemGUID(nil, nil, INVSLOT_OFFHAND),
	}, false
end

-- Rebuilds SW.shields: the worn shield (if any) plus every shield sitting
-- in a bag, with live durability. Item data can arrive async on a cold
-- cache (server just sent the item ID, name/equip-loc not cached yet) -
-- when that happens we register GET_ITEM_INFO_RECEIVED once and rescan
-- when it fires.
function SW:ScanShields()
	local found = {}
	local pending = false

	local equipped, eqPending = scanEquipped()
	if equipped then found[#found + 1] = equipped end
	if eqPending then pending = true end

	for bag = 0, 4 do
		local slots = GetNumSlots and GetNumSlots(bag) or 0
		for slot = 1, slots do
			local itemID = slotItemID(bag, slot)
			if itemID then
				local name, link, _, _, _, _, _, _, equipLoc, texture = GetItemInfo(itemID)
				if not name then
					pending = true
				elseif equipLoc == SHIELD_EQUIP_LOC then
					local durability, maxDurability = GetSlotDurability(bag, slot)
					found[#found + 1] = {
						kind = "bag", bag = bag, slot = slot, itemID = itemID, link = link,
						icon = texture,
						durability = durability or 1,
						maxDurability = maxDurability or 1,
						guid = itemGUID(bag, slot, nil),
					}
				end
			end
		end
	end

	SW.shields = found
	if SW.RefreshLayout then SW:RefreshLayout() end
	if pending then SW:RegisterEvent("GET_ITEM_INFO_RECEIVED") end
	return found
end

function SW:GET_ITEM_INFO_RECEIVED()
	SW:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
	SW:ScanShields()
end

------------------------------------------------------------------------
-- Wiring
------------------------------------------------------------------------

function SW:InitScan()
	SW:RegisterEvent("BAG_UPDATE_DELAYED")
	SW:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	SW:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
	SW:ScanShields()
end

function SW:BAG_UPDATE_DELAYED()
	SW:ScanShields()
end

function SW:PLAYER_EQUIPMENT_CHANGED()
	SW:ScanShields()
end

function SW:UPDATE_INVENTORY_DURABILITY()
	SW:ScanShields()
end
