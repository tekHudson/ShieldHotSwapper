--[[ ShieldWatch — /sw dump: raw per-shield data in a copyable text box.

Diagnostic tool, not part of the addon's normal feature set. Lists
everything we can read off each shield (worn + bagged) - itemID, full
link, the link's parsed uniqueID field, and (best-effort, wrapped in
pcall since availability on this client is unconfirmed) an
ItemLocation-based item GUID via C_Item.GetItemGUID. Used to find a
reliable way to distinguish two physically identical copies of the same
shield item (see the location-key tiebreak in UI/Buttons.lua:RefreshLayout,
which currently sorts without needing this).
]]

local ADDON, ns = ...
local SW = ns.SW

-- item link core fields have been stable since vanilla:
-- item:itemID:enchant:gem1:gem2:gem3:gem4:suffixID:uniqueID:...
local function parseLink(link)
	if not link then return nil end
	return link:match("item:(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*)")
end

local function tryItemGUID(entry)
	if not (C_Item and C_Item.GetItemGUID and _G.ItemLocation) then
		return "unavailable (C_Item.GetItemGUID/ItemLocation not present on this client)"
	end
	local ok, result = pcall(function()
		local loc
		if entry.kind == "equipped" then
			loc = ItemLocation:CreateFromEquipmentSlot(entry.invSlot)
		else
			loc = ItemLocation:CreateFromBagAndSlot(entry.bag, entry.slot)
		end
		if not loc or not loc:IsValid() then return nil end
		return C_Item.GetItemGUID(loc)
	end)
	if not ok then return "ERROR: " .. tostring(result) end
	return result and tostring(result) or "nil"
end

local function buildText()
	local lines = {}
	lines[#lines + 1] = "ShieldWatch debug dump - " .. date("%Y-%m-%d %H:%M:%S")
	lines[#lines + 1] = ""

	local shields = SW.shields or {}
	if #shields == 0 then
		lines[#lines + 1] = "(no shields found)"
	end

	for _, entry in ipairs(shields) do
		local itemID, enchant, gem1, gem2, gem3, gem4, suffix, unique = parseLink(entry.link)
		lines[#lines + 1] = string.format(
			"kind=%s  itemID=%s  bag/slot=%s/%s  invSlot=%s",
			tostring(entry.kind), tostring(entry.itemID),
			tostring(entry.bag), tostring(entry.slot), tostring(entry.invSlot))
		lines[#lines + 1] = "  durability: " .. tostring(entry.durability) .. "/" .. tostring(entry.maxDurability)
		lines[#lines + 1] = "  link: " .. tostring(entry.link)
		lines[#lines + 1] = string.format(
			"  parsed link: itemID=%s enchant=%s gems=%s,%s,%s,%s suffix=%s uniqueID=%s",
			tostring(itemID), tostring(enchant), tostring(gem1), tostring(gem2),
			tostring(gem3), tostring(gem4), tostring(suffix), tostring(unique))
		lines[#lines + 1] = "  itemGUID: " .. tryItemGUID(entry)
		lines[#lines + 1] = ""
	end

	return table.concat(lines, "\n")
end

local dumpFrame

local function createDumpFrame()
	local f = CreateFrame("Frame", "ShieldWatchDumpFrame", UIParent, "BackdropTemplate")
	f:SetSize(600, 440)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -4, -4)

	local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOP", 0, -16)
	title:SetText("ShieldWatch debug dump - select all, copy, paste back")

	local scroll = CreateFrame("ScrollFrame", "ShieldWatchDumpScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 16, -40)
	scroll:SetPoint("BOTTOMRIGHT", -32, 16)

	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(scroll:GetWidth() - 4)
	edit:SetAutoFocus(false)
	edit:SetScript("OnEscapePressed", function() f:Hide() end)
	scroll:SetScrollChild(edit)
	f.editBox = edit

	dumpFrame = f
	return f
end

function SW:ShowDump()
	local f = dumpFrame or createDumpFrame()
	f.editBox:SetText(buildText())
	f.editBox:HighlightText()
	f.editBox:SetFocus()
	f:Show()
end
