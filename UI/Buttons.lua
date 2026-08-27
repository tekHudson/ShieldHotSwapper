--[[ ShieldHotSwapper — icon grid: pool of secure buttons, one per
displayed shield, laid out into the rows x columns grid from options.

Buttons use SecureActionButtonTemplate (type2="macro", right-click) so
click-to-equip survives combat lockdown - a plain insecure button calling
UseContainerItem() during combat gets its equip silently downgraded to
just picking the item up onto the cursor, which is exactly the bug this
fixes. The tradeoff: secure attributes and structural changes (position,
size) can't be touched by insecure code while InCombatLockdown() is true,
so RefreshLayout freezes the whole grid (which shield maps to which
button) during combat and only re-lays-out once combat ends
(PLAYER_REGEN_ENABLED). Durability numbers/colors still update live in
combat via updateCosmeticsOnly() - those are plain child-texture/
fontstring changes, not attribute or structural changes, so they're safe.

Equip is bound to RIGHT-click specifically (not left) so it can use
AnyDown + useOnKeyDown=true (required - see the long comment in
createButton for why a plain LeftButtonUp registration silently drops
the click depending on the player's Action Bar CVar settings) without
racing the left-click drag-to-move gesture below. Each button also
registers its own drag and forwards Start/StopMoving to the shared
container frame (dragging a window via StartMoving isn't a protected
action, so this remains unaffected by any of the above), so holding down
on an icon moves the whole group exactly like holding down on the
background gap does.
]]

local ADDON, ns = ...
local SW = ns.SW

local ICON, PAD, MARGIN = ns.ICON, ns.PAD, ns.MARGIN

-- Pool is sized to the sliders' max bounds (UI/Options.lua: rows 1-6,
-- columns 1-10), so it never needs to grow at runtime.
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
	-- SecureButton_GetModifiedAttribute) rather than guess further after
	-- two failed attempts. Confirmed: the attribute actually looked up is
	-- "type"..SecureButton_GetButtonSuffix(button), where RightButton maps
	-- to suffix "2" - so a right-click reads exactly type2/macrotext2 (set
	-- in setItemAttr below). SecureActionButton_OnClick also only fires the
	-- action when the click's down/up state matches useOnKeyDown
	-- (SecureActionButton_ShouldUseOnKeyDown falls back to the player's
	-- "ActionButtonUseKeyDown" CVar - invisible to the addon - if it isn't
	-- set explicitly), so it's set here rather than left implicit.
	--
	-- Equip is bound to RIGHT-click specifically so useOnKeyDown (fires
	-- immediately on mouse-down) can't race the left-click drag-to-move
	-- gesture below: left click never gets a type1/item1 attribute, so its
	-- mouse-down does nothing, while RegisterForDrag("LeftButton") still
	-- drives the drag independently.
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

	-- Equipped-slot box: a gold outline standing outside the durability
	-- ring, shown only for the currently-worn shield. Distinct from the
	-- ring (which is always green/yellow/red for durability) so "this is
	-- equipped" and "this is how damaged it is" never fight for the same
	-- color.
	-- Sits inside the 4px gap between icons (PAD) so it never overlaps a
	-- neighboring icon.
	local EQUIP_INSET, EQUIP_THICK = 2, 2
	local EQUIP_COLOR = { 1, 0.82, 0.1 }
	local worn = {}
	local function edge(point1, point2)
		local t = btn:CreateTexture(nil, "OVERLAY", nil, 1)
		t:SetColorTexture(unpack(EQUIP_COLOR))
		t:SetPoint(unpack(point1))
		t:SetPoint(unpack(point2))
		return t
	end
	worn.top = edge({ "TOPLEFT", -EQUIP_INSET, EQUIP_INSET }, { "TOPRIGHT", EQUIP_INSET, EQUIP_INSET })
	worn.top:SetHeight(EQUIP_THICK)
	worn.bottom = edge({ "BOTTOMLEFT", -EQUIP_INSET, -EQUIP_INSET }, { "BOTTOMRIGHT", EQUIP_INSET, -EQUIP_INSET })
	worn.bottom:SetHeight(EQUIP_THICK)
	worn.left = edge({ "TOPLEFT", -EQUIP_INSET, EQUIP_INSET }, { "BOTTOMLEFT", -EQUIP_INSET, -EQUIP_INSET })
	worn.left:SetWidth(EQUIP_THICK)
	worn.right = edge({ "TOPRIGHT", EQUIP_INSET, EQUIP_INSET }, { "BOTTOMRIGHT", EQUIP_INSET, -EQUIP_INSET })
	worn.right:SetWidth(EQUIP_THICK)
	for _, t in pairs(worn) do t:Hide() end
	btn.worn = worn

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
	-- protected click dispatch with insecure Lua - exactly the bug being
	-- fixed here.

	btn:Hide()
	return btn
end

function SW:CreateButtons()
	SW.buttons = {}
	for i = 1, MAX_ROWS * MAX_COLUMNS do
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
-- Layout: one pool of icons (every shield you own, worn or in a bag),
-- sorted most-damaged first. Equipping a shield doesn't reshuffle icon
-- positions - durability doesn't change the instant you equip something,
-- so an item's sort position doesn't move either. Only the gold outline
-- box (see fillButton) jumps to mark whichever icon is now worn.
----------------------------------------------------------------------

-- Secure attribute changes are combat-locked just like structural changes
-- (position/size) - only ever called from the non-combat path below.
-- type2/macrotext2 = right click (RightButton -> suffix "2", see the
-- RegisterForClicks comment in createButton for why right-click and not
-- left).
--
-- Deliberately type="macro" + "/use bag slot", NOT type="item" + a link.
-- Traced SECURE_ACTIONS.item in SecureTemplates.lua: for an equippable,
-- not-yet-equipped item it always calls C_Item.EquipItemByName(name) using
-- just the resolved link/name - bag/slot gets parsed out but then thrown
-- away. Two genuinely identical shields have byte-identical links (no
-- uniqueID component - confirmed via /shs dump), so EquipItemByName can't
-- tell them apart and just grabs whichever instance it finds, regardless
-- of which specific button/slot was clicked (Tek's report: right-clicking
-- the second of a duplicate pair didn't equip that one, and the grid
-- sometimes reshuffled - both explained by the wrong physical item getting
-- equipped). A macro's "/use <bag> <slot>" is parsed natively (through
-- WoW's real macro-command interpreter, not this Lua item handler) and
-- targets the container slot directly, with no name/link resolution at
-- all - unambiguous even for exact duplicates.
local function setItemAttr(btn, entry)
	if InCombatLockdown() then return end
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
	btn.guid = entry.guid -- combat-time cosmetic refresh tracks by this, see updateCosmeticsOnly
	btn.icon:SetTexture(entry.icon)
	local isWorn = entry.kind == "equipped"
	for _, t in pairs(btn.worn) do t:SetShown(isWorn) end

	local pct = entry.maxDurability > 0 and (entry.durability / entry.maxDurability) or 1
	btn.durText:SetText(math.floor(pct * 100 + 0.5) .. "%")
	local r, g, b = durabilityColor(pct)
	btn.durText:SetTextColor(r, g, b)
	btn.ring:SetColorTexture(r, g, b, 1)

	setItemAttr(btn, entry)
end

local function placeButton(btn, index, cols)
	local col = index - cols * math.floor(index / cols)
	local row = math.floor(index / cols)
	btn:ClearAllPoints()
	btn:SetPoint("TOPLEFT", SW.frame, "TOPLEFT",
		MARGIN + col * (ICON + PAD), -MARGIN - row * (ICON + PAD))
end

-- Match each already-placed button back to its current entry in a fresh
-- scan. MUST be by guid (the stable per-physical-item identity from
-- Core/Scan.lua), not by kind+location: equipping something during combat
-- moves it from a bag slot to the equip slot and moves whatever was worn
-- into a bag slot (often the exact slot that was just vacated) - matching
-- by kind+location would find "whatever is equipped now" for the button
-- that used to BE the equipped slot (wrong: that button should keep
-- showing the specific physical item it was showing before combat) and
-- "whatever landed in that bag slot" for the button that vacated it
-- (equally wrong). That bug shipped once already: icons appeared to swap
-- places while the gold box stayed put, because kind/location matching
-- silently reassigned which physical item each button displayed. guid
-- doesn't change when an item moves between a bag and the equip slot, so
-- matching by it keeps each button showing the same physical shield all
-- the way through combat - only the worn/gold-box state (computed
-- separately below, from whichever guid is currently equipped) moves.
-- Falls back to the old kind+location match if guid is missing (defensive
-- only - see Core/Scan.lua's itemGUID(), pcall-wrapped for the same
-- reason).
local function findMatchingEntry(shields, btn)
	if btn.guid then
		for _, entry in ipairs(shields) do
			if entry.guid == btn.guid then return entry end
		end
	end
	for _, entry in ipairs(shields) do
		if entry.kind == btn.kind then
			if entry.kind == "equipped" then
				if entry.invSlot == btn.invSlot then return entry end
			elseif entry.bag == btn.bag and entry.slot == btn.slot then
				return entry
			end
		end
	end
	return nil
end

-- Note: a shield that gets newly equipped mid-combat, displacing whatever
-- was worn, leaves the displaced item's button without a working
-- right-click (its secure macrotext2 was never set, since it was the
-- equipped-slot button - no attribute needed - up until this moment, and
-- secure attributes can't be set during combat). It'll look and read
-- correct (icon/durability/gold-box all update via guid matching above);
-- it just can't be swapped again itself until combat ends and a full
-- RefreshLayout re-arms every button's attributes.
local function updateCosmeticsOnly()
	local shields = SW.shields or {}

	local equippedGuid
	for _, entry in ipairs(shields) do
		if entry.kind == "equipped" then
			equippedGuid = entry.guid
			break
		end
	end

	for _, btn in ipairs(SW.buttons) do
		if btn.kind then
			local entry = findMatchingEntry(shields, btn)
			if entry then
				btn.icon:SetTexture(entry.icon)
				local pct = entry.maxDurability > 0 and (entry.durability / entry.maxDurability) or 1
				btn.durText:SetText(math.floor(pct * 100 + 0.5) .. "%")
				local r, g, b = durabilityColor(pct)
				btn.durText:SetTextColor(r, g, b)
				btn.ring:SetColorTexture(r, g, b, 1)
			end

			local isWorn = btn.guid ~= nil and btn.guid == equippedGuid
			for _, t in pairs(btn.worn) do t:SetShown(isWorn) end
		end
	end
end

function SW:RefreshLayout()
	if not SW.buttons then return end

	-- Nothing to monitor with 0-1 total shields (worn + bagged combined) -
	-- there's no "which one is worn" question to answer yet, so don't even
	-- show the group. Safe to check/toggle regardless of combat: this is
	-- visibility on the plain (non-secure) container frame, not a
	-- structural or attribute change on any of the secure icon buttons.
	if #(SW.shields or {}) < 2 then
		SW.frame:Hide()
		return
	end
	SW.frame:Show()

	-- Combat lockdown: can't reassign/reposition/resize secure buttons, so
	-- freeze the grid as-is and just refresh numbers on whatever's already
	-- placed. Full layout (including any new/removed shields) applies the
	-- moment combat ends, via PLAYER_REGEN_ENABLED above.
	if InCombatLockdown() then
		SW.layoutPending = true
		updateCosmeticsOnly()
		return
	end
	SW.layoutPending = false

	local shields = SW.shields or {}

	-- table.sort isn't stable: when two shields tie on durability (the
	-- common case - most are undamaged), Lua is free to order them
	-- differently between calls even though neither value changed. guid
	-- (Core/Scan.lua: a per-physical-item identity, confirmed via /shs dump
	-- to stay fixed across an equip/unequip location change, unlike
	-- bag/slot) fixes this completely - sorting by it means the grid's
	-- order never changes just because something got equipped, including
	-- for two genuinely identical shields (same itemID) where nothing else
	-- would tell them apart. itemID is the fallback for the rare case guid
	-- comes back nil (API unavailable).
	table.sort(shields, function(a, b)
		local pa = a.maxDurability > 0 and a.durability / a.maxDurability or 1
		local pb = b.maxDurability > 0 and b.durability / b.maxDurability or 1
		if pa ~= pb then return pa < pb end
		if a.guid and b.guid and a.guid ~= b.guid then return a.guid < b.guid end
		return a.itemID < b.itemID
	end)

	-- "columns" is the wrap width; "rows" caps how many rows will ever be
	-- shown (most-damaged shield first fills the grid, the rest are
	-- clipped).
	local cols = math.min(MAX_COLUMNS, math.max(1, SW.opt.display.columns or MAX_COLUMNS))
	local rows = math.min(MAX_ROWS, math.max(1, SW.opt.display.rows or 1))
	local capacity = rows * cols

	-- Never let the worn shield get clipped out, even if enough
	-- badly-damaged bag shields exist to otherwise push it past the cutoff -
	-- it's the one most worth always being able to see.
	local shown = {}
	local sawEquipped = false
	for i = 1, math.min(capacity, #shields) do
		shown[#shown + 1] = shields[i]
		if shields[i].kind == "equipped" then sawEquipped = true end
	end
	if not sawEquipped then
		for _, entry in ipairs(shields) do
			if entry.kind == "equipped" then
				shown[math.max(#shown, 1)] = entry
				break
			end
		end
	end

	local used = 0
	for i, entry in ipairs(shown) do
		local btn = SW.buttons[i]
		fillButton(btn, entry)
		placeButton(btn, i - 1, cols)
		btn:Show()
		used = used + 1
	end

	for i = used + 1, #SW.buttons do
		SW.buttons[i].kind = nil
		SW.buttons[i]:Hide()
	end

	-- Size the frame to only what's actually filled (min one icon's worth,
	-- so there's always something to grab even with zero shields).
	local usedCols = math.min(cols, math.max(used, 1))
	local usedRows = math.max(1, math.ceil(math.max(used, 1) / cols))
	SW.frame:SetSize(
		2 * MARGIN + usedCols * (ICON + PAD) - PAD,
		2 * MARGIN + usedRows * (ICON + PAD) - PAD)
end
