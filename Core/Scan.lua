--[[
	Core/Scan.lua - bag scan, keeps SW.shields up to date.

	Rescans only on BAG_UPDATE_DELAYED (Blizzard already coalesces this into
	one fire per batch of bag changes). A shield's durability only changes
	while it's equipped and taking damage, so this is cheap and correct -
	between events the icon grid just reads SW.shields from memory.
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

local function slotItemID(bag, slot)
	local info = GetSlotInfo(bag, slot)
	if type(info) == "table" then return info.itemID end
	local link = GetSlotLink(bag, slot)
	if link then return tonumber(link:match("item:(%d+)")) end
	return nil
end

------------------------------------------------------------------------
-- Scan
------------------------------------------------------------------------

-- Rebuilds SW.shields: every shield currently sitting in a bag, with its
-- live durability. Item data can arrive async on a cold cache (server just
-- sent the item ID, name/equip-loc not cached yet) - when that happens we
-- register GET_ITEM_INFO_RECEIVED once and rescan when it fires.
function SW:ScanShields()
	local found = {}
	local pending = false

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
						bag = bag, slot = slot, itemID = itemID, link = link,
						icon = texture,
						durability = durability or 1,
						maxDurability = maxDurability or 1,
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
	SW:ScanShields()
end

function SW:BAG_UPDATE_DELAYED()
	SW:ScanShields()
end
