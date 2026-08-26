--[[ ShieldHotSwapper — movable container frame.

Pure Lua (no XML). Icons are always visible (no hover-to-reveal - tried
that, Tek didn't like it: an empty reserved box when not hovering, and no
way to see the rest of the group while hovering over just one icon).

Click-and-hold works from the background gap (this frame) or from any icon
button (UI/Buttons.lua delegates its drag scripts here), so the whole group
moves together no matter where you grab it.
]]

local ADDON, ns = ...
local SW = ns.SW

local ICON, PAD, MARGIN = ns.ICON, ns.PAD, ns.MARGIN

local function savePos(f)
	local point, _, relPoint, x, y = f:GetPoint()
	SW.opt.pos = { point = point, relPoint = relPoint, x = x, y = y }
end

function SW:CreateMainFrame()
	local f = CreateFrame("Frame", "ShieldHotSwapperFrame", UIParent, "BackdropTemplate")
	f:SetSize(ICON + 2 * MARGIN, ICON + 2 * MARGIN)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	f:SetBackdropColor(0, 0, 0, 0.55)
	f:SetBackdropBorderColor(1, 1, 1, 0.5)

	if SW.opt.pos then
		local p = SW.opt.pos
		f:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
	else
		f:SetPoint("CENTER")
	end

	f:SetScript("OnDragStart", function(self)
		if not SW.opt.locked then self:StartMoving() end
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePos(self)
	end)

	SW.frame = f
end

function SW:ResetPosition()
	SW.opt.pos = nil
	SW.frame:ClearAllPoints()
	SW.frame:SetPoint("CENTER")
end

function SW:InitUI()
	SW:CreateMainFrame()
	SW:CreateButtons()
	SW:CreateOptions()
	SW:RefreshLayout()
end
