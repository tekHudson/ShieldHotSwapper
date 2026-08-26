--[[ ShieldWatch — icon grid: pool of plain (non-secure) buttons, one per
displayed shield, laid out into the rows x columns grid from options.

No casting happens here, so these are ordinary Buttons, not
SecureActionButtonTemplate - no combat-lockdown handling needed. Each button
also registers its own drag and forwards Start/StopMoving to the shared
container frame, so holding down on an icon moves the whole group exactly
like holding down on the background gap does.
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
	local btn = CreateFrame("Button", "ShieldWatchIcon" .. i, SW.frame)
	btn:SetSize(ICON, ICON)
	btn:EnableMouse(true)
	btn:RegisterForDrag("LeftButton")
	btn:SetScript("OnDragStart", onDragStart)
	btn:SetScript("OnDragStop", onDragStop)

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
			GameTooltip:AddLine("Click to equip", 0.6, 1, 0.6)
		end
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Click to equip: same as double-clicking the item in your bags (swaps
	-- whatever's currently worn back into the bag slot this came from). The
	-- already-worn shield's icon is a no-op here - nothing to swap it with.
	btn:RegisterForClicks("LeftButtonUp")
	btn:SetScript("OnClick", function(self)
		if self.kind ~= "bag" then return end
		local UseItem = C_Container and C_Container.UseContainerItem or _G.UseContainerItem
		UseItem(self.bag, self.slot)
	end)

	btn:Hide()
	return btn
end

function SW:CreateButtons()
	SW.buttons = {}
	for i = 1, MAX_ROWS * MAX_COLUMNS do
		SW.buttons[i] = createButton(i)
	end
end

----------------------------------------------------------------------
-- Layout: place shields into the configured grid, most-damaged first.
----------------------------------------------------------------------
function SW:RefreshLayout()
	if not SW.buttons then return end
	local shields = SW.shields or {}

	table.sort(shields, function(a, b)
		local pa = a.maxDurability > 0 and a.durability / a.maxDurability or 1
		local pb = b.maxDurability > 0 and b.durability / b.maxDurability or 1
		return pa < pb
	end)

	-- "columns" is the wrap width; "rows" caps how many rows of shields will
	-- ever be shown (most-damaged first fills the grid, the rest are
	-- clipped). The frame itself is sized to what's actually filled below,
	-- not to this full capacity, so there's no dead space when you have
	-- fewer shields than the grid could hold.
	local cols = math.min(MAX_COLUMNS, math.max(1, SW.opt.display.columns or MAX_COLUMNS))
	local rows = math.min(MAX_ROWS, math.max(1, SW.opt.display.rows or 1))
	local capacity = rows * cols

	SW.activeButtons = {}
	local shown = 0
	for i = 1, math.min(capacity, #shields) do
		local entry = shields[i]
		local btn = SW.buttons[i]

		btn.kind = entry.kind
		btn.bag, btn.slot = entry.bag, entry.slot
		btn.invSlot = entry.invSlot
		btn.icon:SetTexture(entry.icon)
		local isWorn = entry.kind == "equipped"
		for _, t in pairs(btn.worn) do t:SetShown(isWorn) end

		local pct = entry.maxDurability > 0 and (entry.durability / entry.maxDurability) or 1
		btn.durText:SetText(math.floor(pct * 100 + 0.5) .. "%")
		local r, g, b = durabilityColor(pct)
		btn.durText:SetTextColor(r, g, b)
		btn.ring:SetColorTexture(r, g, b, 1)

		local col = i - 1 - cols * math.floor((i - 1) / cols)
		local row = math.floor((i - 1) / cols)
		btn:ClearAllPoints()
		btn:SetPoint("TOPLEFT", SW.frame, "TOPLEFT",
			MARGIN + col * (ICON + PAD), -MARGIN - row * (ICON + PAD))

		SW.activeButtons[#SW.activeButtons + 1] = btn
		shown = shown + 1
	end

	for i = shown + 1, #SW.buttons do
		SW.buttons[i].kind = nil
		SW.buttons[i]:Hide()
	end

	-- Size the frame to only what's actually filled (min one icon's worth,
	-- so there's always something to grab/hover even with zero shields).
	local usedCols = math.min(cols, math.max(shown, 1))
	local usedRows = math.max(1, math.ceil(math.max(shown, 1) / cols))
	SW.frame:SetSize(
		2 * MARGIN + usedCols * (ICON + PAD) - PAD,
		2 * MARGIN + usedRows * (ICON + PAD) - PAD)

	-- Re-apply the current reveal state immediately so a bag update doesn't
	-- flash a newly-active icon before the next hover tick.
	if SW.ApplyReveal then SW:ApplyReveal() end
end
