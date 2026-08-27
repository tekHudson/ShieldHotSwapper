--[[ ShieldHotSwapper — icon grid: pool of secure buttons, laid out as
<equipped icon> <gap> <bag grid, rows x columns from options>.

ONE layout path for WHICH shield is on WHICH icon - that reassignment
needs secure attribute changes and repositioning, both blocked by
InCombatLockdown(), so it only ever happens out of combat and freezes
otherwise (RefreshLayout below), catching up the instant combat ends
(PLAYER_REGEN_ENABLED). An earlier attempt tried to also keep icon
*identity* in sync during combat (matching fresh scan data back to
buttons by guid, since equipping moves an item between a bag slot and the
equip slot) and chased several real bugs (wrong click target, swapped
icons, a highlight box in the wrong place) without fully resolving - not
worth it, since the equipped icon no longer needs tracking anyway (it's
always position #1, gap, then the bag grid - position alone shows what's
equipped, nothing to move/track).

Durability numbers/icon/color DO still update live during combat, via the
much simpler updateDurabilityOnly() - reading and displaying data was
never the protected part (a plain tooltip hover shows live durability in
combat with zero special handling); it just re-reads whatever's actually
in each button's already-assigned bag/slot right now, with no attempt to
track a physical item across a location change.

Buttons use SecureActionButtonTemplate (type2="macro", right-click) so
click-to-equip survives combat lockdown - a plain insecure button calling
UseContainerItem() during combat gets its equip silently downgraded to
just picking the item up onto the cursor. Equip is bound to RIGHT-click
specifically (not left) so useOnKeyDown (fires immediately on mouse-down,
required - see the long comment in createButton) can't race the
left-click drag-to-move gesture: left click never gets a type1/item1
attribute, so its mouse-down does nothing, while
RegisterForDrag("LeftButton") still drives the drag independently. Each
button registers its own drag and forwards Start/StopMoving to the
shared container frame, so holding down on an icon moves the whole group
exactly like holding down on the background gap does.
]]

local ADDON, ns = ...
local SW = ns.SW

local ICON, PAD, MARGIN = ns.ICON, ns.PAD, ns.MARGIN
local GAP = 14 -- extra spacing between the equipped icon and the bag grid

-- Pool is sized to the sliders' max bounds (UI/Options.lua: rows 1-6,
-- columns 1-10) plus one dedicated slot for the always-present equipped
-- icon, so it never needs to grow at runtime.
local MAX_ROWS, MAX_COLUMNS = 6, 10

local function durabilityColor(pct)
	if pct <= 0.2 then return 0.9, 0.2, 0.2 end
	if pct <= 0.5 then return 0.95, 0.8, 0.2 end
	return 0.2, 0.85, 0.2
end

local function onDragStart()
	if not SW.opt.locked then SW.frame:StartMoving() end
end

local function onDragStop()
	SW.frame:StopMovingOrSizing()
	local point, _, relPoint, x, y = SW.frame:GetPoint()
	SW.opt.pos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function createButton(i)
	local btn = CreateFrame("Button", "ShieldHotSwapperIcon" .. i, SW.frame, "SecureActionButtonTemplate")
	btn:SetSize(ICON, ICON)
	btn:EnableMouse(true)
	btn:RegisterForDrag("LeftButton")
	btn:SetScript("OnDragStart", onDragStart)
	btn:SetScript("OnDragStop", onDragStop)
	-- Traced the actual dispatch chain in
	-- ~/ws/wow-ui-source/.../Blizzard_FrameXML/SecureTemplates.lua
	-- (OnActionButtonClick -> GetConvertedButtonUnitAndActionType ->
	-- SecureButton_GetModifiedAttribute) rather than guess. Confirmed: the
	-- attribute actually looked up is "type"..SecureButton_GetButtonSuffix
	-- (button), where RightButton maps to suffix "2" - so a right-click
	-- reads exactly type2/macrotext2 (set in setItemAttr below).
	-- SecureActionButton_OnClick also only fires the action when the
	-- click's down/up state matches useOnKeyDown
	-- (SecureActionButton_ShouldUseOnKeyDown falls back to the player's
	-- "ActionButtonUseKeyDown" CVar - invisible to the addon - if it isn't
	-- set explicitly), so it's set here rather than left implicit.
	btn:RegisterForClicks("AnyDown")
	btn:SetAttribute("useOnKeyDown", true)

	local ring = btn:CreateTexture(nil, "BACKGROUND")
	ring:SetPoint("TOPLEFT", -1, 1)
	ring:SetPoint("BOTTOMRIGHT", 1, -1)
	ring:SetColorTexture(0, 0, 0, 1)
	btn.ring = ring

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	btn.icon = icon

	local durText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	durText:SetPoint("BOTTOM", 0, 1)
	local font, size = durText:GetFont()
	durText:SetFont(font, size, "THICKOUTLINE")
	durText:SetShadowColor(0, 0, 0, 1)
	btn.durText = durText

	btn:SetScript("OnEnter", function(self)
		if not self.kind then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if self.kind == "equipped" then
			GameTooltip:SetInventoryItem("player", self.invSlot) -- native tooltip already shows durability
		else
			GameTooltip:SetBagItem(self.bag, self.slot)
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Right-click to equip", 0.6, 1, 0.6)
		end
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- No OnClick script: right-click-to-equip is handled entirely by the
	-- secure type2="macro" attribute set in setItemAttr below. Setting a raw
	-- OnClick on a SecureActionButtonTemplate button would replace its
	-- protected click dispatch with insecure Lua.

	btn:Hide()
	return btn
end

function SW:CreateButtons()
	SW.buttons = {}
	for i = 1, 1 + MAX_ROWS * MAX_COLUMNS do
		SW.buttons[i] = createButton(i)
	end
	SW:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- Combat ended: apply whatever layout would have happened while frozen.
function SW:PLAYER_REGEN_ENABLED()
	if SW.layoutPending then
		SW:RefreshLayout()
	end
end

----------------------------------------------------------------------
-- Layout: equipped icon (fixed first, if any) + gap + bag grid (most-
-- damaged first).
----------------------------------------------------------------------

-- Deliberately type="macro" + "/use bag slot", NOT type="item" + a link.
-- Traced SECURE_ACTIONS.item in SecureTemplates.lua: for an equippable,
-- not-yet-equipped item it always calls C_Item.EquipItemByName(name) using
-- just the resolved link/name - bag/slot gets parsed out but then thrown
-- away. Two genuinely identical shields have byte-identical links (no
-- uniqueID component - confirmed via /shs dump), so EquipItemByName can't
-- tell them apart and just grabs whichever instance it finds, regardless
-- of which specific button/slot was clicked. A macro's "/use <bag> <slot>"
-- is parsed natively (through WoW's real macro-command interpreter, not
-- this Lua item handler) and targets the container slot directly, with no
-- name/link resolution at all - unambiguous even for exact duplicates.
-- Only ever called out of combat (see RefreshLayout).
local function setItemAttr(btn, entry)
	if entry.kind == "bag" then
		btn:SetAttribute("type2", "macro")
		btn:SetAttribute("macrotext2", "/use " .. entry.bag .. " " .. entry.slot)
	else
		btn:SetAttribute("type2", nil)
		btn:SetAttribute("macrotext2", nil)
	end
end

local function fillButton(btn, entry)
	btn.kind = entry.kind
	btn.bag, btn.slot = entry.bag, entry.slot
	btn.invSlot = entry.invSlot
	btn.icon:SetTexture(entry.icon)

	local pct = entry.maxDurability > 0 and (entry.durability / entry.maxDurability) or 1
	btn.durText:SetText(math.floor(pct * 100 + 0.5) .. "%")
	local r, g, b = durabilityColor(pct)
	btn.durText:SetTextColor(r, g, b)
	btn.ring:SetColorTexture(r, g, b, 1)

	setItemAttr(btn, entry)
end

-- Combat-safe durability refresh: reading/displaying data was never the
-- protected part (a plain tooltip hover shows live durability in combat
-- with zero special handling - only reassigning which button represents
-- what, and repositioning, are protected). Matches each already-placed
-- button back to whatever's actually in ITS bag/slot (or the equip slot)
-- right now, same as a tooltip would - no identity tracking across a
-- location change, unlike the earlier guid-based attempt that caused real
-- bugs. Tradeoff, accepted: if a shield gets equipped mid-combat, the
-- bag slots that shuffle as a result may show a different physical
-- shield's numbers on that button than before, until combat ends and
-- RefreshLayout re-syncs everything - never wrong data, just possibly not
-- the same physical item you were tracking a moment ago.
local function updateDurabilityOnly()
	local shields = SW.shields or {}
	for _, btn in ipairs(SW.buttons) do
		if btn.kind then
			for _, entry in ipairs(shields) do
				local matches = (entry.kind == btn.kind) and (
					(entry.kind == "equipped" and entry.invSlot == btn.invSlot) or
					(entry.kind == "bag" and entry.bag == btn.bag and entry.slot == btn.slot))
				if matches then
					btn.icon:SetTexture(entry.icon)
					local pct = entry.maxDurability > 0 and (entry.durability / entry.maxDurability) or 1
					btn.durText:SetText(math.floor(pct * 100 + 0.5) .. "%")
					local r, g, b = durabilityColor(pct)
					btn.durText:SetTextColor(r, g, b)
					btn.ring:SetColorTexture(r, g, b, 1)
					break
				end
			end
		end
	end
end

function SW:RefreshLayout()
	if not SW.buttons then return end

	-- Nothing to monitor with 0-1 total shields (worn + bagged combined) -
	-- there's no swap to make yet, so don't even show the group.
	if #(SW.shields or {}) < 2 then
		SW.frame:Hide()
		return
	end
	SW.frame:Show()

	-- Combat lockdown: secure attributes and structural changes (position,
	-- size) on the secure icon buttons can't be touched by insecure code
	-- while this is true, so reassigning which shield is on which icon has
	-- to wait until combat ends (PLAYER_REGEN_ENABLED). Durability numbers
	-- still update live via updateDurabilityOnly() above - see its comment
	-- for why that part is safe.
	if InCombatLockdown() then
		SW.layoutPending = true
		updateDurabilityOnly()
		return
	end
	SW.layoutPending = false

	local equipped
	local bagShields = {}
	for _, entry in ipairs(SW.shields or {}) do
		if entry.kind == "equipped" then
			equipped = entry
		else
			bagShields[#bagShields + 1] = entry
		end
	end

	-- table.sort isn't stable: when two shields tie on durability (the
	-- common case - most are undamaged), Lua is free to order them
	-- differently between calls even though neither value changed. guid
	-- (Core/Scan.lua: a per-physical-item identity) fixes this - itemID is
	-- the fallback for the rare case guid comes back nil (API unavailable).
	table.sort(bagShields, function(a, b)
		local pa = a.maxDurability > 0 and a.durability / a.maxDurability or 1
		local pb = b.maxDurability > 0 and b.durability / b.maxDurability or 1
		if pa ~= pb then return pa < pb end
		if a.guid and b.guid and a.guid ~= b.guid then return a.guid < b.guid end
		return a.itemID < b.itemID
	end)

	local cols = math.min(MAX_COLUMNS, math.max(1, SW.opt.display.columns or MAX_COLUMNS))
	local rows = math.min(MAX_ROWS, math.max(1, SW.opt.display.rows or 1))
	local bagCapacity = rows * cols

	local used = 0

	if equipped then
		local btn = SW.buttons[1]
		fillButton(btn, equipped)
		btn:ClearAllPoints()
		btn:SetPoint("TOPLEFT", SW.frame, "TOPLEFT", MARGIN, -MARGIN)
		btn:Show()
		used = 1
	end

	local bagOriginX = MARGIN + ICON + GAP
	local shownBag = 0
	for i = 1, math.min(bagCapacity, #bagShields) do
		local btn = SW.buttons[used + 1]
		fillButton(btn, bagShields[i])
		local col = shownBag % cols
		local row = math.floor(shownBag / cols)
		btn:ClearAllPoints()
		btn:SetPoint("TOPLEFT", SW.frame, "TOPLEFT",
			bagOriginX + col * (ICON + PAD), -MARGIN - row * (ICON + PAD))
		btn:Show()
		used = used + 1
		shownBag = shownBag + 1
	end

	for i = used + 1, #SW.buttons do
		SW.buttons[i].kind = nil
		SW.buttons[i]:Hide()
	end

	local bagCols = math.min(cols, math.max(shownBag, 1))
	local bagRows = math.max(1, math.ceil(math.max(shownBag, 1) / cols))
	local bagWidth = bagCols * (ICON + PAD) - PAD
	local bagHeight = bagRows * (ICON + PAD) - PAD

	SW.frame:SetSize(
		MARGIN + ICON + GAP + bagWidth + MARGIN,
		MARGIN + math.max(ICON, bagHeight) + MARGIN)
end
